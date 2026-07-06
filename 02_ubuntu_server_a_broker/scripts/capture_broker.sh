#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"
load_config
require_cmd tshark timeout
ensure_exp_dir
write_metadata

PCAP_FILE="$EXP_DIR/capture.pcapng"
CAPTURE_LOG="$EXP_DIR/capture.log"
FILTER="host $BROKER_CAPTURE_HOST and tcp port $MQTT_PORT"

echo "[INFO] Broker capture collector"
echo "[INFO] mode      : $DEPLOYMENT_MODE"
echo "[INFO] interface : $BROKER_IFACE"
echo "[INFO] filter    : $FILTER"
echo "[INFO] duration  : ${CAPTURE_DURATION}s"
echo "[INFO] output    : $PCAP_FILE"

timeout --foreground "$CAPTURE_DURATION" tshark \
  -i "$BROKER_IFACE" \
  -f "$FILTER" \
  -w "$PCAP_FILE" \
  > "$CAPTURE_LOG" 2>&1 || status=$?

status="${status:-0}"
if [[ "$status" -ne 0 && "$status" -ne 124 ]]; then
  echo "[ERR] tshark failed. See $CAPTURE_LOG" >&2
  exit "$status"
fi

echo "[OK] capture saved: $PCAP_FILE"
