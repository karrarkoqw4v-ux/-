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

// فايربيس: المصدر الوحيد لبيانات المحادثات والرسائل (Firebase Realtime
// Database). الحسابات وكلمات السر تبقى محلية بالسيرفر، لكن أي شي يخص
// المحادثات (البدء، الإرسال، القراءة) يروح ويجي من فايربيس مباشرة.
//
// مهم: هذا غير ملف google-services.json اللي سويت فيه التسجيل بالتطبيق.
// هذا يحتاج "مفتاح حساب خدمة" (Service Account Key) تنزّله من:
// Firebase Console → ⚙️ إعدادات المشروع → حسابات الخدمة → Generate new private key
// وتحط الملف بجنب السيرفر باسم serviceAccountKey.json (أو تحدد مساره بمتغير البيئة FIREBASE_SERVICE_ACCOUNT).
//
// بدون هذا الملف: تسجيل الدخول وإنشاء الحساب يشتغلون عادي (محليين)،
// لكن كل شي يخص المحادثات يرجّع خطأ واضح لأنه ما عنده وين يخزّن.
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
		log.Printf("فايربيس: المحادثات معطّلة — ما لكيت ملف مفتاح حساب الخدمة (%s). راجع server/FIREBASE.md. %v", keyPath, err)
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
	log.Printf("فايربيس: متصل بـ %s — المحادثات تشتغل الحين من فايربيس", fbBaseURL)
}

// fbGet يقرأ مسار من قاعدة البيانات. لو المسار فاضي (null) ما يرجع خطأ،
// بس يخلي out على قيمته الافتراضية.
func fbGet(path string, out any) error {
	resp, err := fbClient.Get(fbBaseURL + path + ".json")
	if err != nil {
		return fmt.Errorf("فايربيس: تعذر الاتصال: %w", err)
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	if resp.StatusCode >= 300 {
		return fmt.Errorf("فايربيس: رفض القراءة من %s (%d): %s", path, resp.StatusCode, body)
	}
	if string(body) == "null" || len(body) == 0 {
		return nil // المسار فاضي، نخلي out كما هو (صفري)
	}
	return json.Unmarshal(body, out)
}

// fbPutSync يكتب قيمة بمسار معيّن (استبدال كامل لهذا المسار) وينتظر النتيجة.
func fbPutSync(path string, v any) error {
	b, err := json.Marshal(v)
	if err != nil {
		return err
	}
	req, err := http.NewRequest(http.MethodPut, fbBaseURL+path+".json", bytes.NewReader(b))
	if err != nil {
		return err
	}
	resp, err := fbClient.Do(req)
	if err != nil {
		return fmt.Errorf("فايربيس: تعذر الاتصال: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 300 {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("فايربيس: رفض الكتابة على %s (%d): %s", path, resp.StatusCode, body)
	}
	return nil
}

// fbSet نسخة "إضافية" (best effort) لا تنتظر ولا ترجع خطأ — تُستخدم لأشياء
// ثانوية مثل نسخة الملف الشخصي العامة، اللي ما نبي نوقف الطلب الأساسي لأجلها.
func fbSet(path string, v any) {
	if !fbReady {
		return
	}
	go func() {
		if err := fbPutSync(path, v); err != nil {
			log.Printf("%v", err)
		}
	}()
}

func fbSyncUser(u User) {
	fbSet("/users/"+u.ID, map[string]string{"name": u.Name, "username": u.Username, "avatar": u.Avatar})
	fbSet("/usernames/"+u.Username, u.ID)
}
