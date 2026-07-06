#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"
load_config

echo "[INFO] Memeriksa izin administrator untuk pengaturan rate limiting."
sudo -v

ensure_exp_dir
write_metadata

if [[ "$SCENARIO" == "syn_flood_rate_limit" ]]; then
  "$SCRIPT_DIR/rate_limit.sh" enable
  "$SCRIPT_DIR/rate_limit.sh" status > "$EXP_DIR/nft_before_capture.txt" 2>&1 || true
  trap '"$SCRIPT_DIR/rate_limit.sh" status > "$EXP_DIR/nft_after_capture.txt" 2>&1 || true; "$SCRIPT_DIR/rate_limit.sh" disable' EXIT
else
  "$SCRIPT_DIR/rate_limit.sh" disable >/dev/null 2>&1 || true
fi

"$SCRIPT_DIR/capture_broker.sh"
