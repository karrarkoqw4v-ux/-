FROM python:3.12-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential libffi-dev libssl-dev libxml2-dev libxslt1-dev \
      libjpeg-dev zlib1g-dev git curl ca-certificates \
      nodejs npm \
      php-cli php-mbstring php-curl php-xml php-zip php-gd php-sqlite3 php-mysql composer \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
# مكاتب بايثون القوية الجاهزة مسبقاً (بيئات المستخدمين ترثها)
COPY base-requirements.txt .
RUN pip install --no-cache-dir -r base-requirements.txt
# tgcrypto يُبنى من المصدر (تسريع تشفير تيليجرام) — فشله لا يمنع البناء
RUN pip install --no-cache-dir tgcrypto || true
# مكاتب Node القوية (متاحة لكل البوتات عبر NODE_PATH)
COPY base-node.txt .
RUN npm install -g --no-audit --no-fund $(tr '\n' ' ' < base-node.txt) && npm cache clean --force
COPY server.py .
ENV PORT=8080 DATA_DIR=/data
VOLUME /data
EXPOSE 8080
# يعمل كـ root ليشغّل كل مستخدم تحت uid مستقل (عزل الملفات)
CMD ["python", "server.py"]
