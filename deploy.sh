#!/usr/bin/env bash
# festival-tuluvluguu — серверийн deploy script (mcloud / manage-dornogovi, Ubuntu).
#
# Ашиглах (сервер дээр):
#   /opt/festival-tuluvluguu/deploy.sh
#
# Юу хийдэг вэ: GitHub-аас сүүлийн хувилбарыг татаад, вэб сайтын хавтас руу
# статик файлуудыг хуулна. Энэ бол статик сайт тул composer/npm/migration
# байхгүй — зөвхөн файл хуулна.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$REPO_DIR"

BRANCH="${DEPLOY_BRANCH:-main}"
WEB_ROOT="${DEPLOY_WEB_ROOT:-/var/www/uureg-biyelelt}"
WEB_USER="${DEPLOY_WEB_USER:-www-data}"

echo "==> GitHub-аас татаж байна ($BRANCH)..."
git fetch --quiet origin "$BRANCH"
git reset --hard "origin/$BRANCH"

echo "==> Вэб хавтас руу хуулж байна: $WEB_ROOT"
mkdir -p "$WEB_ROOT"
# Сайтад хамаарахгүй файлуудыг хасна (repo дотоод баримт, script, git).
rsync -a --delete \
  --exclude '.git/' \
  --exclude '.github/' \
  --exclude 'scripts/' \
  --exclude 'tools/' \
  --exclude '*.md' \
  --exclude 'deploy.sh' \
  --exclude '.gitignore' \
  "$REPO_DIR"/ "$WEB_ROOT"/

if id -u "$WEB_USER" >/dev/null 2>&1; then
  chown -R "$WEB_USER":"$WEB_USER" "$WEB_ROOT"
fi
find "$WEB_ROOT" -type d -exec chmod 755 {} +
find "$WEB_ROOT" -type f -exec chmod 644 {} +

echo "==> Дууслаа: $(git rev-parse --short HEAD) — $(date -Is)"
