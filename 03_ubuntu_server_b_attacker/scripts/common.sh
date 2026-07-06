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
