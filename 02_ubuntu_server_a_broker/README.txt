PAKET 2 - UBUNTU SERVER A / BROKER
===================================

Fungsi:
1. Menjalankan broker MQTT Mosquitto.
2. Merekam trafik yang menuju port MQTT menggunakan TShark.
3. Mengaktifkan rate limiting hanya pada skenario mitigasi.
4. Mengubah hasil capture menjadi raw_flow.csv.

Program utama:
- scripts/doctor.sh          : memeriksa kebutuhan server.
- scripts/run_broker.sh      : capture dan rate limiting sesuai skenario.
- scripts/finalize_broker.sh : membuat raw_flow.csv setelah capture.
- scripts/rate_limit.sh      : enable, disable, atau status rate limiting.

Persiapan:
1. Salin config.env.example menjadi config.env.
2. Pastikan BROKER_CAPTURE_HOST adalah IP Ubuntu Server A.
3. Pastikan BROKER_IFACE adalah interface jaringan pengujian.
4. Biarkan CAPTURE_DURATION lebih panjang daripada EXPERIMENT_DURATION.
5. Pastikan Mosquitto aktif pada port yang ditentukan.
6. Jalankan: ./scripts/doctor.sh

Setiap pengujian:
1. Samakan RUN_ID dan SCENARIO dengan Windows dan Ubuntu Server B.
2. Jalankan: ./scripts/run_broker.sh
3. Setelah capture selesai: ./scripts/finalize_broker.sh
4. Salin metadata.env dan raw_flow.csv dari experiments/<RUN_ID>/ ke Windows.
