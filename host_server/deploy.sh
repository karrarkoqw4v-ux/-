#!/usr/bin/env bash
# نشر خادم الاستضافة على VPS (Ubuntu/Debian). شغّله كـ root:  bash deploy.sh
set -e
command -v docker >/dev/null || curl -fsSL https://get.docker.com | sh
mkdir -p /opt/host-server && cd /opt/host-server
# ضع هنا ملفي server.py و Dockerfile (من الـ ZIP) ثم:
docker build -t host-server .
docker rm -f host-server 2>/dev/null || true
docker run -d --name host-server -p 8080:8080 -v hostdata:/data --restart always host-server
sleep 2
echo "الخادم يعمل. جرّب: curl http://127.0.0.1:8080/health"
echo "العنوان في التطبيق: http://$(curl -s ifconfig.me):8080"
