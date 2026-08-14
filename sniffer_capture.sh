#!/bin/bash
# sniffer_capture.sh
# Capture trafik TCP ke/dari broker MQTT ke file PCAP

source ./lab_env.sh

TS=$(date +%Y%m%d_%H%M%S)
PCAP_FILE="$PCAP_DIR/mqtt_traffic_$TS.pcapng"

FILTER_PARTS=()

# Tambah semua port MQTT
if [[ -n "$MQTT_PORTS" ]]; then
  IFS=',' read -ra MP_ARR <<< "$MQTT_PORTS"
  for p in "${MP_ARR[@]}"; do
    p_trimmed="$(echo "$p" | xargs)"
    [[ -z "$p_trimmed" ]] && continue
    FILTER_PARTS+=("tcp port $p_trimmed")
  done
fi

if [[ ${#FILTER_PARTS[@]} -eq 0 ]]; then
  echo "[ERR] Tidak ada port MQTT yang dikonfigurasi. Periksa MQTT_PORTS di lab_env.sh."
  exit 1
fi

FILTER=$(IFS=" or "; echo "${FILTER_PARTS[*]}")

echo "[*] Capture interface : $NET_IFACE"
echo "[*] Simpan ke         : $PCAP_FILE"
echo "[*] Filter            : $FILTER"
echo

sudo tshark -i "$NET_IFACE" \
  -f "$FILTER" \
  -w "$PCAP_FILE"
