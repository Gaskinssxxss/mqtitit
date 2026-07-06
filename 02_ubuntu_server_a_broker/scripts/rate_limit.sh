#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"
load_config
require_cmd nft

TABLE="inet mqtt_dos"
CHAIN="input_mqtt_limit"

usage() {
  cat <<EOF
Usage: $0 <enable|disable|status|reset>

Controls nftables rate limiting for TCP SYN packets to the MQTT broker port.
Current config:
  BROKER_HOST=$BROKER_HOST
  BROKER_CAPTURE_HOST=$BROKER_CAPTURE_HOST
  MQTT_PORT=$MQTT_PORT
  RL_RATE=$RL_RATE
  RL_BURST=$RL_BURST
EOF
}

cmd="${1:-}"
case "$cmd" in
  enable)
    sudo nft add table inet mqtt_dos 2>/dev/null || true
    sudo nft "add chain $TABLE $CHAIN { type filter hook input priority 0; policy accept; }" 2>/dev/null || true
    sudo nft flush chain "$TABLE" "$CHAIN"
    sudo nft add rule "$TABLE" "$CHAIN" ip daddr "$BROKER_CAPTURE_HOST" tcp dport "$MQTT_PORT" tcp flags syn / syn limit rate over "$RL_RATE" burst "$RL_BURST" packets counter drop
    sudo nft add rule "$TABLE" "$CHAIN" ip daddr "$BROKER_CAPTURE_HOST" tcp dport "$MQTT_PORT" tcp flags syn / syn counter accept
    echo "[OK] rate limiting enabled for $BROKER_CAPTURE_HOST:$MQTT_PORT"
    ;;
  disable|reset)
    sudo nft delete table inet mqtt_dos 2>/dev/null || true
    echo "[OK] rate limiting disabled"
    ;;
  status)
    sudo nft list table inet mqtt_dos || true
    ;;
  *)
    usage
    exit 1
    ;;
esac
