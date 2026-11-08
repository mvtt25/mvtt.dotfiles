#!/usr/bin/env bash

set -euo pipefail

# The tokens live in ~/.config/zsh/local.zsh: without them, skip instead of failing every task.
if [ -z "${TELEGRAM_TOKEN:-}" ] || [ -z "${TELEGRAM_CHAT_ID:-}" ]; then
  echo "telegram-notify: TELEGRAM_TOKEN/TELEGRAM_CHAT_ID not set, skipping" >&2
  exit 0
fi

STATUS="${1:-success}"
shift || true

MSG="${*:-Task completed}"

HOST=$(hostname)
TIME=$(date '+%H:%M')

PROJECT=$(basename "$(pwd)")

BRANCH=$(git branch --show-current 2>/dev/null || echo "-")

case "$STATUS" in
success)
  ICON="✅"
  ;;
error)
  ICON="❌"
  ;;
*)
  ICON="🤖"
  ;;
esac

curl -sS --fail --max-time 10 \
  -X POST \
  "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
  -d chat_id="${TELEGRAM_CHAT_ID}" \
  --data-urlencode "text=$ICON [$TIME][$HOST][$PROJECT][$BRANCH]

$MSG" \
  >/dev/null
