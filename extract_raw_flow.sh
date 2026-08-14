#!/bin/bash
# extract_raw_flow.sh
# Ekstrak field penting dari file PCAP trafik MQTT ke CSV (raw_flow).
#
# Penggunaan:
#   ./extract_raw_flow.sh pcap/mqtt_traffic_20251203_174551.pcapng
#
# Hasil:
#   pcap/mqtt_traffic_20251203_174551_raw_flow.csv

source ./lab_env.sh

if [ -z "$1" ]; then
  echo "Usage: $0 <file.pcap|file.pcapng>"
  echo "Contoh: $0 pcap/mqtt_traffic_20251203_174551.pcapng"
  exit 1
fi

PCAP_FILE="$1"

if [ ! -f "$PCAP_FILE" ]; then
  echo "[ERR] File tidak ditemukan: $PCAP_FILE"
  exit 1
fi

# Buat nama output: ganti ekstensi .pcap/.pcapng menjadi _raw_flow.csv
BASE="${PCAP_FILE%.*}"
OUT_CSV="${BASE}_raw_flow.csv"

echo "[*] Input PCAP : $PCAP_FILE"
echo "[*] Output CSV : $OUT_CSV"
echo "[*] Menjalankan tshark ..."

tshark -r "$PCAP_FILE" \
  -T fields \
  -e frame.time_epoch \
  -e frame.len \
  -e ip.src \
  -e ip.dst \
  -e ip.proto \
  -e tcp.srcport \
  -e tcp.dstport \
  -e udp.srcport \
  -e udp.dstport \
  -e tcp.flags \
  -e tcp.flags.syn \
  -e tcp.flags.ack \
  -e tcp.flags.reset \
  -e tcp.flags.fin \
  -e tcp.stream \
  -e mqtt.msgtype \
  -e mqtt.clientid \
  -e mqtt.topic \
  -E header=y -E separator=, \
  > "$OUT_CSV"

if [ $? -ne 0 ]; then
  echo "[ERR] tshark gagal dijalankan."
  exit 1
fi

echo "[+] Selesai. CSV raw flow: $OUT_CSV"
