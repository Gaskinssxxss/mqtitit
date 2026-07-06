#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"
load_config

echo "Peran      : Ubuntu Server A - broker, capture, rate limiting"
echo "Broker     : $BROKER_CAPTURE_HOST:$MQTT_PORT"
echo "Interface  : $BROKER_IFACE"
echo "Scenario   : $SCENARIO"
echo "Run ID     : $RUN_ID"
echo "Capture    : ${CAPTURE_DURATION}s"
echo

missing=0
for cmd in mosquitto tshark nft timeout ip ss awk grep; do
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "[OK] $cmd: $(command -v "$cmd")"
  else
    echo "[MISS] $cmd"
    missing=1
  fi
done

if ip link show "$BROKER_IFACE" >/dev/null 2>&1; then
  echo "[OK] interface tersedia: $BROKER_IFACE"
else
  echo "[MISS] interface tidak ditemukan: $BROKER_IFACE"
  missing=1
fi

if ss -lnt | awk '{print $4}' | grep -Eq "[:.]${MQTT_PORT}$"; then
  echo "[OK] ada layanan yang mendengarkan pada port $MQTT_PORT"
else
  echo "[MISS] tidak ada layanan yang mendengarkan pada port $MQTT_PORT"
  missing=1
fi

exit "$missing"
