package main

import (
	"encoding/json"
	"net/http"
	"sort"
	"strings"
	"time"
)

// الرسالة الواحدة، بنفس الشكل المخزّن بفايربيس تحت
// /conversations/{convId}/messages/{id}
type Message struct {
	ID       string `json:"id"`
	ConvID   string `json:"-"`
	SenderID string `json:"senderId"`
	Text     string `json:"text"`
	At       string `json:"at"` // RFC3339
}

// معرف المحادثة ثابت بغض النظر عن ترتيب الطرفين، حتى ما نسوي محادثتين
// بين نفس الشخصين بالغلط.
func convKey(a, b string) string {
	if a > b {
		a, b = b, a
	}
	return a + "_" + b
}

// authUser يرجّع المستخدم الحالي من رأس Authorization: Bearer <token>
func authUser(r *http.Request) (User, bool) {
	tok := strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer ")
	if tok == "" {
		return User{}, false
	}
	store.mu.Lock()
	defer store.mu.Unlock()
	uid, ok := store.Sessions[tok]
	if !ok {
		return User{}, false
	}
	for _, u := range store.Users {
		if u.ID == uid {
			return u, true
		}
	}
	return User{}, false
}

func requireAuth(h func(w http.ResponseWriter, r *http.Request, me User)) http.HandlerFunc {
	return cors(func(w http.ResponseWriter, r *http.Request) {
		me, ok := authUser(r)
		if !ok {
			fail(w, http.StatusUnauthorized, "", "سجّل الدخول أولاً")
			return
		}
		h(w, r, me)
	})
}

// requireFirebase: المحادثات مصدرها الوحيد فايربيس الحين — بدون اتصال
// فعّال، نرجّع خطأ واضح بدل ما نتظاهر إن فيه بيانات.
func requireFirebase(w http.ResponseWriter) bool {
	if !fbReady {
		fail(w, http.StatusServiceUnavailable, "", "المحادثات تحتاج فايربيس متصل بالسيرفر. راجع firebase/SETUP.md")
		return false
	}
	return true
}

func (s *Store) findUser(id string) (User, bool) {
	for _, u := range s.Users {
		if u.ID == id {
			return u, true
		}
	}
	return User{}, false
}

func (s *Store) findUserByUsername(username string) (User, bool) {
	for _, u := range s.Users {
		if u.Username == username {
			return u, true
		}
	}
	return User{}, false
}

type convMeta struct {
	LastMessage  string `json:"lastMessage"`
	LastAt       string `json:"lastAt"`
	MessageCount int    `json:"messageCount"`
}

type convOut struct {
	ID          string `json:"id"`
	User        any    `json:"user"`
	LastMessage string `json:"lastMessage"`
	LastAt      string `json:"lastAt"`
	UnreadCount int    `json:"unreadCount"`
}

// GET /api/conversations
func listConversations(w http.ResponseWriter, r *http.Request, me User) {
	if !requireFirebase(w) {
		return
	}
	var idx map[string]bool
	if err := fbGet("/userConversations/"+me.ID, &idx); err != nil {
		fail(w, http.StatusBadGateway, "", err.Error())
		return
	}
	out := []convOut{}
	for convID := range idx {
		var participants map[string]bool
		_ = fbGet("/conversations/"+convID+"/participants", &participants)
		otherID := ""
		for uid := range participants {
			if uid != me.ID {
				otherID = uid
			}
		}
		other, _ := store.findUser(otherID)

		var meta convMeta
		_ = fbGet("/conversations/"+convID+"/meta", &meta)

		var readCount map[string]int
		_ = fbGet("/conversations/"+convID+"/readCount", &readCount)
		unread := meta.MessageCount - readCount[me.ID]
		if unread < 0 {
			unread = 0
		}

		out = append(out, convOut{ID: convID, User: publicUser(other), LastMessage: meta.LastMessage, LastAt: meta.LastAt, UnreadCount: unread})
	}
	sort.Slice(out, func(i, j int) bool { return out[i].LastAt > out[j].LastAt })
	json.NewEncoder(w).Encode(out)
}

// POST /api/conversations/start {username}
func startConversation(w http.ResponseWriter, r *http.Request, me User) {
	if !requireFirebase(w) {
		return
	}
	var in struct{ Username string }
	if json.NewDecoder(http.MaxBytesReader(w, r.Body, 1<<16)).Decode(&in) != nil {
		fail(w, 400, "", "طلب غير صالح")
		return
	}
	username := strings.ToLower(strings.TrimSpace(in.Username))
	store.mu.Lock()
	other, ok := store.findUserByUsername(username)
	store.mu.Unlock()
	if !ok {
		fail(w, 404, "username", "ما لكينا هذا المستخدم")
		return
	}
	if other.ID == me.ID {
		fail(w, 400, "username", "ما تقدر تراسل نفسك")
		return
	}

	convID := convKey(me.ID, other.ID)
	// PUT بنفس القيمة كل مرة آمن (idempotent) — ما يسوي تكرار لو المحادثة موجودة أصلاً
	if err := fbPutSync("/conversations/"+convID+"/participants", map[string]bool{me.ID: true, other.ID: true}); err != nil {
		fail(w, http.StatusBadGateway, "", err.Error())
		return
	}
	_ = fbPutSync("/userConversations/"+me.ID+"/"+convID, true)
	_ = fbPutSync("/userConversations/"+other.ID+"/"+convID, true)
	json.NewEncoder(w).Encode(map[string]any{"id": convID, "user": publicUser(other)})
}

func userInConv(uid, convID string) bool {
	var participants map[string]bool
	_ = fbGet("/conversations/"+convID+"/participants", &participants)
	return participants[uid]
}

// GET /api/conversations/{id}/messages
func listMessages(w http.ResponseWriter, r *http.Request, me User) {
	if !requireFirebase(w) {
		return
	}
	id := r.PathValue("id")
	if !userInConv(me.ID, id) {
		fail(w, 404, "", "المحادثة غير موجودة")
		return
	}
	var byID map[string]Message
	if err := fbGet("/conversations/"+id+"/messages", &byID); err != nil {
		fail(w, http.StatusBadGateway, "", err.Error())
		return
	}
	msgs := make([]Message, 0, len(byID))
	for _, m := range byID {
		msgs = append(msgs, m)
	}
	sort.Slice(msgs, func(i, j int) bool { return msgs[i].At < msgs[j].At })

	// صار قراها، نعلّم إنه وصل لآخر رسالة
	var meta convMeta
	_ = fbGet("/conversations/"+id+"/meta", &meta)
	_ = fbPutSync("/conversations/"+id+"/readCount/"+me.ID, meta.MessageCount)

	json.NewEncoder(w).Encode(msgs)
}

// POST /api/conversations/{id}/messages {text}
func sendMessage(w http.ResponseWriter, r *http.Request, me User) {
	if !requireFirebase(w) {
		return
	}
	id := r.PathValue("id")
	var in struct{ Text string }
	if json.NewDecoder(http.MaxBytesReader(w, r.Body, 4<<10)).Decode(&in) != nil {
		fail(w, 400, "", "طلب غير صالح")
		return
	}
	text := strings.TrimSpace(in.Text)
	if text == "" {
		fail(w, 400, "text", "اكتب رسالة")
		return
	}
	if !userInConv(me.ID, id) {
		fail(w, 404, "", "المحادثة غير موجودة")
		return
	}

	m := Message{ID: randHex(8), SenderID: me.ID, Text: text, At: time.Now().Format(time.RFC3339Nano)}
	if err := fbPutSync("/conversations/"+id+"/messages/"+m.ID, m); err != nil {
		fail(w, http.StatusBadGateway, "", err.Error())
		return
	}

	var meta convMeta
	_ = fbGet("/conversations/"+id+"/meta", &meta)
	meta.LastMessage, meta.LastAt, meta.MessageCount = m.Text, m.At, meta.MessageCount+1
	_ = fbPutSync("/conversations/"+id+"/meta", meta)
	_ = fbPutSync("/conversations/"+id+"/readCount/"+me.ID, meta.MessageCount) // المرسل "قاري" رسالته هو

	m.ConvID = id
	json.NewEncoder(w).Encode(m)
}
