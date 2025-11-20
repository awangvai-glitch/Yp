package com.example.myapp

import com.jcraft.jsch.SocketFactory
import java.io.InputStream
import java.io.OutputStream
import java.net.Socket

class PayloadInjectingSocketFactory(
    private val payload: String?,
    private val targetHost: String,
    private val targetPort: Int
) : SocketFactory {

    @Throws(Exception::class)
    override fun createSocket(host: String, port: Int): Socket {
        // Koneksi dibuat ke proxy, bukan ke target akhir secara langsung
        val socket = Socket(host, port)

        if (!payload.isNullOrBlank()) {
            try {
                MyVpnService.sendLog("Mengirim payload...")
                val outputStream = socket.outputStream
                // Mengganti [crlf] dari payload dengan \r\n dan mengirimkannya
                val processedPayload = payload.replace("[crlf]", "\r\n").toByteArray()
                outputStream.write(processedPayload)
                outputStream.flush()
                MyVpnService.sendLog("Payload berhasil dikirim.")

                // Tunggu sebentar untuk menerima balasan dari proxy (opsional, tapi baik untuk stabilitas)
                // Ini bisa disesuaikan atau dibuat lebih cerdas dengan membaca sampai \r\n\r\n
                Thread.sleep(500)

            } catch (e: Exception) {
                MyVpnService.sendLog("Gagal mengirim payload: ${e.message}")
                socket.close()
                throw e
            }
        }

        return socket
    }

    override fun getInputStream(socket: Socket): InputStream {
        return socket.inputStream
    }

    override fun getOutputStream(socket: Socket): OutputStream {
        return socket.outputStream
    }
}