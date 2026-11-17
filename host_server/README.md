# خادم الاستضافة

خادم حقيقي بدون مكتبات خارجية: حسابات + قاعدة بيانات SQLite + حفظ ملفات كل مستخدم
+ تشغيل فعلي للبوتات (Python / PHP / JavaScript) مع تثبيت المكتبات تلقائياً وسجل حي.

## تشغيل محلي
    python3 server.py          # المنفذ 8080، البيانات في ./data

## نشر (Docker)
    docker build -t host-server .
    docker run -d -p 8080:8080 -v hostdata:/data --restart always host-server

يصلح لأي VPS أو منصة تدعم Docker + قرص دائم (Volume) مثل Railway / Fly.io / Render (خطة مدفوعة بقرص).
بعد النشر ضع الرابط (https://...) في التطبيق: شاشة الدخول ← «إعدادات الخادم»،
أو ضعه كمتغير `API_BASE` في GitHub (Settings ← Variables) ليُدمج وقت بناء الـ APK.

## العزل
عند التشغيل كـ root (Docker) كل مستخدم يشغّل أكواده تحت uid نظام مستقل ومجلده 0700،
فلا يستطيع بوت مستخدم قراءة ملفات مستخدم آخر ولا قاعدة البيانات.
هذا عزل على مستوى الملفات فقط — للحماية الكاملة من أكواد خبيثة شغّل الخادم على جهاز/حاوية مخصصة.
الخطة المجانية: إعادة تشغيل تلقائية كل 24 ساعة، وإعادة تشغيل عند التعطل (حتى 5 مرات).

## المكاتب الجاهزة مسبقاً
تُثبَّت عند بناء الصورة (راجع `base-requirements.txt` و`base-node.txt`) وتصير متاحة لكل البوتات فوراً:
- بايثون: aiogram، python-telegram-bot، pyTelegramBotAPI، telethon، pyrogram، discord.py، requests، aiohttp، httpx، flask، fastapi، pandas، numpy، pillow، sqlalchemy، pymongo، redis، yt-dlp وغيرها.
- Node: telegraf، node-telegram-bot-api، grammy، discord.js، axios، express، cheerio، mongoose.
- PHP: إضافات mbstring وcurl وxml وzip وgd وsqlite وmysql + composer.
بيئة كل مستخدم تُنشأ بـ `--system-site-packages` فترث هذه المكاتب، وما يضيفه المستخدم في `requirements.txt` يُثبَّت فوقها.
لتعديل القائمة عدّل الملفين ثم أعد `bash deploy.sh` (البناء الأول يستغرق 5–10 دقائق).
