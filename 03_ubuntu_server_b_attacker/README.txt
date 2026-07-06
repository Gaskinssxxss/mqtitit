PAKET 3 - UBUNTU SERVER B / ATTACKER
=====================================

Fungsi:
1. Membuat trafik SYN flood yang terkontrol menuju Ubuntu Server A.
2. Menyimpan catatan proses serangan.
3. Tidak menjalankan serangan apabila SCENARIO=normal.

Program utama:
- scripts/doctor.sh       : memeriksa hping3 dan koneksi ke broker.
- scripts/run_attacker.sh : menjalankan peran attacker sesuai skenario.

Persiapan:
1. Salin config.env.example menjadi config.env.
2. Isi BROKER_HOST dengan IP Ubuntu Server A.
3. Pastikan pengujian hanya dilakukan pada testbed sendiri atau jaringan berizin.
4. Untuk testbed lokal, ubah I_UNDERSTAND_AUTHORIZED_TESTBED=yes.
5. Jalankan: ./scripts/doctor.sh

Setiap pengujian:
1. Samakan RUN_ID dan SCENARIO dengan Windows dan Ubuntu Server A.
2. Untuk normal: jalankan script; program tidak mengirim serangan.
3. Untuk syn_flood atau syn_flood_rate_limit:
   ./scripts/run_attacker.sh

Mode campus/public membutuhkan izin tertulis dan nilai:
I_HAVE_WRITTEN_AUTHORIZATION=yes
