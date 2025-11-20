
# Blueprint: Aplikasi Flutter SSH/TLS VPN

Dokumen ini menguraikan rencana untuk membangun aplikasi Flutter yang berfungsi sebagai klien VPN dengan tunneling SSH melalui TLS.

## Ikhtisar & Tujuan

Aplikasi ini akan menyediakan antarmuka sederhana bagi pengguna untuk mengonfigurasi dan memulai koneksi VPN dari perangkat Android mereka. Koneksi ini akan mengamankan lalu lintas dengan meneruskannya melalui tunnel SSH, yang selanjutnya dienkapsulasi dalam koneksi TLS untuk melewati batasan jaringan.

## Rencana Implementasi

### 1. Penyiapan Proyek
- **Menambahkan Dependensi:** `provider` untuk state management dan `dartssh2` untuk menangani koneksi SSH.
- **Konfigurasi `AndroidManifest.xml`:** Menambahkan izin yang diperlukan untuk layanan VPN (`BIND_VPN_SERVICE`) dan mendeklarasikan VpnService itu sendiri.

### 2. Lapisan Presentasi (UI - Flutter)
- **`vpn_screen.dart`:** Membuat halaman baru yang berisi:
    - `TextField` untuk Server, Port SSH, Port TLS, Username, dan Password.
    - Tombol "Connect/Disconnect" yang dinamis.
    - Indikator status untuk menunjukkan status koneksi (mis., "Disconnected", "Connecting...", "Connected").
- **`main.dart`:** Memperbarui aplikasi utama untuk menyertakan `ChangeNotifierProvider` untuk manajemen state dan menambahkan tombol untuk menavigasi ke `VpnScreen`.

### 3. Lapisan Logika & State Management (Dart)
- **`vpn_provider.dart`:** Membuat kelas `ChangeNotifier` untuk mengelola state koneksi.
    - Mengelola detail koneksi (host, port, dll.).
    - Menyimpan status koneksi saat ini (mis., `enum VpnStatus`).
    - Berkomunikasi dengan layanan native melalui platform channel.

### 4. Lapisan Native (Android/Kotlin)
- **`MainActivity.kt`:**
    - Menyiapkan `MethodChannel` untuk menerima perintah dari Flutter (mis., `startVpn`, `stopVpn`).
    - Menangani permintaan izin VPN dari pengguna.
- **`MyVpnService.kt`:**
    - Membuat kelas `VpnService` dasar.
    - Di sinilah logika inti untuk menangani paket jaringan akan ditempatkan. Untuk awal, ini akan berisi placeholder dan komentar yang menjelaskan cara kerjanya.
    - Logika koneksi SSH over TLS akan dipicu dari sini.

### 5. Alur Kerja Koneksi
1. Pengguna mengisi detail koneksi di `VpnScreen` dan menekan "Connect".
2. UI memanggil metode di `VpnProvider`.
3. `VpnProvider` memperbarui status menjadi "Connecting" dan memanggil metode `startVpn` pada platform channel, dengan meneruskan detail koneksi.
4. `MainActivity.kt` menerima panggilan, meminta izin VPN kepada pengguna jika diperlukan, lalu memulai `MyVpnService`.
5. `MyVpnService` memulai koneksi SSH over TLS, membangun tunnel, dan mulai merutekan lalu lintas jaringan melalui tunnel tersebut.
6. Status koneksi (berhasil atau gagal) dikirim kembali ke Flutter melalui channel untuk memperbarui UI.

