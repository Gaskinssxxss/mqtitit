MQTT DOS LEGACY TESTBED - SNIFFER DAN PROBER
============================================

Project ini dikembalikan ke konsep awal penelitian:

- PC A menjalankan sniffer dan prober.
- Broker MQTT menjadi target pengujian.
- Attacker berada pada mesin lain dan mengirim serangan ke broker saat skenario
  DoS dijalankan.

Konsep ini sesuai dengan folder legacy lama yang berisi:

- sniffer_capture.sh
- mqtt_prober.sh
- run_all.sh
- run_all_cli.sh
- extract_raw_flow.sh
- compile.py
- lab_env.sh


ARSITEKTUR KONSEP LAMA
----------------------

PC A / host monitoring
├── sniffer_capture.sh
│   └── capture trafik MQTT menggunakan tshark
│
├── mqtt_prober.sh
│   └── mengirim trafik MQTT normal menggunakan mosquitto_pub
│
└── run_all.sh
    └── menjalankan sniffer dan prober bersamaan

Broker MQTT
└── target layanan MQTT

Attacker
└── mesin lain yang mengirim trafik DoS/SYN flood ke broker


ARAH TRAFIK
-----------

PC A prober  ----------------------> Broker MQTT
PC A sniffer ----------------------> capture trafik yang terlihat pada interface PC A
Attacker   ------------------------> Broker MQTT


CATATAN VALIDITAS
-----------------

Pada konsep ini, capture dilakukan pada PC A / host monitoring, bukan langsung
pada broker. Artinya, data serangan hanya akan terlihat lengkap jika trafik
attacker ke broker memang melewati interface yang dicapture oleh PC A.

Jika trafik attacker langsung menuju broker tanpa melewati PC A, maka sniffer
di PC A bisa tidak melihat trafik serangan secara lengkap.


FILE UTAMA
----------

lab_env.sh
    Konfigurasi IP broker, port MQTT, interface capture, folder log, dan folder
    pcap.

run_all.sh
    Menjalankan sniffer_capture.sh dan mqtt_prober.sh bersamaan.

run_all_cli.sh
    Versi interaktif untuk memilih IP broker, interface, dan port MQTT.

sniffer_capture.sh
    Menangkap trafik MQTT menggunakan tshark dan menyimpan capture ke folder
    pcap/.

mqtt_prober.sh
    Mengirim pesan MQTT berkala ke broker menggunakan mosquitto_pub dan
    menyimpan log ke folder logs/.

extract_raw_flow.sh
    Mengekstrak file pcap/pcapng menjadi CSV raw flow.

compile.py
    Menghitung metrik trafik dari CSV raw flow.


DEPENDENCY
----------

Pada PC A:

sudo apt update
sudo apt install -y tshark mosquitto-clients python3 python3-pip
python3 -m pip install -r requirements.txt


CARA CEPAT MENJALANKAN
----------------------

1. Edit konfigurasi di lab_env.sh jika diperlukan.

2. Jalankan mode interaktif:

   ./run_all_cli.sh

3. Saat eksperimen selesai, tekan CTRL+C.

4. Script akan mencari file pcap terbaru dan menjalankan extract_raw_flow.sh.

5. Jalankan compile.py pada file raw_flow.csv:

   python3 compile.py pcap/NAMA_FILE_raw_flow.csv -o metrics.csv --ports 1883


FOLDER KONSEP BARU
------------------

Konsep baru yang memakai Windows + Ubuntu Server A sudah dipindahkan ke:

tmp/current_concept_1_ubuntu_windows/

Folder tmp tidak ikut dipush ke GitHub karena memang hanya arsip lokal.
