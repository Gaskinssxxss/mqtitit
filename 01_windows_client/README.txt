PAKET 1 - WINDOWS CLIENT, ATTACKER, DAN ANALISIS
================================================

Fungsi:
1. Menjalankan simulasi perangkat IoT yang mengirim data suhu melalui MQTT.
2. Menjalankan SYN flood dari Windows menggunakan Nping untuk skenario serangan.
3. Mengukur pesan berhasil, pesan gagal, dan waktu pengiriman pesan.
4. Menggabungkan hasil client dengan hasil capture dari Ubuntu Server A.
5. Menghasilkan KPI setiap pengujian dan perbandingan semua skenario.

File yang dijalankan:
- doctor.ps1       : memeriksa Python, dependency, dan koneksi broker.
- run_client.ps1   : menjalankan client MQTT. Bisa memakai parameter -Scenario,
                     -RunId, -BrokerHost, dan -Duration.
- run_attacker.ps1 : menjalankan SYN flood dari Windows menggunakan Nping.
- collect_results.ps1 : mengambil file mentah hasil pengujian dari Ubuntu
                        Server A ke Windows menggunakan SCP.
- analyze_run.ps1  : menganalisis satu RUN_ID.
- analyze_all.ps1  : membandingkan seluruh hasil pengujian.

Persiapan pertama:
1. Salin config.env.example menjadi config.env.
2. Install Python 3 pada Windows.
3. Install Nmap for Windows dan Npcap jika Windows dipakai sebagai attacker.
4. Buka PowerShell sebagai Administrator di folder ini.
5. Jalankan: py -3 -m pip install -r requirements.txt
6. Jalankan: powershell -ExecutionPolicy Bypass -File .\doctor.ps1

Aturan penting:
- Untuk cara mudah tanpa edit config berkali-kali, baca:
  ../docs/CARA_RUNNING_MUDAH_TANPA_EDIT_CONFIG.txt
- RUN_ID dan SCENARIO harus sama pada Windows dan Ubuntu Server A.
- Setelah pengujian selesai, salin metadata.env dan raw_flow.csv dari
  Ubuntu Server A ke folder experiments\<RUN_ID>\ pada Windows.
- Folder tersebut sudah berisi mqtt_client.csv dari program client.
- Untuk skenario serangan, folder tersebut juga berisi attack.log dari Windows.
- Setelah ketiga file terkumpul, jalankan analyze_run.ps1.
