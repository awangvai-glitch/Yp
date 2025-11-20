# Panduan Pengaturan Server VPN

Ini adalah panduan untuk menyiapkan server SSH Anda agar berfungsi dengan aplikasi VPN yang telah kita bangun. Anda hanya perlu melakukan ini **satu kali**.

**Prasyarat:**
- Server Linux dengan akses root (misalnya, VPS dari DigitalOcean, Vultr, Linode, dll.).
- Python 3.7+ terinstal di server.

---

### Langkah 1: Salin Skrip ke Server

1.  Salin isi dari file `vpn_server.py` yang ada di direktori ini.

2.  Masuk ke server Anda menggunakan koneksi SSH biasa dari komputer Anda:
    ```bash
    ssh root@ALAMAT_IP_SERVER_ANDA
    ```

3.  Buat file baru di server dan tempel isinya:
    ```bash
    nano vpn_server.py
    ```
    Tempel kode Python yang sudah Anda salin, lalu tekan `Ctrl+X`, lalu `Y`, lalu `Enter` untuk menyimpan.

### Langkah 2: Beri Izin Eksekusi

Buat agar skrip tersebut dapat dieksekusi:
```bash
chmod +x vpn_server.py
```

### Langkah 3: Jalankan Skrip (Cara Uji Coba)

Anda bisa menjalankan skrip secara langsung untuk pengujian. Skrip ini akan berjalan sampai Anda menutup koneksi SSH.

```bash
python3 ./vpn_server.py
```

Jika berjalan dengan benar, Anda akan melihat output seperti:
```
[timestamp] Memulai server VPN...
[timestamp] Interface tun0 dibuat.
[timestamp] Mengkonfigurasi interface tun0: IP=10.8.0.1, Peer=10.8.0.2
[timestamp] IP forwarding diaktifkan.
[timestamp] Aturan NAT (iptables) ditambahkan.
[timestamp] Mendengarkan data dari klien SSH (stdin)...
[timestamp] Mendengarkan data dari tun0 (internet)...
```

Biarkan terminal ini berjalan. Sekarang, coba hubungkan dari aplikasi VPN di ponsel Anda. Jika semuanya benar, Anda seharusnya bisa mengakses internet!

---

### Langkah 4: Menjalankan Skrip di Latar Belakang (Produksi)

Untuk penggunaan nyata, Anda tidak ingin terminal SSH Anda terus terbuka. Anda ingin skrip berjalan di latar belakang sebagai layanan. Cara termudah adalah menggunakan `systemd`.

1.  Buat file layanan `systemd`:
    ```bash
    nano /etc/systemd/system/myvpn.service
    ```

2.  Tempel konfigurasi berikut di dalamnya. **PENTING:** Ganti `/root/vpn_server.py` dengan path absolut ke lokasi Anda menyimpan file tersebut.

    ```ini
    [Unit]
    Description=My Custom VPN Server
    After=network.target

    [Service]
    User=root
    Group=root
    Type=simple
    ExecStart=/usr/bin/python3 /root/vpn_server.py
    Restart=always
    RestartSec=3

    [Install]
    WantedBy=multi-user.target
    ```

3.  Aktifkan dan mulai layanan:
    ```bash
    # Muat ulang daemon systemd
    systemctl daemon-reload

    # Aktifkan layanan agar dimulai saat boot
    systemctl enable myvpn.service

    # Mulai layanan sekarang juga
    systemctl start myvpn.service
    ```

4.  Periksa statusnya untuk memastikan tidak ada error:
    ```bash
    systemctl status myvpn.service
    ```

    Jika statusnya `active (running)`, maka server VPN Anda sekarang berjalan 24/7. Anda bisa memutuskan koneksi SSH dari komputer Anda, dan server akan tetap berjalan, siap menerima koneksi dari aplikasi VPN Anda kapan saja.

### Langkah 5: Modifikasi Konfigurasi SSH (Sangat Penting!)

Secara default, saat Anda terhubung melalui SSH, ia akan membuka shell interaktif (`bash`). Kita perlu memberitahu server SSH untuk **menjalankan skrip kita sebagai gantinya** ketika pengguna tertentu (misalnya, pengguna VPN) masuk.

1.  Buat pengguna baru khusus untuk koneksi VPN (ini lebih aman daripada menggunakan `root`):
    ```bash
    adduser vpnuser
    ```
    (Anda akan diminta mengatur kata sandi untuk `vpnuser`. Inilah kata sandi yang akan Anda gunakan di aplikasi.)

2.  Edit file konfigurasi SSH:
    ```bash
    nano /etc/ssh/sshd_config
    ```

3.  Gulir ke bagian paling bawah file dan tambahkan blok berikut:
    ```
    Match User vpnuser
        ForceCommand /usr/bin/python3 /root/vpn_server.py
    ```
    Blok ini mengatakan: "Jika pengguna bernama `vpnuser` mencoba masuk, jangan berikan dia shell. Alih-alih, jalankan paksa skrip `vpn_server.py`."

4.  Simpan file (`Ctrl+X`, `Y`, `Enter`) dan restart layanan SSH untuk menerapkan perubahan:
    ```bash
    systemctl restart sshd
    ```

**SELESAI!**

Sekarang, di aplikasi Flutter Anda, gunakan:
- **Server:** Alamat IP server Anda
- **Port:** 22 (atau port SSH Anda jika berbeda)
- **Username:** `vpnuser`
- **Password:** Kata sandi yang Anda atur untuk `vpnuser`

Saat Anda menekan "Connect", server akan secara otomatis menjalankan skrip VPN, dan koneksi Anda akan tersambung dan berfungsi penuh.
