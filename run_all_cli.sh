#!/bin/bash
# run_all_cli.sh
# CLI interaktif:
#  - pilih TARGET_IP broker MQTT
#  - pilih interface
#  - pilih port-port MQTT
# Lalu menjalankan run_all.sh dengan konfigurasi tersebut.

source ./lab_env.sh

echo "==========================================="
echo "   Konfigurasi Lab MQTT-DoS (Interactive)"
echo "==========================================="

read -p "IP broker MQTT [${TARGET_IP}]: " ip
TARGET_IP="${ip:-$TARGET_IP}"

read -p "Interface jaringan PC A [${NET_IFACE}]: " iface
NET_IFACE="${iface:-$NET_IFACE}"

echo
read -p "Masukkan port MQTT (boleh lebih dari satu, pisah koma, mis: 1883,1884) [${MQTT_PORTS}]: " mp
MQTT_PORTS="${mp:-$MQTT_PORTS}"

echo
echo "Ringkasan konfigurasi:"
echo "  TARGET_IP   = $TARGET_IP"
echo "  NET_IFACE   = $NET_IFACE"
echo "  MQTT_PORTS  = ${MQTT_PORTS:-<tidak ada>}"
echo

read -p "Jalankan eksperimen dengan konfigurasi ini? [Y/n]: " go
go="${go:-Y}"
if [[ ! "$go" =~ ^[Yy]$ ]]; then
  echo "Dibatalkan."
  exit 0
fi

export TARGET_IP NET_IFACE MQTT_PORTS

./run_all.sh
