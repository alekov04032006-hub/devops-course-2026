#!/usr/bin/env bash
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

check_db_health() {
    local status

    status="$(docker inspect -f '{{.State.Health.Status}}' app-db-1)" || return 1
    [[ "$status" == "healthy" ]]
}

check_container_ports() {
    local sockets address

    sockets="$(ss -H -ltn)" || return 1

    while read -r address; do
        case "$address" in
            *:5000|*:5432)
                [[ "$address" == "127.0.0.1:5000" ||
                   "$address" == "127.0.0.1:5432" ]] || return 1
                ;;
        esac
    done < <(printf '%s\n' "$sockets" | awk '{print $4}')

    return 0
}

check_env_permissions() {
    local mode

    mode="$(stat -c '%a' "$HOME/app/.env")" || return 1
    [[ "$mode" == "600" ]]
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

echo "[5] Контейнеризация"

check "Служба Docker активна" \
    systemctl is-active --quiet docker

check "Контейнер PostgreSQL healthy" \
    check_db_health

check "Порты 5000 и 5432 не слушаются на внешних адресах" \
    check_container_ports

check "Права файла app/.env равны 600" \
    check_env_permissions

exit "$FAILED"
