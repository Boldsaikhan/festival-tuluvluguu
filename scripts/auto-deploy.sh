#!/usr/bin/env bash
# Pull-based auto-deploy: сервер өөрөө GitHub-ыг тогтмол шалгаж, шинэ commit
# байвал deploy.sh-г ажиллуулна.
#
# Яагаад push-based биш вэ: GitHub Actions-ийн runner нь АНУ/Европт байрладаг
# бөгөөд НДТөвийн (mcloud.gov.mn) firewall гаднаас ирэх урсгалыг хаадаг нь
# sudalgaa.dornogovi төсөл дээр батлагдсан. Энэ script нь ЗӨВХӨН гадагш
# чиглэсэн холболт (git fetch) ашигладаг тул тэр хоригоос хамаарахгүй.
#
# Сервер дээр cron-д нэмэх:
#   */2 * * * * /opt/festival-tuluvluguu/scripts/auto-deploy.sh >> /var/log/uureg-deploy.log 2>&1
#
# Гар аргаар шалгах:
#   /opt/festival-tuluvluguu/scripts/auto-deploy.sh --force

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_DIR"

BRANCH="${DEPLOY_BRANCH:-main}"
FORCE="${1:-}"

# Хоёр cron зэрэг ажиллахаас сэргийлнэ.
exec 9>"/tmp/festival-auto-deploy.lock"
if ! flock -n 9; then
  echo "$(date -Is) өмнөх ажиллагаа дуусаагүй — алгаслаа"
  exit 0
fi

git fetch --quiet origin "$BRANCH"

local_sha="$(git rev-parse HEAD)"
remote_sha="$(git rev-parse "origin/$BRANCH")"

if [ "$local_sha" = "$remote_sha" ] && [ "$FORCE" != "--force" ]; then
  # Шинэ зүйл байхгүй — log цэвэр байхын тулд дуугүй гарна.
  exit 0
fi

echo "$(date -Is) шинэ commit илэрлээ: ${local_sha:0:7} -> ${remote_sha:0:7}"
"$REPO_DIR/deploy.sh"
echo "$(date -Is) deploy дууслаа: $(git rev-parse --short HEAD)"
