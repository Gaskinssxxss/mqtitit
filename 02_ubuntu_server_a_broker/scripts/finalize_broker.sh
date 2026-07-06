#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"
load_config

PCAP_FILE="$EXP_DIR/capture.pcapng"
RAW_FILE="$EXP_DIR/raw_flow.csv"
if [[ ! -f "$PCAP_FILE" ]]; then
  echo "[ERR] capture tidak ditemukan: $PCAP_FILE" >&2
  exit 1
fi

"$SCRIPT_DIR/extract_raw_flow.sh" "$PCAP_FILE" "$RAW_FILE"
echo "[OK] Salin metadata.env dan raw_flow.csv dari folder berikut ke Windows:"
echo "     $EXP_DIR"
