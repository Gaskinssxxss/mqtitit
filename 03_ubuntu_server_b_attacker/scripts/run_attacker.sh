#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"
load_config

if [[ "$SCENARIO" == "normal" ]]; then
  echo "[OK] Skenario normal tidak menjalankan serangan."
  exit 0
fi

"$SCRIPT_DIR/attack_syn_flood.sh"
