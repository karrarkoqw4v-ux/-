FROM python:3.12-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
      nodejs npm php-cli php-mbstring php-curl composer ca-certificates \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY server.py .
ENV PORT=8080 DATA_DIR=/data
VOLUME /data
EXPOSE 8080
# يعمل كـ root ليستطيع تشغيل كل مستخدم تحت uid مستقل (عزل الملفات)
CMD ["python", "server.py"]
