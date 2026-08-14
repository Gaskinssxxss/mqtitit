#!/bin/bash
# mqtt_prober.sh
# Mengirim publish MQTT periodik ke broker sebagai "trafik normal" klien IoT.
#
# Penggunaan:
#   ./mqtt_prober.sh <port>
#
# Contoh:
#   ./mqtt_prober.sh 1883
#
# Kalau argumen port tidak diisi, skrip akan memakai port pertama dari MQTT_PORTS.

source ./lab_env.sh

# Ambil port dari argumen, atau dari port pertama di MQTT_PORTS
if [[ -n "$1" ]]; then
  PORT="$1"
else
  PORT="$(echo "$MQTT_PORTS" | cut -d',' -f1 | xargs)"
fi

if [[ -z "$PORT" ]]; then
  echo "Usage: $0 <port>"
  echo "Atau set MQTT_PORTS di lab_env.sh"
  exit 1
fi

LOG_FILE="$LOG_DIR/mqtt_${PORT}_probe_log.csv"
TOPIC="unram/iot/probe"

if [ ! -f "$LOG_FILE" ]; then
  echo "timestamp,seq,exit_code,rtt_ms" > "$LOG_FILE"
fi

seq=0
while true; do
  seq=$((seq+1))
  start_ms=$(date +%s%3N)

  mosquitto_pub -h "$TARGET_IP" -p "$PORT" -t "$TOPIC" -m "hello-$seq"
  exit_code=$?    # 0 = sukses, !=0 = gagal

  end_ms=$(date +%s%3N)
  rtt_ms=$((end_ms - start_ms))
  timestamp=$(date +%s)

  echo "$timestamp,$seq,$exit_code,$rtt_ms" | tee -a "$LOG_FILE"

  sleep 1
done
