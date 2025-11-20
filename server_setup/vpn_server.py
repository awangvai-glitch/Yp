
import asyncio
import os
import fcntl
import struct
import logging

# Konfigurasi logging
logging.basicConfig(level=logging.INFO, format='[%(asctime)s] %(message)s')

# Konstanta untuk membuat TUN interface
TUNSETIFF = 0x400454ca
IFF_TUN = 0x0001
IFF_NO_PI = 0x1000

async def handle_client(reader, writer):
    """
    Fungsi ini dipanggil untuk setiap koneksi klien yang masuk.
    Namun, dalam mode SSH kita, kita hanya akan menggunakan stdin/stdout.
    """
    # Fungsi ini tidak akan digunakan secara langsung dalam mode SSH
    pass

def create_tun_interface():
    """Membuat interface TUN virtual dan mengembalikannya."""
    tun_fd = os.open('/dev/net/tun', os.O_RDWR)
    # IFF_TUN: Buat TUN device (paket IP)
    # IFF_NO_PI: Jangan sertakan informasi protokol, karena kita sudah berurusan dengan paket IP mentah
    ifr = struct.pack('16sH', b'tun0', IFF_TUN | IFF_NO_PI)
    fcntl.ioctl(tun_fd, TUNSETIFF, ifr)
    logging.info("Interface tun0 dibuat.")
    return tun_fd

def configure_tun_interface(ip='10.8.0.1', peer_ip='10.8.0.2', mtu=1500):
    """Mengkonfigurasi alamat IP dan mengaktifkan interface tun0."""
    logging.info(f"Mengkonfigurasi interface tun0: IP={ip}, Peer={peer_ip}")
    # Set IP address untuk tun0
    os.system(f'ip addr add {ip}/24 dev tun0')
    # Bawa interface "up"
    os.system(f'ip link set dev tun0 up')
    # Atur MTU (Maximum Transmission Unit)
    os.system(f'ip link set tun0 mtu {mtu}')
    # Aktifkan IP forwarding
    os.system('sysctl -w net.ipv4.ip_forward=1')
    logging.info("IP forwarding diaktifkan.")
    
    # Aturan NAT untuk mengizinkan lalu lintas dari VPN ke internet
    # Ini adalah kunci untuk membuat lalu lintas bisa keluar!
    # Gantilah 'eth0' dengan interface jaringan utama server Anda jika berbeda (misal: ens3, wlan0)
    main_interface = get_main_network_interface()
    if not main_interface:
        logging.error("Tidak dapat menemukan interface jaringan utama. Atur secara manual.")
        return
        
    logging.info(f"Menggunakan {main_interface} sebagai interface keluar utama.")
    os.system(f'iptables -t nat -A POSTROUTING -o {main_interface} -j MASQUERADE')
    logging.info("Aturan NAT (iptables) ditambahkan.")

def get_main_network_interface():
    """Mencoba mendeteksi interface jaringan utama yang memiliki default route."""
    try:
        with open('/proc/net/route') as f:
            for line in f:
                parts = line.strip().split()
                if parts[1] == '00000000': # Default gateway
                    return parts[0]
    except Exception:
        return 'eth0' # Fallback ke eth0 jika gagal
    return 'eth0'

async def read_from_stdin(tun_writer):
    """Membaca data dari stdin (dari klien SSH) dan menuliskannya ke TUN."""
    loop = asyncio.get_event_loop()
    reader = asyncio.StreamReader()
    protocol = asyncio.StreamReaderProtocol(reader)
    await loop.connect_read_pipe(lambda: protocol, os.fdopen(0, 'rb'))

    logging.info("Mendengarkan data dari klien SSH (stdin)...")
    try:
        while not reader.at_eof():
            # Baca panjang paket (4 byte integer)
            len_bytes = await reader.readexactly(4)
            packet_len = struct.unpack('>I', len_bytes)[0]
            
            if packet_len > 0:
                # Baca paket itu sendiri
                packet_data = await reader.readexactly(packet_len)
                # Tulis paket langsung ke TUN interface
                os.write(tun_writer, packet_data)
                # logging.info(f"[STDIN -> TUN] Menulis {packet_len} bytes ke tun0.")
    except asyncio.IncompleteReadError:
        logging.info("Koneksi SSH ditutup dari klien.")
    except Exception as e:
        logging.error(f"Error saat membaca dari stdin: {e}")

async def read_from_tun(tun_reader, stdout_writer):
    """Membaca data dari TUN (dari internet) dan menuliskannya ke stdout (ke klien SSH)."""
    logging.info("Mendengarkan data dari tun0 (internet)...")
    try:
        while True:
            # Baca paket dari TUN interface
            packet_data = os.read(tun_reader, 2048)
            if packet_data:
                # Kirim panjang paket
                packet_len = len(packet_data)
                stdout_writer.write(struct.pack('>I', packet_len))
                
                # Kirim paket itu sendiri
                stdout_writer.write(packet_data)
                await stdout_writer.drain()
                # logging.info(f"[TUN -> STDOUT] Mengirim {packet_len} bytes ke klien SSH.")
    except Exception as e:
        logging.error(f"Error saat membaca dari TUN: {e}")

async def main():
    """Fungsi utama untuk menjalankan server."""
    logging.info("Memulai server VPN...")

    # Pastikan skrip dijalankan sebagai root
    if os.geteuid() != 0:
        logging.error("Skrip ini harus dijalankan sebagai root.")
        return

    tun_fd = create_tun_interface()
    configure_tun_interface()

    loop = asyncio.get_event_loop()

    # Dapatkan writer untuk stdout
    writer_transport, writer_protocol = await loop.connect_write_pipe(
        asyncio.streams.FlowControlMixin, os.fdopen(1, 'wb')
    )
    stdout_writer = asyncio.StreamWriter(writer_transport, writer_protocol, None, loop)

    # Buat dua tugas yang berjalan bersamaan
    task_stdin = asyncio.create_task(read_from_stdin(tun_fd))
    task_tun = asyncio.create_task(read_from_tun(tun_fd, stdout_writer))
    
    await asyncio.gather(task_stdin, task_tun)

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logging.info("Server dihentikan.")
        # Bersihkan aturan iptables saat keluar
        main_interface = get_main_network_interface()
        os.system(f'iptables -t nat -D POSTROUTING -o {main_interface} -j MASQUERADE')
        logging.info("Aturan NAT (iptables) dihapus.")
