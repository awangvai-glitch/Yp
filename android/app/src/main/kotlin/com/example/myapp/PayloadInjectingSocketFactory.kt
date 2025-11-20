package com.example.myapp

import android.util.Log
import com.jcraft.jsch.SocketFactory
import java.io.InputStream
import java.io.OutputStream
import java.net.Socket

/**
 * Pabrik soket ini melakukan dua hal:
 * 1. Membuat terowongan (tunnel) melalui proxy HTTP menggunakan perintah CONNECT.
 * 2. Menyuntikkan payload HTTP kustom setelah terowongan dibuat.
 */
class PayloadInjectingSocketFactory(
    private val payload: String?,
    private val sshHost: String,    // Host SSH tujuan (misal: your_server_ip)
    private val sshTlsPort: Int // Port TLS/SSL di server SSH (misal: 443)
) : SocketFactory {

    companion object {
        const val TAG = "PayloadSocketFactory"
    }

    /**
     * Dipanggil oleh JSch.
     * @param host Host proxy yang akan dihubungi.
     * @param port Port proxy yang akan dihubungi.
     */
    override fun createSocket(host: String, port: Int): Socket {
        Log.d(TAG, "Creating socket to proxy: $host:$port")
        val socket = Socket(host, port)

        try {
            val outputStream = socket.getOutputStream()
            val inputStream = socket.getInputStream()

            // 1. Kirim perintah CONNECT ke proxy untuk membuat terowongan ke server SSH kita
            val connectCmd = "CONNECT $sshHost:$sshTlsPort HTTP/1.1\r\nHost: $sshHost:$sshTlsPort\r\n\r\n"
            Log.d(TAG, "Sending CONNECT command:\n$connectCmd")
            outputStream.write(connectCmd.toByteArray())
            outputStream.flush()

            // 2. Baca respons dari proxy. Implementasi sederhana ini hanya mencari "200".
            // Implementasi yang lebih kuat akan mem-parsing header HTTP secara penuh.
            val buffer = ByteArray(1024)
            val bytesRead = inputStream.read(buffer)
            if (bytesRead > 0) {
                val response = String(buffer, 0, bytesRead)
                Log.d(TAG, "Proxy response:\n$response")
                if (!response.contains(" 200 ")) {
                    throw Exception("Proxy CONNECT command failed. Response: $response")
                }
            } else {
                throw Exception("Proxy did not respond to CONNECT command.")
            }

            // 3. Jika ada payload, suntikkan sekarang setelah terowongan berhasil dibuat.
            if (!payload.isNullOrBlank()) {
                Log.d(TAG, "Injecting payload:\n$payload")
                outputStream.write(payload.toByteArray())
                outputStream.flush()
            }

            Log.d(TAG, "Socket to SSH server via proxy and payload is ready.")
            return socket

        } catch (e: Exception) {
            Log.e(TAG, "Error in PayloadInjectingSocketFactory", e)
            socket.close()
            throw e
        }
    }

    override fun getInputStream(socket: Socket): InputStream = socket.inputStream
    override fun getOutputStream(socket: Socket): OutputStream = socket.outputStream
}
