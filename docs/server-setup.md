# Настройка сервера devops-vm

## 8. Веб-сервер

Установка пакетов:

```bash
sudo apt update
sudo apt install -y nginx rsync openssl
```

Конфигурация ресурса: /etc/nginx/sites-available/devops-site.
Ссылка активного ресурса: /etc/nginx/sites-enabled/devops-site.
Стандартный ресурс отключён удалением ссылки sites-enabled/default.

Каталог сайта: /var/www/devops-site.
Владелец: devops:devops.
Права каталогов: 755, файлов: 644.
Пользователь www-data может читать сайт, но не изменять его.

Сертификат: /etc/ssl/certs/devops.crt.
Владелец root:root, права 644.

Закрытый ключ: /etc/ssl/private/devops.key.
Владелец root:root, права 600.

Команда создания самоподписанного сертификата:

```bash
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/devops.key -out /etc/ssl/certs/devops.crt -subj "/CN=devops.local" -addext "subjectAltName=DNS:devops.local"
```

Срок действия: 365 дней.
Созданный сертификат действует с 26.10.2026 до 26.10.2027.
SAN: DNS:devops.local.

Nginx обслуживает HTTPS на порту 443.
Запросы HTTP на порт 80 перенаправляются на HTTPS с кодом 301.
Разрешены TLSv1.2 и TLSv1.3.

Проверка и применение конфигурации:

```bash
sudo nginx -t && sudo systemctl reload nginx
```

Журналы:
- /var/log/nginx/devops-site.access.log
- /var/log/nginx/devops-site.error.log

Доставка выполняется из WSL сценарием scripts/deploy.sh.
Права при доставке нормализуются параметром --chmod=D755,F644.
Закрытый ключ в репозиторий не добавляется.
4.	Текст раздела 9 документа.

## 9. Контейнеризация

### Установка Docker

Docker Engine Community 29.9.2 установлен из официального APT-репозитория Docker для Ubuntu 26.04:
https://download.docker.com/linux/ubuntu

Установлены пакеты: docker-ce, docker-ce-cli, containerd.io, docker-buildx-plugin, docker-compose-plugin.

Версия Docker Compose — v5.6.1.

Служба включена в автозагрузку:

```bash
sudo systemctl enable --now docker
```

В группу docker входит пользователь devops. Добавление пользователя:

```bash
sudo usermod -aG docker devops
```

После добавления требуется повторный вход в SSH-сессию. Участник группы docker фактически получает права уровня root.

Для устранения тайм-аутов загрузки в /etc/docker/daemon.json задано:

```json
{
  "max-concurrent-downloads": 1
}
```

Проверка и применение настройки:

```bash
sudo dockerd --validate --config-file=/etc/docker/daemon.json
sudo systemctl restart docker
```

### Расположение проекта и секретов

Исходный код находится в каталоге app/ репозитория devops-course-2026.

На сервере проект расположен в /home/devops/app.
Конфигурация Compose: /home/devops/app/docker-compose.yml.

Доставка из корня репозитория в WSL:

```bash
rsync -avz --delete --exclude=.env --chmod=D755,F644 --dry-run app/ devops:app/
rsync -avz --delete --exclude=.env --chmod=D755,F644 app/ devops:app/
```

Файл /home/devops/app/.env создаётся только на сервере.
Владелец — devops:devops, права — 600.

Файл содержит переменные:
POSTGRES_DB, POSTGRES_USER, POSTGRES_PASSWORD, DB_HOST.

Значения POSTGRES_DB и POSTGRES_USER — app.
Значение DB_HOST — db.
Пароль сформирован командой openssl rand -hex 24.

Действующий пароль в документацию не включается.
.env исключён из Git через .gitignore и из контекста сборки через app/.dockerignore.
Безопасный шаблон хранится в app/.env.example.

### Сервисы, сеть и порты

Сервис app использует образ devops-app:1.0.
Процесс приложения работает от непривилегированного пользователя app.

Порт приложения опубликован только на локальном адресе сервера:

```yaml
ports:
  - "127.0.0.1:5000:5000"
```

Сервис db использует образ postgres:16-alpine.
Порт PostgreSQL 5432 на сервере не опубликован.

Сервисы подключены к сети app_backend.
Встроенный DNS Docker разрешает имя db в адрес контейнера PostgreSQL.
Приложение подключается к базе через DB_HOST=db.

Приложение запускается после готовности базы:
depends_on с условием service_healthy.
Готовность PostgreSQL проверяется командой pg_isready.
Для обоих сервисов задано restart: unless-stopped.

Запуск проекта на сервере:

```bash
cd /home/devops/app
docker compose up -d --build
docker compose ps
```

Проверка сети и портов на сервере:

```bash
docker network ls
docker compose exec app getent hosts db
sudo ss -tlnp | grep -E ':(5000|5432)\b'
```

### Хранение данных

Именованный том app_db_data подключён к /var/lib/postgresql/data контейнера PostgreSQL.

docker compose down удаляет контейнеры и сеть, но сохраняет том.
После повторного запуска счётчик посещений продолжает отсчёт.

docker compose down -v удаляет также том и данные.
После повторного запуска создаётся новая база, счётчик начинается с 1.

### Обратный прокси Nginx

В HTTPS-блок файла /etc/nginx/sites-available/devops-site добавлено:

```nginx
location /app/ {
    proxy_pass http://127.0.0.1:5000/;
    proxy_set_header Host              $host;
    proxy_set_header X-Real-IP         $remote_addr;
    proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

Существующий location / сохранён для статического сайта.

Завершающий символ / в proxy_pass заменяет префикс /app/ на /.
Запрос /app/health передаётся приложению как /health.

Проверка и применение конфигурации на сервере:

```bash
sudo nginx -t && sudo systemctl reload nginx
```

Проверка из WSL на Windows:

```bash
curl --cacert ~/devops.crt https://devops.local/app/
curl --cacert ~/devops.crt https://devops.local/app/health
curl --cacert ~/devops.crt -I https://devops.local/
```

Ожидаемые результаты: ответ со счётчиком, строка ok и код 200 для статического сайта.

При остановленном приложении Nginx возвращает 502 Bad Gateway.
В журнале /var/log/nginx/devops-site.error.log появляется запись:
connect() failed (111: Connection refused) while connecting to upstream.

Восстановление приложения на сервере:

```bash
cd /home/devops/app
docker compose start app
```
