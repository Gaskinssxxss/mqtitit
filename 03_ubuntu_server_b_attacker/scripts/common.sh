#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

load_config() {
  local prior_OUTPUT_DIR="${OUTPUT_DIR:-}"
  local prior_RUN_ID="${RUN_ID:-}"
  local prior_SCENARIO="${SCENARIO:-}"
  local prior_EXPERIMENT_DURATION="${EXPERIMENT_DURATION:-}"
  local prior_DEPLOYMENT_MODE="${DEPLOYMENT_MODE:-}"
  local prior_BROKER_HOST="${BROKER_HOST:-}"
  local prior_MQTT_PORT="${MQTT_PORT:-}"
  local prior_ATTACK_RATE="${ATTACK_RATE:-}"
  local prior_I_UNDERSTAND_AUTHORIZED_TESTBED="${I_UNDERSTAND_AUTHORIZED_TESTBED:-}"
  local prior_I_HAVE_WRITTEN_AUTHORIZATION="${I_HAVE_WRITTEN_AUTHORIZATION:-}"

  if [[ -f "$PROJECT_ROOT/config.env" ]]; then
    # shellcheck disable=SC1091
    source "$PROJECT_ROOT/config.env"
  elif [[ -f "$PROJECT_ROOT/config.env.example" ]]; then
    # shellcheck disable=SC1091
    source "$PROJECT_ROOT/config.env.example"
  fi

  [[ -n "$prior_OUTPUT_DIR" ]] && OUTPUT_DIR="$prior_OUTPUT_DIR"
  [[ -n "$prior_RUN_ID" ]] && RUN_ID="$prior_RUN_ID"
  [[ -n "$prior_SCENARIO" ]] && SCENARIO="$prior_SCENARIO"
  [[ -n "$prior_EXPERIMENT_DURATION" ]] && EXPERIMENT_DURATION="$prior_EXPERIMENT_DURATION"
  [[ -n "$prior_DEPLOYMENT_MODE" ]] && DEPLOYMENT_MODE="$prior_DEPLOYMENT_MODE"
  [[ -n "$prior_BROKER_HOST" ]] && BROKER_HOST="$prior_BROKER_HOST"
  [[ -n "$prior_MQTT_PORT" ]] && MQTT_PORT="$prior_MQTT_PORT"
  [[ -n "$prior_ATTACK_RATE" ]] && ATTACK_RATE="$prior_ATTACK_RATE"
  [[ -n "$prior_I_UNDERSTAND_AUTHORIZED_TESTBED" ]] && I_UNDERSTAND_AUTHORIZED_TESTBED="$prior_I_UNDERSTAND_AUTHORIZED_TESTBED"
  [[ -n "$prior_I_HAVE_WRITTEN_AUTHORIZATION" ]] && I_HAVE_WRITTEN_AUTHORIZATION="$prior_I_HAVE_WRITTEN_AUTHORIZATION"

  : "${OUTPUT_DIR:=experiments}"
  : "${RUN_ID:=run01_normal}"
  : "${SCENARIO:=normal}"
  : "${EXPERIMENT_DURATION:=60}"
  : "${DEPLOYMENT_MODE:=local}"
  : "${BROKER_HOST:=192.168.56.10}"
  : "${MQTT_PORT:=1883}"
  : "${ATTACK_RATE:=1000}"

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

  EXP_DIR="$PROJECT_ROOT/$OUTPUT_DIR/$RUN_ID"
  export PROJECT_ROOT OUTPUT_DIR RUN_ID SCENARIO EXPERIMENT_DURATION
  export DEPLOYMENT_MODE BROKER_HOST MQTT_PORT ATTACK_RATE EXP_DIR
  export I_UNDERSTAND_AUTHORIZED_TESTBED I_HAVE_WRITTEN_AUTHORIZATION
}

require_cmd() {
  local missing=0
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "[ERR] command tidak ditemukan: $cmd" >&2
      missing=1
    fi
  done
  [[ "$missing" -eq 0 ]] || exit 1
}

ensure_exp_dir() {
  mkdir -p "$EXP_DIR"
}
