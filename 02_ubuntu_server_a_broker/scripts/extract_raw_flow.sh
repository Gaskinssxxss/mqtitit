#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"
load_config
require_cmd tshark

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <capture.pcapng> [output.csv]" >&2
  exit 1
fi

PCAP_FILE="$1"
OUT_CSV="${2:-${PCAP_FILE%.*}_raw_flow.csv}"

if [[ ! -f "$PCAP_FILE" ]]; then
  echo "[ERR] PCAP not found: $PCAP_FILE" >&2
  exit 1
fi

DISPLAY_FILTER="ip.addr == $BROKER_CAPTURE_HOST && tcp.port == $MQTT_PORT"

echo "[INFO] input  : $PCAP_FILE"
echo "[INFO] filter : $DISPLAY_FILTER"
echo "[INFO] output : $OUT_CSV"

tshark -r "$PCAP_FILE" \
  -Y "$DISPLAY_FILTER" \
  -T fields \
  -e frame.time_epoch \
  -e frame.len \
  -e ip.src \
  -e ip.dst \
  -e ip.proto \
  -e tcp.srcport \
  -e tcp.dstport \
  -e tcp.flags \
  -e tcp.flags.syn \
  -e tcp.flags.ack \
  -e tcp.flags.reset \
  -e tcp.flags.fin \
  -e tcp.stream \
  -e mqtt.msgtype \
  -e mqtt.clientid \
  -e mqtt.topic \
  -E header=y \
  -E separator=, \
  -E quote=d \
  -E occurrence=f \
  > "$OUT_CSV"

echo "[OK] raw flow saved: $OUT_CSV"
