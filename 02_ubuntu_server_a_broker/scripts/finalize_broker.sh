#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id)
      RUN_ID="$2"
      shift 2
      ;;
    --scenario)
      SCENARIO="$2"
      shift 2
      ;;
    -h|--help)
      cat <<EOF
Usage:
  ./scripts/finalize_broker.sh --run-id RUN_ID [--scenario SCENARIO]

Options:
  --run-id RUN_ID       Folder eksperimen yang akan diproses.
  --scenario SCENARIO   normal|syn_flood|syn_flood_rate_limit.

Example:
  ./scripts/finalize_broker.sh --run-id normal_01
EOF
      exit 0
      ;;
    *)
      echo "[ERR] unknown option: $1" >&2
      exit 1
      ;;
  esac
done

load_config

PCAP_FILE="$EXP_DIR/capture.pcapng"
RAW_FILE="$EXP_DIR/raw_flow.csv"
if [[ ! -f "$PCAP_FILE" ]]; then
  echo "[ERR] capture tidak ditemukan: $PCAP_FILE" >&2
  echo "[INFO] Pastikan RUN_ID sama dengan command run_broker.sh." >&2
  echo "[INFO] Contoh: ./scripts/finalize_broker.sh --run-id normal_01" >&2
  exit 1
fi

"$SCRIPT_DIR/extract_raw_flow.sh" "$PCAP_FILE" "$RAW_FILE"
echo "[OK] Salin metadata.env dan raw_flow.csv dari folder berikut ke Windows:"
echo "     $EXP_DIR"
