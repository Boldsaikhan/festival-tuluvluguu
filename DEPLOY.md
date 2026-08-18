# Deploy — mcloud `manage-dornogovi` сервер (Ubuntu)

GitHub-ын `main` branch руу push хийхэд сервер өөрөө татаж, вэб хавтас руу нийтэлдэг
болгох тохиргоо. Нэг удаа хийхэд хангалттай.

| | |
|---|---|
| Repo | https://github.com/Boldsaikhan/festival-tuluvluguu (public) |
| Сервер | mcloud.gov.mn → `manage-dornogovi` (Ubuntu) |
| Repo байрлал серверт | `/opt/festival-tuluvluguu` |
| Вэб хавтас | `/var/www/uureg-biyelelt` |
| Deploy хэлбэр | **pull-based** — серверийн cron 2 минут тутам шалгана |
| Нөөц зам | `.github/workflows/deploy.yml` (гараар ажиллуулна, firewall нээлттэй үед) |

---

## 1. Яагаад pull-based вэ

GitHub Actions-ийн runner нь АНУ/Европт байрладаг. **НДТөвийн firewall гаднаас ирэх
урсгалыг хаадаг** нь `sudalgaa.dornogovi.gov.mn` төсөл дээр аль хэдийн батлагдсан
(Let's Encrypt порт 80 дээр унасан, SSH deploy мөн хүрээгүй). Тиймээс GitHub → сервер
чиглэлийн холболт найдваргүй.

`scripts/auto-deploy.sh` нь эсрэгээр **зөвхөн гадагш** чиглэсэн холболт (`git fetch`)
ашигладаг тул firewall-аас хамаарахгүй.

---

## 2. Серверийн тохиргоо (нэг удаа)

SSH-ээр серверт нэвтэрсний дараа root эрхээр:

```bash
# 2.1 Шаардлагатай багц
apt update && apt install -y git rsync nginx cron

# 2.2 Repo-г татах (public тул нууц үг шаардахгүй)
git clone https://github.com/Boldsaikhan/festival-tuluvluguu.git /opt/festival-tuluvluguu
chmod +x /opt/festival-tuluvluguu/deploy.sh /opt/festival-tuluvluguu/scripts/auto-deploy.sh

# 2.3 Эхний deploy
/opt/festival-tuluvluguu/deploy.sh

# 2.4 nginx vhost
cat > /etc/nginx/sites-available/uureg-biyelelt <<'CONF'
server {
    listen 80;
    server_name _;                      # домэйн бэлэн болмогц энд бичнэ

    root /var/www/uureg-biyelelt;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    # Статик сайт — index.html-ийг кэшлэхгүй, шинэчлэлт шууд харагдана.
    location = /index.html {
        add_header Cache-Control "no-cache, must-revalidate";
    }
}
CONF
ln -sf /etc/nginx/sites-available/uureg-biyelelt /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx

# 2.5 Cron — 2 минут тутам GitHub-ыг шалгана
( crontab -l 2>/dev/null; \
  echo '*/2 * * * * /opt/festival-tuluvluguu/scripts/auto-deploy.sh >> /var/log/uureg-deploy.log 2>&1' \
) | crontab -
```

Шалгах:

```bash
/opt/festival-tuluvluguu/scripts/auto-deploy.sh --force   # гараар нэг удаа
tail -f /var/log/uureg-deploy.log                          # cron-ийн бүртгэл
curl -sI http://localhost/ | head -1                       # HTTP 200 байх ёстой
```

---

## 3. Хэрхэн ажилладаг

```
Локал засвар → git push → GitHub (main)
                             │
                             ├─→ GitHub Pages (шууд, ~1 мин)
                             │      https://boldsaikhan.github.io/festival-tuluvluguu/
                             │
                             └─← сервер 2 мин тутам git fetch хийж шалгана
                                    шинэ commit байвал deploy.sh:
                                    git reset --hard origin/main
                                    rsync → /var/www/uureg-biyelelt
```

Өөрөөр хэлбэл push хийсний дараа **хамгийн ихдээ 2 минутын дотор** сервер дээр
шинэчлэгдэнэ. Хүлээхгүйн тулд серверт `auto-deploy.sh --force` ажиллуулж болно.

---

## 4. Тохируулж болох утгууд

`deploy.sh` нь орчны хувьсагчаар удирдагдана — өөр хавтас/branch хэрэглэвэл cron мөрөнд
дараах байдлаар өгнө:

| Хувьсагч | Анхдагч | Утга |
|---|---|---|
| `DEPLOY_BRANCH` | `main` | Дагах branch |
| `DEPLOY_WEB_ROOT` | `/var/www/uureg-biyelelt` | Вэб хавтас |
| `DEPLOY_WEB_USER` | `www-data` | Файлын эзэмшигч |

---

## 5. Домэйн ба HTTPS

`manage.dornogovi.gov.mn` одоогоор DNS-д **бүртгэгдээгүй** (NXDOMAIN). Домэйн заасны дараа:

1. `server_name`-д домэйнээ бичих → `nginx -t && systemctl reload nginx`
2. HTTPS: `apt install -y certbot python3-certbot-nginx && certbot --nginx -d <домэйн>`
   ⚠️ Let's Encrypt-ийн шалгалт **гаднаас порт 80 руу** ирдэг. НДТ-ийн firewall үүнийг
   хааж байвал `sudalgaa` төсөл дээрх шиг унана — тэр тохиолдолд DNS-01 сорил
   (домэйны TXT бичлэгээр) эсвэл НДТ-өөс 80/443 нээлгэх хүсэлт гаргана.

---

## 6. Нөөц зам — GitHub Actions (гараар)

`.github/workflows/deploy.yml` нь **push дээр ажиллахгүй**, зөвхөн Actions таб → *Run
workflow* дарахад ажиллана. Ашиглахын тулд 4 secret нэмнэ:
`SSH_HOST`, `SSH_PORT`, `SSH_USER`, `SSH_PRIVATE_KEY`.

Workflow эхлээд секретүүд бүрэн эсэх, дараа нь **порт хүрэх эсэхийг** шалгаад,
хүрэхгүй бол ойлгомжтой алдаа өгч зогсоно (firewall-ын асуудлыг тодорхой хэлнэ).
