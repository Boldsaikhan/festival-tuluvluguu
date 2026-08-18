#!/usr/bin/env bash
# Серверийн нэг удаагийн тохиргоо — mcloud `manage-dornogovi` (Ubuntu 24.04).
#
# Ажиллуулах (root эрхээр, VNC консол дээр ганц мөр):
#   sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/Boldsaikhan/festival-tuluvluguu/main/scripts/server-setup.sh)"
#
# Юу хийдэг вэ:
#   1. git / rsync / nginx / cron суулгана
#   2. Repo-г /opt/festival-tuluvluguu-д татна (эсвэл шинэчилнэ)
#   3. Эхний deploy хийж /var/www/uureg-biyelelt-д нийтэлнэ
#   4. nginx vhost үүсгэж идэвхжүүлнэ
#   5. Cron нэмж 2 минут тутам GitHub-ыг шалгадаг болгоно
#
# Дахин ажиллуулахад аюулгүй (idempotent).

set -euo pipefail

REPO_URL="https://github.com/Boldsaikhan/festival-tuluvluguu.git"
REPO_DIR="/opt/festival-tuluvluguu"
WEB_ROOT="/var/www/uureg-biyelelt"
SITE="uureg-biyelelt"
CRON_LINE="*/2 * * * * $REPO_DIR/scripts/auto-deploy.sh >> /var/log/uureg-deploy.log 2>&1"

if [ "$(id -u)" -ne 0 ]; then
  echo "ЭНЭ SCRIPT-ЫГ root эрхээр ажиллуулна: sudo bash ..." >&2
  exit 1
fi

echo "==> 1/5 Багц суулгаж байна…"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq git rsync nginx cron curl >/dev/null

echo "==> 2/5 Repo…"
if [ -d "$REPO_DIR/.git" ]; then
  git -C "$REPO_DIR" fetch --quiet origin main
  git -C "$REPO_DIR" reset --hard --quiet origin/main
  echo "    шинэчлэв: $REPO_DIR"
else
  git clone --quiet "$REPO_URL" "$REPO_DIR"
  echo "    татав: $REPO_DIR"
fi
chmod +x "$REPO_DIR/deploy.sh" "$REPO_DIR/scripts/auto-deploy.sh"

echo "==> 3/5 Эхний deploy…"
"$REPO_DIR/deploy.sh"

echo "==> 4/5 nginx…"
cat > "/etc/nginx/sites-available/$SITE" <<CONF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    root $WEB_ROOT;
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    # Статик сайт — index.html-ийг кэшлэхгүй, шинэчлэлт шууд харагдана.
    location = /index.html {
        add_header Cache-Control "no-cache, must-revalidate";
    }
}
CONF
ln -sf "/etc/nginx/sites-available/$SITE" "/etc/nginx/sites-enabled/$SITE"
# Ubuntu-ийн анхны хуудас мөн default_server эзэлдэг тул салгана.
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl enable --now nginx >/dev/null 2>&1 || systemctl reload nginx
systemctl reload nginx

echo "==> 5/5 Cron…"
systemctl enable --now cron >/dev/null 2>&1 || true
if crontab -l 2>/dev/null | grep -Fq "$REPO_DIR/scripts/auto-deploy.sh"; then
  echo "    cron аль хэдийн тохируулагдсан"
else
  ( crontab -l 2>/dev/null; echo "$CRON_LINE" ) | crontab -
  echo "    cron нэмэв (2 минут тутам)"
fi

echo
echo "──────────── ШАЛГАЛТ ────────────"
printf "nginx        : %s\n" "$(systemctl is-active nginx)"
printf "cron         : %s\n" "$(systemctl is-active cron)"
printf "commit       : %s\n" "$(git -C "$REPO_DIR" rev-parse --short HEAD)"
printf "вэб хавтас   : %s файл\n" "$(find "$WEB_ROOT" -type f | wc -l)"
printf "локал хариу  : %s\n" "$(curl -s -o /dev/null -w '%{http_code}' http://localhost/)"
echo "IP           : $(hostname -I | awk '{print $1}')"
echo "─────────────────────────────────"
echo "Дууслаа. GitHub-д push хийхэд 2 минутын дотор автоматаар шинэчлэгдэнэ."
echo "Гараар шалгах: $REPO_DIR/scripts/auto-deploy.sh --force"
echo "Бүртгэл харах: tail -f /var/log/uureg-deploy.log"
