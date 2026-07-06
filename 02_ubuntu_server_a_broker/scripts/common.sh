#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

load_config() {
  if [[ -f "$PROJECT_ROOT/config.env" ]]; then
    # shellcheck disable=SC1091
    source "$PROJECT_ROOT/config.env"
  elif [[ -f "$PROJECT_ROOT/config.env.example" ]]; then
    # shellcheck disable=SC1091
    source "$PROJECT_ROOT/config.env.example"
  fi

  : "${PROJECT_NAME:=mqtt-dos-rate-limit}"
  : "${OUTPUT_DIR:=experiments}"
  : "${SCENARIO:=normal}"
  : "${EXPERIMENT_DURATION:=60}"
  : "${CAPTURE_DURATION:=$((EXPERIMENT_DURATION + 15))}"
  : "${DEPLOYMENT_MODE:=local}"
  : "${BROKER_HOST:=192.168.1.10}"
  : "${BROKER_CAPTURE_HOST:=$BROKER_HOST}"
  : "${MQTT_PORT:=1883}"
  : "${MQTT_TOPIC:=unram/iot/suhu}"
  : "${BROKER_IFACE:=eth0}"
  : "${MQTT_CLIENT_ID_PREFIX:=unram-test}"
  : "${MQTT_QOS:=1}"
  : "${MQTT_INTERVAL_MS:=1000}"
  : "${MQTT_TIMEOUT_SEC:=5}"
  : "${ATTACK_RATE:=1000}"
  : "${RL_RATE:=50/second}"
  : "${RL_BURST:=100}"

  if [[ -z "${RUN_ID:-}" ]]; then
    RUN_ID="$(date +%Y%m%d_%H%M%S)_${SCENARIO}"
  fi

  EXP_DIR="$PROJECT_ROOT/$OUTPUT_DIR/$RUN_ID"
  case "$DEPLOYMENT_MODE" in
    local|campus|public) ;;
    *)
      echo "[ERR] invalid DEPLOYMENT_MODE: $DEPLOYMENT_MODE" >&2
      echo "      allowed: local, campus, public" >&2
      exit 1
      ;;
  esac

  case "$SCENARIO" in
    normal|syn_flood|syn_flood_rate_limit) ;;
    *)
      echo "[ERR] invalid SCENARIO: $SCENARIO" >&2
      echo "      allowed: normal, syn_flood, syn_flood_rate_limit" >&2
      exit 1
      ;;
  esac

  if ! [[ "$EXPERIMENT_DURATION" =~ ^[0-9]+$ ]] || [[ "$EXPERIMENT_DURATION" -le 0 ]]; then
    echo "[ERR] EXPERIMENT_DURATION must be a positive integer" >&2
    exit 1
  fi
  if ! [[ "$CAPTURE_DURATION" =~ ^[0-9]+$ ]] || [[ "$CAPTURE_DURATION" -le "$EXPERIMENT_DURATION" ]]; then
    echo "[ERR] CAPTURE_DURATION must be an integer greater than EXPERIMENT_DURATION" >&2
    exit 1
  fi

  export PROJECT_ROOT PROJECT_NAME OUTPUT_DIR RUN_ID SCENARIO EXPERIMENT_DURATION CAPTURE_DURATION DEPLOYMENT_MODE
  export BROKER_HOST BROKER_CAPTURE_HOST MQTT_PORT MQTT_TOPIC BROKER_IFACE
  export MQTT_CLIENT_ID_PREFIX MQTT_QOS MQTT_INTERVAL_MS MQTT_TIMEOUT_SEC
  export ATTACK_RATE RL_RATE RL_BURST EXP_DIR
}

require_cmd() {
  local missing=0
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "[ERR] command not found: $cmd" >&2
      missing=1
    fi
  done
  if [[ "$missing" -ne 0 ]]; then
    exit 1
  fi
}

ensure_exp_dir() {
  mkdir -p "$EXP_DIR"
}

write_metadata() {
  ensure_exp_dir
  cat > "$EXP_DIR/metadata.env" <<EOF
PROJECT_NAME=$PROJECT_NAME
RUN_ID=$RUN_ID
SCENARIO=$SCENARIO
EXPERIMENT_DURATION=$EXPERIMENT_DURATION
CAPTURE_DURATION=$CAPTURE_DURATION
DEPLOYMENT_MODE=$DEPLOYMENT_MODE
BROKER_HOST=$BROKER_HOST
BROKER_CAPTURE_HOST=$BROKER_CAPTURE_HOST
MQTT_PORT=$MQTT_PORT
MQTT_TOPIC=$MQTT_TOPIC
BROKER_IFACE=$BROKER_IFACE
MQTT_QOS=$MQTT_QOS
MQTT_INTERVAL_MS=$MQTT_INTERVAL_MS
MQTT_TIMEOUT_SEC=$MQTT_TIMEOUT_SEC
ATTACK_RATE=$ATTACK_RATE
RL_RATE=$RL_RATE
RL_BURST=$RL_BURST
START_EPOCH=$(date +%s)
EOF
}
