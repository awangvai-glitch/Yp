import asyncio
import ssl
import logging
import sys

# --- Konfigurasi Logging ---
logging.basicConfig(level=logging.INFO, format='[%(asctime)s] - %(levelname)s - %(message)s')

# --- Logika Utama ---

async def consume_payload(reader):
    """
    Membaca dan membuang data dari stream jika terlihat seperti payload HTTP.
    Jika tidak, kembalikan data yang sudah dibaca karena itu mungkin awal dari handshake SSH.
    """
    logging.info("Memeriksa keberadaan payload HTTP...")
    
    try:
        # Coba intip beberapa byte data awal tanpa menunggu terlalu lama
        initial_data = await asyncio.wait_for(reader.read(40), timeout=3.0)
    except asyncio.TimeoutError:
        logging.info("Tidak ada data yang diterima dalam 3 detik. Mengasumsikan tidak ada payload.")
        return b'' # Tidak ada data, tidak ada sisa
    
    if not initial_data:
        logging.info("Koneksi ditutup sebelum data apa pun diterima.")
        return None

    # Periksa apakah data awal terlihat seperti metode HTTP
    http_methods = [b'GET ', b'POST ', b'CONNECT ', b'PUT ', b'DELETE ', b'HEAD ', b'OPTIONS ']
    is_http = any(initial_data.startswith(method) for method in http_methods)

    if not is_http:
        logging.info("Data awal tidak terlihat seperti HTTP. Mengasumsikan tidak ada payload.")
        return initial_data # Kembalikan data karena ini bagian dari handshake SSH

    # --- Jika ini adalah payload HTTP, buang header-nya ---
    logging.info("Payload HTTP terdeteksi. Membuang header...")
    buffer = initial_data
    end_marker = b'\r\n\r\n'

    try:
        while end_marker not in buffer:
            # Lanjutkan membaca sampai akhir header ditemukan
            chunk = await asyncio.wait_for(reader.read(1024), timeout=5.0)
            if not chunk:
                logging.warning("Koneksi ditutup saat sedang membuang sisa payload.")
                return None
            buffer += chunk
        
        payload_end_pos = buffer.find(end_marker) + len(end_marker)
        logging.info(f"Payload ditemukan ({payload_end_pos} bytes) dan berhasil dibuang.")
        
        spillover = buffer[payload_end_pos:]
        if spillover:
            logging.info(f"Ditemukan {len(spillover)} bytes data sisa setelah payload.")
        return spillover

    except asyncio.TimeoutError:
        logging.error("Timeout saat menunggu akhir dari payload HTTP. Koneksi mungkin korup.")
        return None
    except Exception as e:
        logging.error(f"Error saat membuang payload: {e}")
        return None

async def forward_data(reader, writer, direction):
    """
    Membaca data dari `reader` dan meneruskannya ke `writer` secara terus-menerus.
    """
    try:
        while not reader.at_eof() and not writer.is_closing():
            data = await reader.read(4096) # Baca dalam chunk 4KB
            if not data:
                break
            writer.write(data)
            await writer.drain()
    except (asyncio.CancelledError, ConnectionResetError):
        pass # Ini normal saat koneksi ditutup
    except Exception as e:
        if not writer.is_closing():
            logging.error(f"Error saat meneruskan data ke {direction}: {e}")
    finally:
        if not writer.is_closing():
            writer.close()

async def handle_client(client_reader, client_writer):
    """
    Fungsi untuk menangani setiap koneksi klien yang masuk.
    """
    client_addr = client_writer.get_extra_info('peername')
    logging.info(f"Koneksi diterima dari {client_addr}")

    ssh_reader = None
    ssh_writer = None

    try:
        # 1. Buang payload HTTP jika ada
        spillover_data = await consume_payload(client_reader)
        if spillover_data is None:
            return # Terjadi error atau koneksi ditutup

        # 2. Buka koneksi ke server SSH lokal
        logging.info(f"Membuka koneksi ke server SSH di {SSH_HOST}:{SSH_PORT}...")
        ssh_reader, ssh_writer = await asyncio.open_connection(SSH_HOST, SSH_PORT)
        logging.info("Koneksi ke server SSH lokal berhasil.")
        
        # 3. Tulis data sisa (jika ada) ke server SSH
        if spillover_data:
            ssh_writer.write(spillover_data)
            await ssh_writer.drain()

        # 4. Buat jembatan dua arah untuk meneruskan data
        task_client_to_ssh = asyncio.create_task(forward_data(client_reader, ssh_writer, "SSH Server"))
        task_ssh_to_client = asyncio.create_task(forward_data(ssh_reader, client_writer, "Klien"))

        await asyncio.gather(task_client_to_ssh, task_ssh_to_client)

    except ConnectionRefusedError:
        logging.error(f"FATAL: Koneksi ke server SSH di {SSH_HOST}:{SSH_PORT} ditolak. Pastikan layanan sshd berjalan.")
    except Exception as e:
        logging.error(f"Error tidak terduga di handle_client: {e}")
    finally:
        logging.info(f"Menutup koneksi dari {client_addr}")
        if not client_writer.is_closing():
            client_writer.close()
        if ssh_writer and not ssh_writer.is_closing():
            ssh_writer.close()

async def main():
    if len(sys.argv) != 5:
        print(f"Penggunaan: python3 {sys.argv[0]} <listen_host> <listen_port> <path/ke/sertifikat.pem> <path/ke/kunci_privat.pem>")
        print("Contoh: python3 vpn_server.py 0.0.0.0 443 /etc/ssl/certs/mycert.pem /etc/ssl/private/mykey.pem")
        sys.exit(1)

    listen_host = sys.argv[1]
    listen_port = int(sys.argv[2])
    cert_file = sys.argv[3]
    key_file = sys.argv[4]
    
    global SSH_HOST, SSH_PORT
    SSH_HOST = '127.0.0.1' # Selalu terhubung ke layanan SSH di mesin lokal
    SSH_PORT = 22
    
    try:
        ssl_context = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
        ssl_context.load_cert_chain(certfile=cert_file, keyfile=key_file)
        logging.info(f"Sertifikat SSL/TLS dari '{cert_file}' berhasil dimuat.")
    except Exception as e:
        logging.error(f"FATAL: Gagal memuat sertifikat SSL/TLS. Pastikan path benar dan izin sesuai. Error: {e}")
        sys.exit(1)

    server = await asyncio.start_server(
        handle_client,
        listen_host,
        listen_port,
        ssl=ssl_context
    )

    addrs = ', '.join(str(sock.getsockname()) for sock in server.sockets)
    logging.info(f'Server berjalan di {addrs}, mode TLS/SSL aktif.')
    logging.info(f"Meneruskan koneksi yang masuk ke {SSH_HOST}:{SSH_PORT}")

    async with server:
        await server.serve_forever()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logging.info("Server dihentikan oleh pengguna.")
    except Exception as e:
        logging.error(f"Server berhenti karena error: {e}")
