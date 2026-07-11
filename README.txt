MQTT DOS RATE LIMITING TESTBED
==============================

Project ini menguji dampak SYN flood terhadap broker MQTT dan mengukur
efektivitas rate limiting. Packet capture dilakukan langsung pada server
broker agar trafik yang dianalisis benar-benar merupakan trafik yang diterima
broker.

Status penggunaan saat ini:

- mode utama: local;
- jaringan: VirtualBox Host-Only;
- port MQTT testbed: 1883;
- target pengujian: Ubuntu Server A milik sendiri.

PEMBAGIAN SISTEM
----------------

1. 01_windows_client
   Dijalankan pada Windows. Berfungsi sebagai simulasi perangkat IoT,
   attacker SYN flood berbasis Nping, pencatat keberhasilan dan latency MQTT,
   serta tempat analisis akhir.

2. 02_ubuntu_server_a_broker
   Disalin ke Ubuntu Server A. Berisi Mosquitto test workflow, packet capture
   TShark, ekstraksi trafik, dan rate limiting nftables.

3. 03_ubuntu_server_b_attacker
   Folder lama untuk mode dua Ubuntu Server. Pada arsitektur sederhana terbaru,
   folder ini tidak perlu dipakai.

ARAH TRAFIK
-----------

Windows client MQTT ---------------> Ubuntu Server A : port MQTT
Windows attacker SYN flood --------> Ubuntu Server A : port MQTT
Ubuntu Server A -------------------> merekam seluruh trafik yang diterimanya

KONFIGURASI BERSAMA
-------------------

Untuk satu pengujian, nilai berikut harus sama pada Windows dan Ubuntu Server A:

- RUN_ID
- SCENARIO
- EXPERIMENT_DURATION
- DEPLOYMENT_MODE
- BROKER_HOST
- MQTT_PORT

SCENARIO yang valid:

- normal
- syn_flood
- syn_flood_rate_limit

Contoh tiga pengujian:

run01_normal       + SCENARIO=normal
run01_attack       + SCENARIO=syn_flood
run01_mitigation   + SCENARIO=syn_flood_rate_limit

URUTAN MENJALANKAN SATU PENGUJIAN
---------------------------------

1. Atur config.env pada Windows dan Ubuntu Server A.
2. Jalankan run_broker.sh pada Ubuntu Server A terlebih dahulu.
3. Untuk skenario serangan, jalankan run_attacker.ps1 pada Windows.
4. Jalankan run_client.ps1 pada Windows.
5. Tunggu durasi pengujian selesai.
6. Jalankan finalize_broker.sh pada Ubuntu Server A.
7. Salin metadata.env dan raw_flow.csv dari Server A ke folder RUN_ID Windows.
8. Jalankan analyze_run.ps1 pada Windows.

Setelah tersedia beberapa pengulangan setiap skenario, jalankan
analyze_all.ps1 pada Windows.

OUTPUT YANG DIGABUNGKAN DI WINDOWS
----------------------------------

01_windows_client\experiments\<RUN_ID>\
    mqtt_client.csv       dibuat oleh Windows
    metadata.env          disalin dari Ubuntu Server A
    raw_flow.csv          disalin dari Ubuntu Server A
    metrics.json          dibuat oleh analyze_run.ps1
    metrics.csv           dibuat oleh analyze_run.ps1
    timeseries_metrics.csv

BACA DOKUMENTASI
----------------

Mulai dari:

1. docs/TUTORIAL_PENGGUNAAN_3_TERMINAL_POWERSHELL.txt
2. docs/BLUEPRINT_PROJECT_MQTT_MUDAH_DIPAHAMI.docx

Dokumen pendukung:

- Setiap direktori mesin memiliki README.txt sendiri.
- docs/STRUKTUR_DIREKTORI.txt menjelaskan pembagian file.
- docs/CARA_MENJALANKAN_PROJECT.txt menjelaskan urutan operasi.
- docs/BLUEPRINT_PROJECT_BARU.txt menjelaskan konsep penelitian.
- SECURITY.txt menjelaskan batas penggunaan yang diizinkan.

BATAS KEAMANAN
--------------

SYN flood hanya boleh dijalankan pada testbed milik sendiri atau jaringan yang
memberikan izin tertulis. Mode campus dan public tidak berarti serangan boleh
dijalankan tanpa persetujuan pengelola jaringan dan server.
