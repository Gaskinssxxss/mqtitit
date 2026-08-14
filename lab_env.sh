#!/bin/bash
# lab_env.sh (versi MQTT-DoS-Unram)
# Konfigurasi dasar lab untuk analisis DoS pada broker MQTT

# IP broker MQTT di server Universitas Mataram
# Bisa dioverride: export TARGET_IP=1.2.3.4 sebelum menjalankan skrip
: "${TARGET_IP:=192.168.100.50}"

# Port broker MQTT (boleh lebih dari satu, pisah koma: 1883,1884)
: "${MQTT_PORTS:=1883}"

# Tidak fokus HTTP dalam judul baru, jadi dikosongkan
: "${HTTP_PORTS:=}"

# Interface jaringan di PC A (sniffer + client normal)
: "${NET_IFACE:=eth0}"

# Direktori log & pcap
: "${LOG_DIR:=./logs}"
: "${PCAP_DIR:=./pcap}"

mkdir -p "$LOG_DIR" "$PCAP_DIR"
