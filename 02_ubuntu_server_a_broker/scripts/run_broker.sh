#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"
load_config

scenario_from_cli=0
run_id_from_cli=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --scenario)
      SCENARIO="$2"
      scenario_from_cli=1
      shift 2
      ;;
    --run-id)
      RUN_ID="$2"
      run_id_from_cli=1
      shift 2
      ;;
    --broker-host)
      BROKER_HOST="$2"
      BROKER_CAPTURE_HOST="$2"
      shift 2
      ;;
    --capture-host)
      BROKER_CAPTURE_HOST="$2"
      shift 2
      ;;
    --iface)
      BROKER_IFACE="$2"
      shift 2
      ;;
    --duration)
      EXPERIMENT_DURATION="$2"
      shift 2
      ;;
    --capture-duration)
      CAPTURE_DURATION="$2"
      shift 2
      ;;
    --mode)
      DEPLOYMENT_MODE="$2"
      shift 2
      ;;
    --rate)
      RL_RATE="$2"
      shift 2
      ;;
    --burst)
      RL_BURST="$2"
      shift 2
      ;;
    -h|--help)
      cat <<EOF
Usage:
  ./scripts/run_broker.sh [options]

Options:
  --scenario normal|syn_flood|syn_flood_rate_limit
  --run-id RUN_ID
  --broker-host IP
  --capture-host IP
  --iface INTERFACE
  --duration SECONDS
  --capture-duration SECONDS
  --mode local|campus|public
  --rate NFT_RATE
  --burst NFT_BURST

Example:
  ./scripts/run_broker.sh --scenario syn_flood --run-id run02_syn_flood --iface enp0s8
EOF
      exit 0
      ;;
    *)
      echo "[ERR] unknown option: $1" >&2
      exit 1
      ;;
  esac
done

if [[ "$scenario_from_cli" -eq 1 && "$run_id_from_cli" -eq 0 ]]; then
  RUN_ID="$(date +%Y%m%d_%H%M%S)_${SCENARIO}"
fi

case "$DEPLOYMENT_MODE" in
  local|campus|public) ;;
  *)
    echo "[ERR] invalid DEPLOYMENT_MODE: $DEPLOYMENT_MODE" >&2
    exit 1
    ;;
esac
case "$SCENARIO" in
  normal|syn_flood|syn_flood_rate_limit) ;;
  *)
    echo "[ERR] invalid SCENARIO: $SCENARIO" >&2
    exit 1
    ;;
esac
if ! [[ "$EXPERIMENT_DURATION" =~ ^[0-9]+$ ]] || [[ "$EXPERIMENT_DURATION" -le 0 ]]; then
  echo "[ERR] EXPERIMENT_DURATION must be a positive integer" >&2
  exit 1
fi
if ! [[ "$CAPTURE_DURATION" =~ ^[0-9]+$ ]] || [[ "$CAPTURE_DURATION" -le "$EXPERIMENT_DURATION" ]]; then
  echo "[ERR] CAPTURE_DURATION must be greater than EXPERIMENT_DURATION" >&2
  exit 1
fi

EXP_DIR="$PROJECT_ROOT/$OUTPUT_DIR/$RUN_ID"
export RUN_ID SCENARIO EXPERIMENT_DURATION CAPTURE_DURATION DEPLOYMENT_MODE
export BROKER_HOST BROKER_CAPTURE_HOST BROKER_IFACE RL_RATE RL_BURST EXP_DIR

ensure_exp_dir
write_metadata

if [[ "$SCENARIO" == "syn_flood_rate_limit" ]]; then
  echo "[INFO] Memeriksa izin administrator untuk rate limiting."
  sudo -v
  "$SCRIPT_DIR/rate_limit.sh" enable
  "$SCRIPT_DIR/rate_limit.sh" status > "$EXP_DIR/nft_before_capture.txt" 2>&1 || true
  trap '"$SCRIPT_DIR/rate_limit.sh" status > "$EXP_DIR/nft_after_capture.txt" 2>&1 || true; "$SCRIPT_DIR/rate_limit.sh" disable' EXIT
else
  echo "[INFO] Rate limiting tidak diaktifkan untuk skenario $SCENARIO."
fi

"$SCRIPT_DIR/capture_broker.sh"
