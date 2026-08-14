#!/bin/bash
# run_all.sh
# Orkestrasi di PC A:
#  - sniffer_capture.sh (capture trafik MQTT)
#  - mqtt_prober.sh     (trafik normal ke broker MQTT)
#
# Skenario eksperimen:
#  - Normal:   hanya skrip ini + broker berjalan normal.
#  - DoS:      skrip ini + trafik serangan dari mesin lain, tanpa rate limiting.
#  - DoS+RL:   skrip ini + trafik serangan, dengan rate limiting di server.

source ./lab_env.sh

PIDS=()

start_bg() {
  local script="$1"
  shift
  if [[ -x "$script" ]]; then
    echo "[*] Start $script $* ..."
    ./"$script" "$@" &
    PIDS+=($!)
  else
    echo "[WARN] $script tidak ditemukan atau belum executable."
  fi
}

cleanup() {
  echo
  echo "[*] SIGINT diterima, menghentikan semua proses..."
  for pid in "${PIDS[@]}"; do
    if kill -0 "$pid" 2>/dev/null; then
      echo "    - kill PID $pid"
      kill "$pid" 2>/dev/null || true
    fi
  done

  echo "[*] Menunggu semua proses selesai..."
  wait 2>/dev/null

  echo "[*] Mencari file PCAP terbaru di $PCAP_DIR ..."
  latest_pcap=$(ls -1t "$PCAP_DIR"/mqtt_traffic_*.pcapng 2>/dev/null | head -n 1)

  if [[ -n "$latest_pcap" ]]; then
    echo "[*] PCAP terbaru: $latest_pcap"
    if [[ -x "./extract_raw_flow.sh" ]]; then
      echo "[*] Menjalankan extract_raw_flow.sh ..."
      ./extract_raw_flow.sh "$latest_pcap"
    else
      echo "[WARN] extract_raw_flow.sh tidak executable / belum ada."
      echo "       Jalankan manual nanti: ./extract_raw_flow.sh $latest_pcap"
    fi
  else
    echo "[WARN] Tidak menemukan file PCAP di $PCAP_DIR."
  fi

  echo "[*] Selesai. Keluar."
  exit 0
}

trap cleanup SIGINT SIGTERM

echo "==========================================="
echo "   RUN ALL: MQTT Prober + Sniffer (PC A)"
echo "==========================================="
echo "[INFO] Broker IP   : $TARGET_IP"
echo "[INFO] Interface   : $NET_IFACE"
echo "[INFO] Log dir     : $LOG_DIR"
echo "[INFO] PCAP dir    : $PCAP_DIR"
echo "[INFO] MQTT_PORTS  : ${MQTT_PORTS:-<none>}"
echo "==========================================="
echo

# 1) Jalankan sniffer (tshark)
if [[ -x "./sniffer_capture.sh" ]]; then
  echo "[*] Menjalankan sniffer_capture.sh ..."
  ./sniffer_capture.sh &
  PIDS+=($!)
else
  echo "[ERR] sniffer_capture.sh tidak ditemukan / tidak executable."
fi

# 2) Jalankan MQTT probers (satu proses per port)
if [[ -n "$MQTT_PORTS" ]]; then
  IFS=',' read -ra MP_ARR <<< "$MQTT_PORTS"
  for port in "${MP_ARR[@]}"; do
    port_trimmed="$(echo "$port" | xargs)"
    [[ -z "$port_trimmed" ]] && continue
    start_bg "mqtt_prober.sh" "$port_trimmed"
  done
fi

echo
echo "[*] Semua komponen sudah dijalankan."
echo "[*] Tekan CTRL+C untuk menghentikan eksperimen."
echo

wait
