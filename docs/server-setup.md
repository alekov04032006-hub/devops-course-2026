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
