#!/usr/bin/env bash
set -uo pipefail

FAILED=0
CERT_MIN_SECONDS="${CERT_MIN_SECONDS:-2592000}"

check() {
    local description="$1"
    shift

    if "$@"; then
        echo "[OK] $description"
    else
        echo "[FAIL] $description"
        FAILED=1
    fi
}

check_permissions() {
    local writable key_mode

    writable="$(find /var/www/devops-site -perm -o+w)" || return 1
    key_mode="$(sudo stat -c '%a' /etc/ssl/private/devops.key)" || return 1

    [[ -z "$writable" && "$key_mode" == "600" ]]
}

echo "[4] Веб-сервер"

check "Служба nginx активна" \
    systemctl is-active --quiet nginx

check "Конфигурация nginx корректна" \
    sudo nginx -t

check "Сертификат действует ещё минимум ${CERT_MIN_SECONDS} секунд" \
    openssl x509 -in /etc/ssl/certs/devops.crt \
    -noout -checkend "$CERT_MIN_SECONDS"

check "Нет записи для всех; права закрытого ключа 600" \
    check_permissions

exit "$FAILED"
