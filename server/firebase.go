package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"time"

	"golang.org/x/oauth2"
	"golang.org/x/oauth2/google"
)

// فايربيس: نسخة من المحادثات والرسائل بقاعدة بيانات Firebase Realtime Database
// حتى تشوفها بوضوح في لوحة فايربيس، وحتى تقدر لاحقاً تربط تطبيقات أو
// وظائف ثانية (Cloud Functions) تتفاعل وياها مباشرة.
//
// مهم: هذا غير ملف google-services.json اللي سويت فيه التسجيل بالتطبيق.
// هذا يحتاج "مفتاح حساب خدمة" (Service Account Key) تنزّله من:
// Firebase Console → ⚙️ إعدادات المشروع → حسابات الخدمة → Generate new private key
// وتحط الملف بجنب السيرفر باسم serviceAccountKey.json (أو تحدد مساره بمتغير البيئة FIREBASE_SERVICE_ACCOUNT).
//
// السيرفر يشتغل طبيعي حتى بدون هذا الملف — المزامنة مع فايربيس "إضافية"
// (best effort)، ما توقف تسجيل الدخول ولا المحادثات لو فشلت أو الملف ناقص.
var (
	fbClient  *http.Client
	fbBaseURL string
	fbReady   bool
)

func initFirebase() {
	keyPath := os.Getenv("FIREBASE_SERVICE_ACCOUNT")
	if keyPath == "" {
		keyPath = "serviceAccountKey.json"
	}
	b, err := os.ReadFile(keyPath)
	if err != nil {
		log.Printf("فايربيس: تعطيل المزامنة — ما لكيت ملف مفتاح حساب الخدمة (%s). %v", keyPath, err)
		return
	}
	ctx := context.Background()
	creds, err := google.CredentialsFromJSON(ctx, b,
		"https://www.googleapis.com/auth/firebase.database",
		"https://www.googleapis.com/auth/userinfo.email",
	)
	if err != nil {
		log.Printf("فايربيس: ملف مفتاح حساب الخدمة غير صالح: %v", err)
		return
	}
	fbBaseURL = os.Getenv("FIREBASE_DB_URL")
	if fbBaseURL == "" {
		fbBaseURL = "https://ssus-b6995-default-rtdb.firebaseio.com" // من firebase_url بملف google-services.json
	}
	// oauth2.NewClient يسوي HTTP client يحط رمز الدخول تلقائياً بكل طلب،
	// ويجدّده نفسه قبل ما ينتهي — ما نحتاج نتعامل وياه يدوياً.
	fbClient = oauth2.NewClient(ctx, creds.TokenSource)
	fbClient.Timeout = 10 * time.Second
	fbReady = true
	log.Printf("فايربيس: متصل بـ %s", fbBaseURL)
}

// fbSet يكتب قيمة بمسار معيّن بقاعدة البيانات (PUT = استبدال كامل لهذا المسار).
// ما يرجع خطأ للمستخدم أبداً — يسجّله بالسجل فقط، لأن المزامنة إضافية.
func fbSet(path string, v any) {
	if !fbReady {
		return
	}
	go func() {
		b, err := json.Marshal(v)
		if err != nil {
			return
		}
		req, err := http.NewRequest(http.MethodPut, fbBaseURL+path+".json", bytes.NewReader(b))
		if err != nil {
			return
		}
		resp, err := fbClient.Do(req)
		if err != nil {
			log.Printf("فايربيس: فشلت الكتابة على %s: %v", path, err)
			return
		}
		defer resp.Body.Close()
		if resp.StatusCode >= 300 {
			body, _ := io.ReadAll(resp.Body)
			log.Printf("فايربيس: رفض الكتابة على %s (%d): %s", path, resp.StatusCode, string(body))
		}
	}()
}

// مسارات قاعدة البيانات المستخدمة (تطابق database.rules.json):
//   users/{uid}                         — نسخة عامة من الملف الشخصي (بدون كلمة السر أبداً)
//   usernames/{username}                — uid صاحب هذا اليوزر (لمنع التكرار لو قرأها تطبيق ثاني)
//   conversations/{convId}/participants — أطراف المحادثة
//   conversations/{convId}/meta         — آخر رسالة ووقتها
//   conversations/{convId}/messages/{id}— الرسائل نفسها
//   userConversations/{uid}/{convId}    — فهرس: محادثات كل مستخدم

func fbSyncUser(u User) {
	fbSet("/users/"+u.ID, map[string]string{"name": u.Name, "username": u.Username, "avatar": u.Avatar})
	fbSet("/usernames/"+u.Username, u.ID)
}

func fbSyncConversation(c *Conversation) {
	fbSet(fmt.Sprintf("/conversations/%s/participants", c.ID), map[string]bool{c.UserA: true, c.UserB: true})
	fbSet(fmt.Sprintf("/userConversations/%s/%s", c.UserA, c.ID), true)
	fbSet(fmt.Sprintf("/userConversations/%s/%s", c.UserB, c.ID), true)
}

func fbSyncMessage(m Message) {
	fbSet(fmt.Sprintf("/conversations/%s/messages/%s", m.ConvID, m.ID), map[string]any{
		"id": m.ID, "senderId": m.SenderID, "text": m.Text, "at": m.At.Format(time.RFC3339),
	})
	fbSet(fmt.Sprintf("/conversations/%s/meta", m.ConvID), map[string]string{
		"lastMessage": m.Text, "lastAt": m.At.Format(time.RFC3339),
	})
}
