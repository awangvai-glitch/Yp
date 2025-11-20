# Blueprint: Aplikasi Android Advanced Tunneling (Seperti HTTP Injector)

Dokumen ini menguraikan arsitektur dan rencana implementasi untuk aplikasi Flutter yang berfungsi sebagai alat tunneling canggih, menggabungkan koneksi SSH, proxy HTTP, injeksi payload, dan DNS kustom.

## Ikhtisar & Tujuan

Aplikasi ini berevolusi dari klien VPN sederhana menjadi alat yang sangat fleksibel untuk melewati batasan jaringan yang ketat. Pengguna dapat menumpuk beberapa protokol untuk menyamarkan lalu lintas mereka dan mengarahkannya melalui proxy.

**Alur Koneksi Utama:**
`Aplikasi Android -> (HTTP Proxy) -> (Injeksi Payload) -> Server SSH/TLS -> Internet`

## Rencana Implementasi

### 1. Perubahan Antarmuka Pengguna (`lib/vpn_screen.dart`)
- Menambahkan kolom input untuk:
  - **Proxy Host:** Alamat IP/hostname dari HTTP Proxy.
  - **Proxy Port:** Port dari HTTP Proxy (misal: 8080).
  - **Payload:** Kolom teks multi-baris untuk payload HTTP kustom.
  - **DNS Kustom:** Kolom teks untuk server DNS (misal: 1.1.1.1).
- Mengubah tata letak untuk mengakomodasi semua kolom baru secara intuitif.

### 2. State Management & Alur Data (`lib/vpn_provider.dart`)
- Memperbarui state untuk menyimpan semua nilai konfigurasi baru (proxy, payload, dns).
- Memodifikasi fungsi `startVpn` untuk mengumpulkan semua parameter ini ke dalam sebuah map dan mengirimkannya melalui platform channel.

### 3. Jembatan Native (`MainActivity.kt`)
- Mengadaptasi handler `MethodChannel` untuk menerima map argumen yang diperluas.
- Mengekstrak semua parameter (termasuk yang baru) dan meneruskannya ke `MyVpnService` menggunakan `Intent.putExtra()`.

### 4. Logika Inti Tunneling (`MyVpnService.kt`)
- **Menerima Konfigurasi:** Membaca semua data tambahan dari Intent di `onStartCommand`.
- **Implementasi Koneksi Proxy:**
  - Sebelum membuat `Session` JSch, buat objek `ProxyHTTP`.
  - Atur proxy ini pada sesi SSH (`session.setProxy(proxy)`). JSch akan secara internal menangani pengiriman perintah `CONNECT` ke proxy.
- **Implementasi Injeksi Payload:**
  - Setelah koneksi soket melalui proxy berhasil dibuat (`session.connect()`), dapatkan akses ke `Socket` yang mendasarinya.
  - Tulis string `payload` ke `socket.getOutputStream()` **sebelum** memulai proses autentikasi SSH lebih lanjut.
- **Implementasi DNS Kustom:**
  - Saat menggunakan `VpnService.Builder`, panggil `builder.addDnsServer(customDns)` dengan nilai yang diterima dari Intent. Tambahkan penanganan kesalahan untuk alamat DNS yang tidak valid.

### 5. Penyesuaian Sisi Server (`server_setup/vpn_server.py`)
- **Penanganan Payload:**
  - Di awal setiap koneksi klien yang baru, tambahkan loop untuk membaca data dari soket klien.
  - Terus baca dan buang data sampai urutan byte `b'\r\n\r\n'` terdeteksi.
  - Setelah itu, lanjutkan dengan alur kerja penerusan data SSH yang sudah ada.

### 6. Alur Kerja Koneksi (Diperbarui)
1.  Pengguna mengisi semua detail koneksi (SSH, Proxy, Payload, DNS) di `VpnScreen`.
2.  UI memanggil metode di `VpnProvider`.
3.  `VpnProvider` memperbarui status dan memanggil `startVpn` pada platform channel dengan semua argumen.
4.  `MainActivity.kt` menerima panggilan, meminta izin VPN, lalu memulai `MyVpnService` dengan semua detail konfigurasi dalam Intent.
5.  `MyVpnService` melakukan urutan koneksi:
    a. Menghubungi HTTP Proxy.
    b. Meminta proxy untuk membuat tunnel ke Server SSH.
    c. Mengirimkan Payload melalui tunnel tersebut.
    d. Memulai koneksi dan autentikasi SSH.
    e. Membangun antarmuka VPN lokal dengan DNS kustom.
    f. Mulai merutekan lalu lintas.
6.  Status koneksi dikirim kembali ke Flutter untuk memperbarui UI.
