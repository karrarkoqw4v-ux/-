package main

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"sync"
	"time"
	"unicode/utf8"

	"golang.org/x/crypto/bcrypt"
)

type User struct {
	ID       string `json:"id"`
	Name     string `json:"name"`
	Username string `json:"username"`
	Email    string `json:"email"`
	Avatar   string `json:"avatar"`
	Hash     []byte `json:"hash"`
}

// الحسابات وكلمات السر تبقى محلية بهالسيرفر (مع ملف data.json).
// المحادثات والرسائل مصدرها الوحيد فايربيس — شوف server/chat.go و server/firebase.go.
type Store struct {
	mu       sync.Mutex
	path     string
	Users    []User            `json:"users"`
	Sessions map[string]string `json:"sessions"` // token -> user id
}

var (
	store      = &Store{path: "data.json", Sessions: map[string]string{}}
	emailRe    = regexp.MustCompile(`^[^@\s]+@[^@\s]+\.[^@\s]+$`)
	usernameRe = regexp.MustCompile(`^[a-z0-9_.]{3,20}$`)
)

func (s *Store) load() {
	b, err := os.ReadFile(s.path)
	if err == nil {
		json.Unmarshal(b, s)
	}
	if s.Sessions == nil {
		s.Sessions = map[string]string{}
	}
}

func (s *Store) save() {
	b, _ := json.MarshalIndent(s, "", " ")
	os.WriteFile(s.path, b, 0o600)
}

func (s *Store) usernameTaken(u string) bool {
	for _, x := range s.Users {
		if x.Username == u {
			return true
		}
	}
	return false
}

func randHex(n int) string {
	b := make([]byte, n)
	rand.Read(b)
	return hex.EncodeToString(b)
}

func fail(w http.ResponseWriter, code int, field, msg string) {
	w.WriteHeader(code)
	json.NewEncoder(w).Encode(map[string]string{"field": field, "error": msg})
}

func publicUser(u User) map[string]string {
	return map[string]string{"id": u.ID, "name": u.Name, "username": u.Username, "email": u.Email, "avatar": u.Avatar}
}

func nameValid(n string) bool { return len(strings.Fields(n)) >= 3 && utf8.RuneCountInString(n) <= 35 }

// seedDemo يسوّي حسابين تجريبيين مع محادثة فيها رسائل، بس لو ما فيه
// مستخدمين أبداً (أول تشغيل). يسهّل تجربة التطبيق بدون تسجيل يدوي.
// محادثة الديمو تحتاج فايربيس متصل (المحادثات مصدرها الوحيد الحين)؛
// بدونه تنسوي الحسابات بس بدون محادثة جاهزة.
func seedDemo() {
	store.mu.Lock()
	if len(store.Users) > 0 {
		store.mu.Unlock()
		return
	}
	hash, _ := bcrypt.GenerateFromPassword([]byte("demo1234"), bcrypt.DefaultCost)
	u1 := User{ID: randHex(8), Name: "حساب تجريبي أول", Username: "demo1", Email: "demo1@test.com", Hash: hash}
	u2 := User{ID: randHex(8), Name: "حساب تجريبي ثاني", Username: "demo2", Email: "demo2@test.com", Hash: hash}
	store.Users = append(store.Users, u1, u2)
	store.save()
	store.mu.Unlock()

	fbSyncUser(u1)
	fbSyncUser(u2)
	log.Printf("حسابات تجريبية: demo1@test.com / demo2@test.com — كلمة السر: demo1234")

	if !fbReady {
		log.Printf("حسابات الديمو جاهزة بدون محادثة جاهزة (فايربيس مو متصل) — صِل فايربيس وأعد التشغيل عشان تنسوي المحادثة التجريبية")
		return
	}
	convID := convKey(u1.ID, u2.ID)
	if err := fbPutSync("/conversations/"+convID+"/participants", map[string]bool{u1.ID: true, u2.ID: true}); err != nil {
		log.Printf("تعذر إنشاء محادثة الديمو: %v", err)
		return
	}
	_ = fbPutSync("/userConversations/"+u1.ID+"/"+convID, true)
	_ = fbPutSync("/userConversations/"+u2.ID+"/"+convID, true)

	now := time.Now()
	msgs := []struct{ from, text string }{
		{u1.ID, "هلا، شلونك؟"},
		{u2.ID, "هلا والله زين الحمدلله، وإنت؟"},
		{u1.ID, "تمام، هذا حساب تجريبي أشوف فيه المحادثات"},
		{u2.ID, "ما شاء الله تصميم جماعتكم حلو 🔥"},
	}
	var lastFrom, lastText, lastAt string
	for i, mm := range msgs {
		m := Message{ID: randHex(8), SenderID: mm.from, Text: mm.text, At: now.Add(time.Duration(i) * time.Minute).Format(time.RFC3339Nano)}
		_ = fbPutSync("/conversations/"+convID+"/messages/"+m.ID, m)
		lastFrom, lastText, lastAt = mm.from, mm.text, m.At
	}
	_ = fbPutSync("/conversations/"+convID+"/meta", convMeta{LastMessage: lastText, LastAt: lastAt, MessageCount: len(msgs)})
	_ = fbPutSync("/conversations/"+convID+"/readCount/"+lastFrom, len(msgs))
}

// GET /api/auth/username-available?username=
func usernameAvailable(w http.ResponseWriter, r *http.Request) {
	u := strings.ToLower(strings.TrimSpace(r.URL.Query().Get("username")))
	if !usernameRe.MatchString(u) {
		json.NewEncoder(w).Encode(map[string]any{"available": false, "reason": "invalid"})
		return
	}
	store.mu.Lock()
	taken := store.usernameTaken(u)
	store.mu.Unlock()
	json.NewEncoder(w).Encode(map[string]any{"available": !taken, "reason": map[bool]string{true: "taken", false: ""}[taken]})
}

// POST /api/auth/register  (multipart: name, username, email, password, avatar?)
func register(w http.ResponseWriter, r *http.Request) {
	r.Body = http.MaxBytesReader(w, r.Body, 5<<20)
	if err := r.ParseMultipartForm(5 << 20); err != nil {
		fail(w, 400, "", "طلب غير صالح أو الصورة كبيرة")
		return
	}
	name := strings.TrimSpace(r.FormValue("name"))
	username := strings.ToLower(strings.TrimSpace(r.FormValue("username")))
	email := strings.ToLower(strings.TrimSpace(r.FormValue("email")))
	pass := r.FormValue("password")

	switch {
	case !nameValid(name):
		fail(w, 400, "name", "الاسم لازم يكون ثلاثي أو أكثر، وبحد أقصى 35 حرف")
		return
	case !usernameRe.MatchString(username):
		fail(w, 400, "username", "اسم المستخدم 3-20 حرف إنجليزي أو أرقام أو _ .")
		return
	case !emailRe.MatchString(email):
		fail(w, 400, "email", "البريد الإلكتروني غير صالح")
		return
	case utf8.RuneCountInString(pass) < 8:
		fail(w, 400, "password", "كلمة السر لازم تكون 8 أحرف على الأقل")
		return
	}

	avatar := ""
	if f, hdr, err := r.FormFile("avatar"); err == nil {
		defer f.Close()
		head := make([]byte, 512)
		n, _ := f.Read(head)
		ext := map[string]string{"image/jpeg": ".jpg", "image/png": ".png", "image/webp": ".webp"}[http.DetectContentType(head[:n])]
		if ext == "" {
			fail(w, 400, "avatar", "نوع الصورة غير مدعوم")
			return
		}
		f.Seek(0, 0)
		os.MkdirAll("uploads", 0o755)
		fname := randHex(12) + ext
		out, err := os.Create(filepath.Join("uploads", fname))
		if err != nil {
			fail(w, 500, "", "تعذر حفظ الصورة")
			return
		}
		defer out.Close()
		_ = hdr
		buf := make([]byte, 32*1024)
		for {
			n, e := f.Read(buf)
			out.Write(buf[:n])
			if e != nil {
				break
			}
		}
		avatar = "/uploads/" + fname
	}

	hash, _ := bcrypt.GenerateFromPassword([]byte(pass), bcrypt.DefaultCost)
	store.mu.Lock()
	defer store.mu.Unlock()
	if store.usernameTaken(username) {
		fail(w, 409, "username", "اسم المستخدم مستخدم، جرّب غيره")
		return
	}
	for _, u := range store.Users {
		if u.Email == email {
			fail(w, 409, "email", "هذا البريد مسجّل من قبل")
			return
		}
	}
	u := User{ID: randHex(8), Name: name, Username: username, Email: email, Avatar: avatar, Hash: hash}
	store.Users = append(store.Users, u)
	token := randHex(24)
	store.Sessions[token] = u.ID
	store.save()
	fbSyncUser(u) // نسخة من الملف الشخصي (بدون كلمة السر) لقاعدة بيانات فايربيس
	w.WriteHeader(201)
	json.NewEncoder(w).Encode(map[string]any{"token": token, "user": publicUser(u)})
}

// POST /api/auth/login {email,password}
func login(w http.ResponseWriter, r *http.Request) {
	var in struct{ Email, Password string }
	if json.NewDecoder(http.MaxBytesReader(w, r.Body, 1<<16)).Decode(&in) != nil {
		fail(w, 400, "", "طلب غير صالح")
		return
	}
	email := strings.ToLower(strings.TrimSpace(in.Email))
	store.mu.Lock()
	defer store.mu.Unlock()
	for _, u := range store.Users {
		if u.Email == email && bcrypt.CompareHashAndPassword(u.Hash, []byte(in.Password)) == nil {
			token := randHex(24)
			store.Sessions[token] = u.ID
			store.save()
			json.NewEncoder(w).Encode(map[string]any{"token": token, "user": publicUser(u)})
			return
		}
	}
	fail(w, 401, "", "البريد أو كلمة السر غير صحيحة")
}

// POST /api/auth/forgot {email} - always 200 (no account enumeration). Email sending: TODO.
func forgot(w http.ResponseWriter, r *http.Request) {
	json.NewEncoder(w).Encode(map[string]string{"message": "إذا كان البريد مسجّلاً راح تصلك رسالة لإعادة تعيين كلمة السر"})
}
