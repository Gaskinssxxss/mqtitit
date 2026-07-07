PAKET 1 - WINDOWS CLIENT DAN ANALISIS
======================================

Fungsi:
1. Menjalankan simulasi perangkat IoT yang mengirim data suhu melalui MQTT.
2. Mengukur pesan berhasil, pesan gagal, dan waktu pengiriman pesan.
3. Menggabungkan hasil client dengan hasil capture dari Ubuntu Server A.
4. Menghasilkan KPI setiap pengujian dan perbandingan semua skenario.

File yang dijalankan:
- doctor.ps1       : memeriksa Python, dependency, dan koneksi broker.
- run_client.ps1   : menjalankan client MQTT. Bisa memakai parameter -Scenario,
                     -RunId, -BrokerHost, dan -Duration.
- run_experiment.ps1 : menjalankan Server A, Windows client, dan Server B dari
                       satu terminal PowerShell menggunakan SSH.
- analyze_run.ps1  : menganalisis satu RUN_ID.
- analyze_all.ps1  : membandingkan seluruh hasil pengujian.

Persiapan pertama:
1. Salin config.env.example menjadi config.env.
2. Install Python 3 pada Windows.
3. Buka PowerShell di folder ini.
4. Jalankan: py -3 -m pip install -r requirements.txt
5. Jalankan: powershell -ExecutionPolicy Bypass -File .\doctor.ps1

Aturan penting:
- Untuk cara mudah tanpa edit config berkali-kali, baca:
  ../docs/CARA_RUNNING_MUDAH_TANPA_EDIT_CONFIG.txt
- RUN_ID dan SCENARIO harus sama pada ketiga mesin.
- Setelah pengujian selesai, salin metadata.env dan raw_flow.csv dari
  Ubuntu Server A ke folder experiments\<RUN_ID>\ pada Windows.
- Folder tersebut sudah berisi mqtt_client.csv dari program client.
- Setelah ketiga file terkumpul, jalankan analyze_run.ps1.
