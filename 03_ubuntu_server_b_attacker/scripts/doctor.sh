#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"
load_config

echo "Peran      : Ubuntu Server B - attacker pengujian"
echo "Target     : $BROKER_HOST:$MQTT_PORT"
echo "Scenario   : $SCENARIO"
echo "Run ID     : $RUN_ID"
echo

missing=0
for cmd in hping3 timeout ping; do
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "[OK] $cmd: $(command -v "$cmd")"
  else
    echo "[MISS] $cmd"
    missing=1
  fi
done

if ping -c 1 -W 2 "$BROKER_HOST" >/dev/null 2>&1; then
  echo "[OK] Ubuntu Server A dapat dijangkau."
else
  echo "[WARN] Target tidak menjawab ping. Periksa jaringan atau firewall."
fi

exit "$missing"
