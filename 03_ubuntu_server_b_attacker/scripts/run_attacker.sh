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
      shift 2
      ;;
    --port)
      MQTT_PORT="$2"
      shift 2
      ;;
    --duration)
      EXPERIMENT_DURATION="$2"
      shift 2
      ;;
    --attack-rate)
      ATTACK_RATE="$2"
      shift 2
      ;;
    --mode)
      DEPLOYMENT_MODE="$2"
      shift 2
      ;;
    --yes-local)
      I_UNDERSTAND_AUTHORIZED_TESTBED=yes
      shift
      ;;
    --yes-authorized)
      I_HAVE_WRITTEN_AUTHORIZATION=yes
      shift
      ;;
    -h|--help)
      cat <<EOF
Usage:
  ./scripts/run_attacker.sh [options]

Options:
  --scenario normal|syn_flood|syn_flood_rate_limit
  --run-id RUN_ID
  --broker-host IP
  --port PORT
  --duration SECONDS
  --attack-rate PACKETS_PER_SECOND
  --mode local|campus|public
  --yes-local
  --yes-authorized

Example:
  ./scripts/run_attacker.sh --scenario syn_flood --run-id run02_syn_flood --broker-host 192.168.56.10 --attack-rate 1000 --yes-local
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
    echo "[ERR] DEPLOYMENT_MODE harus local, campus, atau public" >&2
    exit 1
    ;;
esac
case "$SCENARIO" in
  normal|syn_flood|syn_flood_rate_limit) ;;
  *)
    echo "[ERR] SCENARIO harus normal, syn_flood, atau syn_flood_rate_limit" >&2
    exit 1
    ;;
esac
if ! [[ "$EXPERIMENT_DURATION" =~ ^[0-9]+$ ]] || [[ "$EXPERIMENT_DURATION" -le 0 ]]; then
  echo "[ERR] EXPERIMENT_DURATION harus berupa bilangan bulat positif" >&2
  exit 1
fi
if ! [[ "$ATTACK_RATE" =~ ^[0-9]+$ ]] || [[ "$ATTACK_RATE" -le 0 ]]; then
  echo "[ERR] ATTACK_RATE harus berupa bilangan bulat positif" >&2
  exit 1
fi

EXP_DIR="$PROJECT_ROOT/$OUTPUT_DIR/$RUN_ID"
export RUN_ID SCENARIO EXPERIMENT_DURATION DEPLOYMENT_MODE OUTPUT_DIR EXP_DIR
export BROKER_HOST MQTT_PORT ATTACK_RATE I_UNDERSTAND_AUTHORIZED_TESTBED I_HAVE_WRITTEN_AUTHORIZATION

if [[ "$SCENARIO" == "normal" ]]; then
  echo "[OK] Skenario normal tidak menjalankan serangan."
  exit 0
fi

"$SCRIPT_DIR/attack_syn_flood.sh"
