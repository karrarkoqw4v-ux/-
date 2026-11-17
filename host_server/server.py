#!/usr/bin/env python3
"""خادم الاستضافة: حسابات + قاعدة بيانات + تخزين ملفات + تشغيل حقيقي للبوتات.

بدون أي مكتبات خارجية (stdlib فقط).  التشغيل:  python3 server.py
متغيرات البيئة:  PORT (8080)  ·  DATA_DIR (./data)
"""
import hashlib
import json
import os
import re
import secrets
import shutil
import signal
import sqlite3
import subprocess
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

try:
    import resource
except ImportError:  # ويندوز
    resource = None

IS_ROOT = hasattr(os, "geteuid") and os.geteuid() == 0
PORT = int(os.environ.get("PORT", "8080"))
DATA = os.path.abspath(os.environ.get("DATA_DIR", "./data"))
USERS_DIR = os.path.join(DATA, "users")
os.makedirs(USERS_DIR, exist_ok=True)
if IS_ROOT:
    os.chmod(DATA, 0o711)
    os.chmod(USERS_DIR, 0o711)

LANGS = {
    "python": {"main": "main.py"},
    "php": {"main": "index.php"},
    "js": {"main": "index.js"},
}
IGNORED = {".venv", "node_modules", "vendor", "__pycache__", ".git"}
MAX_TOTAL = 8 * 1024 * 1024
RESTART_EVERY = 24 * 3600  # الخطة المجانية: إعادة تشغيل كل 24 ساعة

# ───────────────────────── قاعدة البيانات ─────────────────────────
DB_PATH = os.path.join(DATA, "host.db")
open(DB_PATH, "a").close()
os.chmod(DB_PATH, 0o600)  # فيها التوكنات وكلمات السر المشفّرة: للخادم فقط
db = sqlite3.connect(DB_PATH, check_same_thread=False)
db.row_factory = sqlite3.Row
dblock = threading.RLock()
with dblock:
    db.executescript(
        """
        CREATE TABLE IF NOT EXISTS users(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            salt TEXT NOT NULL, pw TEXT NOT NULL,
            stage TEXT NOT NULL DEFAULT 'provision',
            plan TEXT NOT NULL DEFAULT 'free',
            created REAL NOT NULL);
        CREATE TABLE IF NOT EXISTS tokens(
            token TEXT PRIMARY KEY, user_id INTEGER NOT NULL, created REAL NOT NULL);
        CREATE TABLE IF NOT EXISTS projects(
            user_id INTEGER NOT NULL, lang TEXT NOT NULL,
            want_running INTEGER NOT NULL DEFAULT 0,
            last_state TEXT NOT NULL DEFAULT 'idle',
            PRIMARY KEY(user_id, lang));
        CREATE TABLE IF NOT EXISTS runs(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL, lang TEXT NOT NULL,
            started REAL NOT NULL, ended REAL, exit_code INTEGER, note TEXT);
        """
    )
    db.commit()


def q(sql, args=(), one=False, commit=False):
    with dblock:
        cur = db.execute(sql, args)
        if commit:
            db.commit()
        rows = cur.fetchall()
    if one:
        return rows[0] if rows else None
    return rows


def hash_pw(salt, pw):
    return hashlib.scrypt(pw.encode(), salt=salt.encode(), n=2**14, r=8, p=1).hex()


# ───────────────────────── الملفات ─────────────────────────
def sys_uid(uid):
    """كل مستخدم يشغّل أكواده تحت مستخدم نظام مستقل (يعزل الملفات عن بعضها)"""
    return 20000 + int(uid)


def fix_perms(uid):
    if not IS_ROOT:
        return
    base = os.path.join(USERS_DIR, str(uid))
    os.makedirs(base, exist_ok=True)
    su = sys_uid(uid)
    for dp, dns, fns in os.walk(base):
        for n in dns + fns:
            try:
                os.lchown(os.path.join(dp, n), su, su)
            except OSError:
                pass
    os.chown(base, su, su)
    os.chmod(base, 0o700)


def proj_dir(uid, lang):
    return os.path.join(USERS_DIR, str(uid), lang)


def safe_rel(p):
    p = p.replace("\\", "/").lstrip("/")
    parts = [x for x in p.split("/") if x not in ("", ".")]
    if not parts or any(x == ".." for x in parts):
        raise ValueError("مسار غير صالح: " + p)
    if parts[0] in IGNORED:
        raise ValueError("اسم محجوز: " + parts[0])
    return "/".join(parts)


def list_files(uid, lang):
    root = proj_dir(uid, lang)
    out = {}
    if not os.path.isdir(root):
        return out
    for dp, dns, fns in os.walk(root):
        dns[:] = [d for d in dns if d not in IGNORED]
        for fn in fns:
            full = os.path.join(dp, fn)
            rel = os.path.relpath(full, root).replace(os.sep, "/")
            try:
                with open(full, "rb") as f:
                    out[rel] = f.read().decode("utf-8", errors="replace")
            except OSError:
                pass
        if not fns and not dns and dp != root:
            out[os.path.relpath(dp, root).replace(os.sep, "/") + "/.keep"] = ""
    return out


def replace_files(uid, lang, files):
    total = sum(len(v.encode()) for v in files.values())
    if total > MAX_TOTAL:
        raise ValueError("حجم الملفات أكبر من الحد المسموح (8MB)")
    clean = {safe_rel(k): v for k, v in files.items()}
    root = proj_dir(uid, lang)
    os.makedirs(root, exist_ok=True)
    # احذف الملفات القديمة غير الموجودة
    for dp, dns, fns in os.walk(root):
        dns[:] = [d for d in dns if d not in IGNORED]
        for fn in fns:
            rel = os.path.relpath(os.path.join(dp, fn), root).replace(os.sep, "/")
            if rel not in clean:
                os.remove(os.path.join(dp, fn))
    for rel, content in clean.items():
        full = os.path.join(root, rel)
        os.makedirs(os.path.dirname(full), exist_ok=True)
        with open(full, "w", encoding="utf-8") as f:
            f.write(content)
    fix_perms(uid)


# ───────────────────────── تشغيل المشاريع ─────────────────────────
def kind_of(line):
    low = line.lower()
    if "traceback" in low or "error" in low or "exception" in low:
        return "err"
    if "warning" in low or "warn" in low:
        return "warn"
    return "plain"


class Project:
    def __init__(self, uid, lang):
        self.uid, self.lang = uid, lang
        self.dir = proj_dir(uid, lang)
        self.logfile = os.path.join(USERS_DIR, str(uid), lang + ".log")
        self.lines = []
        self.state = "idle"  # idle | installing | running | error | stopped
        self.proc = None
        self.thread = None
        self.stop_flag = False
        self.restart_flag = False
        self.lock = threading.RLock()
        self._load_log()

    # ----- سجل -----
    def _load_log(self):
        try:
            with open(self.logfile, encoding="utf-8") as f:
                for ln in f.read().splitlines()[-2000:]:
                    k, _, t = ln.partition("\t")
                    self.lines.append((k, t))
        except OSError:
            pass

    def log(self, kind, text):
        with self.lock:
            self.lines.append((kind, text))
            if len(self.lines) > 4000:
                del self.lines[:1000]
            try:
                os.makedirs(os.path.dirname(self.logfile), exist_ok=True)
                with open(self.logfile, "a", encoding="utf-8") as f:
                    f.write(kind + "\t" + text.replace("\n", " ") + "\n")
            except OSError:
                pass

    def clear_log(self):
        with self.lock:
            self.lines = []
            try:
                open(self.logfile, "w").close()
            except OSError:
                pass

    def alive(self):
        return self.thread is not None and self.thread.is_alive()

    # ----- تحكم -----
    def start(self):
        with self.lock:
            if self.alive():
                return False
            self.stop_flag = False
            self.restart_flag = False
            self.clear_log()
            self.state = "installing"
            fix_perms(self.uid)
            self.thread = threading.Thread(target=self._worker, daemon=True)
            self.thread.start()
        q(
            "INSERT INTO projects(user_id,lang,want_running) VALUES(?,?,1) "
            "ON CONFLICT(user_id,lang) DO UPDATE SET want_running=1",
            (self.uid, self.lang),
            commit=True,
        )
        return True

    def stop(self, persist=True):
        self.stop_flag = True
        self._kill()
        if persist:
            q(
                "INSERT INTO projects(user_id,lang,want_running,last_state) VALUES(?,?,0,'stopped') "
                "ON CONFLICT(user_id,lang) DO UPDATE SET want_running=0,last_state='stopped'",
                (self.uid, self.lang),
                commit=True,
            )
        t = self.thread
        if t and t.is_alive() and t is not threading.current_thread():
            t.join(timeout=8)
        if not self.alive():
            if self.state != "error":
                self.state = "stopped"
            self.log("warn", "■ تم إيقاف البوت")

    def _kill(self):
        p = self.proc
        if p and p.poll() is None:
            try:
                os.killpg(os.getpgid(p.pid), signal.SIGTERM)
            except OSError:
                pass
            try:
                p.wait(timeout=4)
            except subprocess.TimeoutExpired:
                try:
                    os.killpg(os.getpgid(p.pid), signal.SIGKILL)
                except OSError:
                    pass

    # ----- أوامر خارجية بسجل حي -----
    def _env(self):
        return {
            "PATH": os.environ.get("PATH", "/usr/local/bin:/usr/bin:/bin"),
            "HOME": self.dir,
            "LANG": "C.UTF-8",
            "PYTHONUNBUFFERED": "1",
            "PYTHONIOENCODING": "utf-8",
            "PIP_DISABLE_PIP_VERSION_CHECK": "1",
            "PIP_NO_INPUT": "1",
            "NPM_CONFIG_UPDATE_NOTIFIER": "false",
        }

    def _as_user(self):
        if not IS_ROOT:
            return {}
        su = sys_uid(self.uid)
        return {"user": su, "group": su, "extra_groups": []}

    def _limits(self):
        if resource is None:
            return None

        def fn():
            try:
                resource.setrlimit(resource.RLIMIT_FSIZE, (500 * 1024 * 1024,) * 2)
                resource.setrlimit(resource.RLIMIT_NPROC, (512, 512))
            except (ValueError, OSError):
                pass

        return fn

    def _exec(self, cmd, timeout=900, slow=0.0):
        """ينفّذ أمراً ويبث مخرجاته للسجل سطراً بسطر. يرجع (رمز الخروج)"""
        self.log("info", "$ " + " ".join(cmd))
        try:
            self.proc = subprocess.Popen(
                cmd,
                cwd=self.dir,
                env=self._env(),
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                stdin=subprocess.DEVNULL,
                start_new_session=True,
                preexec_fn=self._limits(),
                **self._as_user(),
                text=True,
                encoding="utf-8",
                errors="replace",
                bufsize=1,
            )
        except FileNotFoundError:
            self.log("err", "الأداة غير مثبتة على الخادم: " + cmd[0])
            return 127
        timer = threading.Timer(timeout, self._kill)
        timer.start()
        try:
            for line in self.proc.stdout:
                line = line.rstrip("\n")
                if line.strip():
                    self.log(kind_of(line), line)
                    if slow:
                        time.sleep(slow)
                if self.stop_flag or self.restart_flag:
                    break
        finally:
            timer.cancel()
        if self.stop_flag or self.restart_flag:
            self._kill()
        return self.proc.wait()

    # ----- المراحل -----
    def _check(self):
        files = list_files(self.uid, self.lang)
        files = {k: v for k, v in files.items() if not k.endswith("/.keep")}
        main = LANGS[self.lang]["main"]
        self.log("info", "› فحص الملفات (%d ملف)" % len(files))
        if main not in files:
            self.log("err", "الملف الرئيسي %s غير موجود" % main)
            self.log("warn", "أنشئ ملفاً باسم %s داخل قسم الملفات." % main)
            return False
        self.log("ok", main + " ✓")
        bad = False
        for name in sorted(files):
            ext = name.rsplit(".", 1)[-1].lower()
            cmd = {
                "py": [sys.executable, "-m", "py_compile", name],
                "js": ["node", "--check", name],
                "php": ["php", "-l", name],
            }.get(ext)
            if not cmd or (ext, self.lang) not in (("py", "python"), ("js", "js"), ("php", "php")):
                continue
            try:
                r = subprocess.run(
                    cmd, cwd=self.dir, capture_output=True, text=True, timeout=30,
                    env=self._env(), **self._as_user(),
                )
            except (FileNotFoundError, subprocess.TimeoutExpired):
                continue
            if r.returncode != 0:
                bad = True
                self.log("err", "خطأ في الملف " + name)
                for ln in (r.stderr or r.stdout).strip().splitlines()[-8:]:
                    self.log("err", ln)
        if bad:
            self.log("warn", "تم إيقاف التشغيل. صحّح الأخطاء وأعد التشغيل.")
            return False
        return True

    def _install(self):
        d = self.dir
        if self.lang == "python":
            req = os.path.join(d, "requirements.txt")
            has_req = os.path.isfile(req) and open(req, encoding="utf-8", errors="replace").read().strip()
            if not os.path.isdir(os.path.join(d, ".venv")):
                self.log("info", "› إنشاء بيئة بايثون معزولة")
                if self._exec([sys.executable, "-m", "venv", ".venv"], timeout=180) != 0:
                    self.log("err", "فشل إنشاء البيئة")
                    return False
            if has_req:
                self.log("info", "› تثبيت المكتبات تلقائياً من requirements.txt")
                code = self._exec(
                    [".venv/bin/python", "-m", "pip", "install", "-r", "requirements.txt",
                     "--progress-bar", "off"], slow=0.25)
                if self.stop_flag:
                    return False
                if code != 0:
                    self.log("err", "فشل تثبيت المكتبات (رمز %d)" % code)
                    return False
                self.log("ok", "تم تثبيت المكتبات ✓")
        elif self.lang == "js" and os.path.isfile(os.path.join(d, "package.json")):
            self.log("info", "› تثبيت المكتبات تلقائياً (npm install)")
            code = self._exec(["npm", "install", "--no-audit", "--no-fund"], slow=0.25)
            if self.stop_flag:
                return False
            if code != 0:
                self.log("err", "فشل تثبيت المكتبات (رمز %d)" % code)
                return False
            self.log("ok", "تم تثبيت المكتبات ✓")
        elif self.lang == "php" and os.path.isfile(os.path.join(d, "composer.json")):
            self.log("info", "› تثبيت المكتبات تلقائياً (composer install)")
            code = self._exec(["composer", "install", "--no-interaction", "--no-progress"], slow=0.25)
            if self.stop_flag:
                return False
            if code != 0:
                self.log("err", "فشل تثبيت المكتبات (رمز %d)" % code)
                return False
            self.log("ok", "تم تثبيت المكتبات ✓")
        return True

    def _run_cmd(self):
        main = LANGS[self.lang]["main"]
        if self.lang == "python":
            return [".venv/bin/python", "-u", main]
        if self.lang == "js":
            return ["node", main]
        return ["php", main]

    def _worker(self):
        run_id = None
        try:
            if not self._check():
                self.state = "error"
                return
            self.state = "installing"
            if not self._install():
                self.state = "stopped" if self.stop_flag else "error"
                return
            fails = 0
            while not self.stop_flag:
                self.restart_flag = False
                self.state = "running"
                self.log("info", "› تشغيل " + LANGS[self.lang]["main"])
                t0 = time.time()
                with dblock:
                    cur = db.execute("INSERT INTO runs(user_id,lang,started) VALUES(?,?,?)",
                                     (self.uid, self.lang, t0))
                    db.commit()
                    run_id = cur.lastrowid
                watchdog = threading.Timer(RESTART_EVERY, self._daily_restart)
                watchdog.start()
                code = self._exec(self._run_cmd(), timeout=10 ** 9)
                watchdog.cancel()
                q("UPDATE runs SET ended=?, exit_code=? WHERE id=?",
                  (time.time(), code, run_id), commit=True)
                if self.stop_flag:
                    break
                if self.restart_flag:
                    self.log("info", "› إعادة التشغيل الدورية (كل 24 ساعة)")
                    continue
                if code == 0:
                    self.log("ok", "انتهى تشغيل البرنامج بنجاح (رمز الخروج 0)")
                    break
                if time.time() - t0 > 60:
                    fails = 0
                fails += 1
                self.log("warn", "البوت توقف (رمز الخروج %s)" % code)
                if fails > 5:
                    self.log("err", "تكرر التوقف 5 مرات — تم الإيقاف. راجع الأخطاء أعلاه.")
                    self.state = "error"
                    return
                self.log("info", "› إعادة تشغيل تلقائية بعد 5 ثواني…")
                for _ in range(50):
                    if self.stop_flag:
                        break
                    time.sleep(0.1)
            self.state = "stopped"
        except Exception as e:  # noqa
            self.log("err", "خطأ داخلي في الخادم: %r" % (e,))
            self.state = "error"
        finally:
            q("INSERT INTO projects(user_id,lang,last_state) VALUES(?,?,?) "
              "ON CONFLICT(user_id,lang) DO UPDATE SET last_state=?",
              (self.uid, self.lang, self.state, self.state), commit=True)

    def _daily_restart(self):
        self.restart_flag = True
        self._kill()


PROJECTS = {}
plock = threading.Lock()


def get_project(uid, lang):
    with plock:
        k = (uid, lang)
        if k not in PROJECTS:
            PROJECTS[k] = Project(uid, lang)
        return PROJECTS[k]


# ───────────────────────── HTTP ─────────────────────────
class Err(Exception):
    def __init__(self, status, msg):
        self.status, self.msg = status, msg


USER_RE = re.compile(r"^[A-Za-z0-9_]{3,20}$")


class H(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "HostServer/1.0"

    def log_message(self, fmt, *a):
        sys.stderr.write("%s %s\n" % (self.address_string(), fmt % a))

    def _send(self, status, obj):
        data = json.dumps(obj, ensure_ascii=False).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _body(self):
        n = int(self.headers.get("Content-Length") or 0)
        if n > MAX_TOTAL + 1024 * 1024:
            raise Err(413, "الطلب كبير جداً")
        raw = self.rfile.read(n) if n else b"{}"
        try:
            return json.loads(raw or b"{}")
        except ValueError:
            raise Err(400, "JSON غير صالح")

    def _user(self):
        auth = self.headers.get("Authorization", "")
        tok = auth[7:] if auth.startswith("Bearer ") else ""
        row = q("SELECT u.* FROM tokens t JOIN users u ON u.id=t.user_id WHERE t.token=?",
                (tok,), one=True)
        if not row:
            raise Err(401, "انتهت الجلسة، سجّل الدخول مرة ثانية")
        return row

    def _handle(self, method):
        u = urlparse(self.path)
        path, qs = u.path.rstrip("/"), parse_qs(u.query)
        try:
            if path == "/health":
                return self._send(200, {"ok": True})
            if method == "POST" and path == "/api/register":
                b = self._body()
                name, pw = str(b.get("username", "")).strip().lower(), str(b.get("password", ""))
                if not USER_RE.match(name):
                    raise Err(400, "اسم المستخدم: 3 إلى 20 حرف إنكليزي أو رقم أو _")
                if len(pw) < 6:
                    raise Err(400, "كلمة السر لازم 6 أحرف على الأقل")
                if q("SELECT 1 FROM users WHERE username=?", (name,), one=True):
                    raise Err(409, "اسم المستخدم مستخدم مسبقاً")
                salt = secrets.token_hex(16)
                q("INSERT INTO users(username,salt,pw,created) VALUES(?,?,?,?)",
                  (name, salt, hash_pw(salt, pw), time.time()), commit=True)
                row = q("SELECT * FROM users WHERE username=?", (name,), one=True)
                return self._send(200, self._session(row))
            if method == "POST" and path == "/api/login":
                b = self._body()
                name, pw = str(b.get("username", "")).strip().lower(), str(b.get("password", ""))
                row = q("SELECT * FROM users WHERE username=?", (name,), one=True)
                if not row or not secrets.compare_digest(row["pw"], hash_pw(row["salt"], pw)):
                    raise Err(401, "اسم المستخدم أو كلمة السر غير صحيحة")
                return self._send(200, self._session(row))

            user = self._user()
            uid = user["id"]
            if method == "GET" and path == "/api/me":
                return self._send(200, {"username": user["username"], "stage": user["stage"],
                                        "plan": user["plan"]})
            if method == "POST" and path == "/api/stage":
                st = str(self._body().get("stage", ""))
                if st not in ("provision", "plans", "creating", "ready"):
                    raise Err(400, "مرحلة غير صالحة")
                q("UPDATE users SET stage=? WHERE id=?", (st, uid), commit=True)
                return self._send(200, {"ok": True})
            m = re.match(r"^/api/files/(\w+)$", path)
            if m:
                lang = self._lang(m.group(1))
                if method == "GET":
                    return self._send(200, {"files": list_files(uid, lang)})
                if method == "PUT":
                    files = self._body().get("files")
                    if not isinstance(files, dict):
                        raise Err(400, "files مطلوب")
                    try:
                        replace_files(uid, lang, {str(k): str(v) for k, v in files.items()})
                    except ValueError as e:
                        raise Err(400, str(e))
                    return self._send(200, {"ok": True})
            m = re.match(r"^/api/run/(\w+)/(start|stop|restart|logs)$", path)
            if m:
                lang, act = self._lang(m.group(1)), m.group(2)
                p = get_project(uid, lang)
                if act == "logs" and method == "GET":
                    since = int((qs.get("since") or ["0"])[0])
                    with p.lock:
                        total = len(p.lines)
                        if since > total:
                            since = 0
                        chunk = p.lines[since:]
                    return self._send(200, {"lines": [{"k": k, "t": t} for k, t in chunk],
                                            "next": since + len(chunk), "state": p.state})
                if method == "POST":
                    if act == "start":
                        p.start()
                    elif act == "stop":
                        p.stop()
                    else:
                        p.stop(persist=False)
                        p.start()
                    return self._send(200, {"state": p.state})
            m = re.match(r"^/api/runs/(\w+)$", path)
            if m and method == "GET":
                lang = self._lang(m.group(1))
                rows = q("SELECT started,ended,exit_code FROM runs WHERE user_id=? AND lang=? "
                         "ORDER BY id DESC LIMIT 30", (uid, lang))
                return self._send(200, {"runs": [dict(r) for r in rows]})
            raise Err(404, "غير موجود")
        except Err as e:
            self._send(e.status, {"error": e.msg})
        except Exception as e:  # noqa
            sys.stderr.write("خطأ: %r\n" % (e,))
            self._send(500, {"error": "خطأ داخلي في الخادم"})

    def _lang(self, s):
        if s not in LANGS:
            raise Err(400, "لغة غير مدعومة")
        return s

    def _session(self, row):
        tok = secrets.token_hex(32)
        q("INSERT INTO tokens(token,user_id,created) VALUES(?,?,?)",
          (tok, row["id"], time.time()), commit=True)
        return {"token": tok, "username": row["username"], "stage": row["stage"]}

    def do_GET(self):
        self._handle("GET")

    def do_POST(self):
        self._handle("POST")

    def do_PUT(self):
        self._handle("PUT")


def resume_projects():
    for r in q("SELECT user_id,lang FROM projects WHERE want_running=1"):
        try:
            get_project(r["user_id"], r["lang"]).start()
        except Exception as e:  # noqa
            sys.stderr.write("resume failed: %r\n" % (e,))


if __name__ == "__main__":
    resume_projects()
    srv = ThreadingHTTPServer(("0.0.0.0", PORT), H)
    srv.daemon_threads = True
    print("Host server listening on :%d  data=%s" % (PORT, DATA), flush=True)

    def bye(*_):
        for p in list(PROJECTS.values()):
            p.stop_flag = True
            p._kill()
        os._exit(0)

    signal.signal(signal.SIGTERM, bye)
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        bye()
