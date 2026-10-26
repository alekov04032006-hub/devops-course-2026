#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
REMOTE="devops"
REMOTE_DIR="/var/www/devops-site/"
SITE_URL="https://devops.local"
CA_CERT="${HOME}/devops.crt"
DRY_RUN=false

fail() {
    echo "Ошибка: $*" >&2
    exit 1
}

case "${1:-}" in
    "") ;;
    --dry-run) DRY_RUN=true ;;
    *) fail "Использование: scripts/deploy.sh [--dry-run]" ;;
esac

[[ $# -le 1 ]] || fail "Слишком много аргументов"
[[ -f "$ROOT/site/index.html" ]] || fail "Нет site/index.html"

[[ -z "$(git -C "$ROOT" status --porcelain)" ]] \
    || fail "Есть незакоммиченные изменения"

OPTIONS=(-avz --delete --chmod=D755,F644)
if "$DRY_RUN"; then
    OPTIONS+=(--dry-run)
fi

if ! rsync "${OPTIONS[@]}" \
    -e "ssh -o BatchMode=yes -o ConnectTimeout=5" \
    "$ROOT/site/" "${REMOTE}:${REMOTE_DIR}"; then
    fail "Не удалось доставить файлы"
fi

if "$DRY_RUN"; then
    echo "Пробный запуск завершён, сервер не изменён"
    exit 0
fi

if ! curl --fail --silent --show-error \
    --connect-timeout 5 --max-time 15 \
    --cacert "$CA_CERT" "$SITE_URL" > /dev/null; then
    fail "Проверка HTTPS не пройдена"
fi

echo "Деплой успешен. Коммит: $(git -C "$ROOT" rev-parse --short HEAD)"
