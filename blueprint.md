# Blueprint: Aplikasi Android Advanced Tunneling (Seperti HTTP Injector)

Dokumen ini menguraikan arsitektur dan rencana implementasi untuk aplikasi Flutter yang berfungsi sebagai alat tunneling canggih, menggabungkan koneksi SSH, SNI, proxy HTTP, injeksi payload, dan DNS kustom.

## Ikhtisar & Tujuan

Aplikasi ini berevolusi dari klien VPN sederhana menjadi alat yang sangat fleksibel untuk melewati batasan jaringan yang ketat. Pengguna dapat menumpuk beberapa protokol untuk menyamarkan lalu lintas mereka dan mengarahkannya melalui proxy.

**Alur Koneksi Utama:**
`Aplikasi Android -> (Proxy) -> SSL/TLS Handshake dengan SNI -> (Injeksi Payload) -> Server SSH -> Internet`

## Status Proyek: Sisi Flutter Selesai

- **Antarmuka Pengguna (`lib/vpn_screen.dart`):** Lengkap. Semua kolom input yang diperlukan, termasuk panel "Konfigurasi Lanjutan" yang dapat diperluas, telah diimplementasikan.
- **Manajemen State (`lib/vpn_provider.dart`):** Lengkap. Provider dengan andal mengelola semua input pengguna dan status koneksi.
- **Komunikasi Native (`MethodChannel`):** Lengkap dan Teruji. Provider dengan benar mengirimkan SEMUA parameter konfigurasi ke sisi native.
- **Pengujian (`test/widget_test.dart`):** Lengkap. Tes otomatis memverifikasi bahwa antarmuka pengguna memicu panggilan native yang benar dengan argumen yang benar, memastikan integritas sisi Flutter.

## Langkah Selanjutnya: Implementasi Sisi Android

Pekerjaan yang tersisa adalah secara eksklusif di sisi kode native Android.

### 1. Jembatan Native (`MainActivity.kt`)
- **Status:** Selesai.
- **Detail:** Handler `MethodChannel` dengan benar menerima semua argumen dari Flutter dan meneruskannya ke `MyVpnService` melalui `Intent.putExtra()`. Logging telah ditambahkan untuk memverifikasi penerimaan data.

### 2. Logika Inti Tunneling (`MyVpnService.kt`)
- **Status:** **Tugas Selanjutnya.**
- **Detail:**
  - **Menerima Konfigurasi:** Di dalam metode `onStartCommand`, ekstrak semua parameter (`server`, `sshPort`, `proxyHost`, `payload`, `sni`, dll.) dari `Intent` yang masuk.
  - **Menerapkan Logika Koneksi:** Gunakan parameter yang diekstrak untuk mengonfigurasi dan memulai koneksi tunnel Anda yang sebenarnya. Ini melibatkan penggunaan library seperti JSch dan menerapkan logika kustom untuk menangani proxy, injeksi payload, dan SNI.
  - **Implementasi SNI:** Jika nilai `sni` ada, logika koneksi Anda harus membuat `SSLSocket` dan mengatur parameter SNI **sebelum** terhubung.
  - **Injeksi Payload:** Setelah koneksi TCP/SSL awal dibuat, suntikkan string `payload` ke dalam aliran output socket.
  - **DNS Kustom:** Gunakan nilai `dns` saat membangun antarmuka VpnService menggunakan `VpnService.Builder().addDnsServer(...)`.
