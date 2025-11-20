package com.example.myapp

import android.content.Intent
import android.net.VpnService
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.util.Log
import com.jcraft.jsch.ChannelShell
import com.jcraft.jsch.JSch
import com.jcraft.jsch.Session
import io.flutter.plugin.common.MethodChannel
import java.io.DataInputStream
import java.io.DataOutputStream
import java.io.FileInputStream
import java.io.FileOutputStream
import java.lang.Exception

class MyVpnService : VpnService() {

    private var vpnInterface: ParcelFileDescriptor? = null
    private var sshSession: Session? = null
    private val vpnThreads = mutableListOf<Thread>()
    // PacketProcessor tidak ada di kode asli, saya asumsikan itu ada di file lain
    // private val packetProcessor = PacketProcessor() 

    companion object {
        const val TAG = "MyVpnService"
        private var methodChannel: MethodChannel? = null
        private val handler = Handler(Looper.getMainLooper())

        fun setMethodChannel(channel: MethodChannel) {
            methodChannel = channel
        }

        // Mengirim log ke Flutter
        fun sendLog(message: String) {
            handler.post {
                methodChannel?.invokeMethod("log", message)
            }
        }
        
        // Memperbarui status koneksi dan juga mengirimkannya sebagai log
        fun updateStatus(status: String) {
             handler.post {
                methodChannel?.invokeMethod("updateStatus", status)
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val mainThread = Thread {
            try {
                updateStatus("connecting")
                sendLog("Memulai layanan VPN...")

                val server = intent?.getStringExtra("server")!!
                val sshPort = intent.getStringExtra("sshPort")!!.toInt()
                val tlsPort = intent.getStringExtra("tlsPort")?.toIntOrNull() ?: sshPort
                val username = intent.getStringExtra("username")!!
                val password = intent.getStringExtra("password")!!
                val proxyHost = intent.getStringExtra("proxyHost")
                val proxyPort = intent.getStringExtra("proxyPort")?.toIntOrNull()
                val payload = intent.getStringExtra("payload")
                val customDns = intent.getStringExtra("dns")

                sendLog("Konfigurasi diterima: Server=$server, Port SSH=$sshPort, Port TLS=$tlsPort")

                val jsch = JSch()
                
                sshSession = jsch.getSession(username, server, sshPort).apply {
                    setPassword(password)
                    setConfig("StrictHostKeyChecking", "no")
                    
                    if (!proxyHost.isNullOrBlank() && proxyPort != null && proxyPort > 0) {
                        sendLog("Menggunakan proxy: $proxyHost:$proxyPort")
                        // Asumsi PayloadInjectingSocketFactory ada dan berfungsi
                        setSocketFactory(PayloadInjectingSocketFactory(payload, server, tlsPort))
                        this.host = proxyHost
                        this.port = proxyPort
                    } else {
                        sendLog("Koneksi langsung ke $server:$tlsPort")
                        this.host = server
                        this.port = tlsPort
                    }
                }
                
                sendLog("Mencoba menyambungkan sesi SSH ke ${sshSession?.host}:${sshSession?.port}...")
                sshSession?.connect(30000) // 30 detik timeout

                if (sshSession?.isConnected != true) throw Exception("Koneksi SSH gagal. Periksa host, port, dan kredensial.")
                sendLog("Sesi SSH berhasil tersambung.")

                val builder = Builder().setSession(this.javaClass.simpleName)
                    .addAddress("10.8.0.1", 24)
                    .addRoute("0.0.0.0", 0)

                if (!customDns.isNullOrBlank()) {
                    try {
                        builder.addDnsServer(customDns)
                        sendLog("Menggunakan DNS kustom: $customDns")
                    } catch (e: IllegalArgumentException) {
                        sendLog("DNS kustom '$customDns' tidak valid. Menggunakan 8.8.8.8 sebagai fallback.")
                        builder.addDnsServer("8.8.8.8")
                    }
                } else {
                    sendLog("Menggunakan DNS default: 8.8.8.8")
                    builder.addDnsServer("8.8.8.8")
                }

                vpnInterface = builder.establish() ?: throw IllegalStateException("Gagal membuat antarmuka VPN.")
                sendLog("Antarmuka VPN berhasil dibuat.")

                val channel = sshSession?.openChannel("shell") as ChannelShell
                channel.connect(10000)
                if (!channel.isConnected) throw Exception("Gagal menyambungkan channel shell SSH.")
                sendLog("Channel shell SSH berhasil tersambung.")

                val vpnInput = FileInputStream(vpnInterface!!.fileDescriptor)
                val vpnOutput = FileOutputStream(vpnInterface!!.fileDescriptor)
                val sshInput = DataInputStream(channel.inputStream)
                val sshOutput = DataOutputStream(channel.outputStream)

                // Di VpnOutput, kita tidak menggunakan PacketProcessor, sesuai kode asli
                vpnThreads.add(Thread(VpnOutput(vpnInput, sshOutput)).apply { start() })
                vpnThreads.add(Thread(VpnInput(sshInput, vpnOutput)).apply { start() })

                updateStatus("connected")
                sendLog("VPN berjalan dengan sukses.")

                while(channel.isConnected) {
                    Thread.sleep(1000)
                }

            } catch (e: Exception) {
                Log.e(TAG, "VPN Error", e)
                val errorMessage = e.message ?: "Terjadi kesalahan tidak diketahui"
                sendLog("ERROR: $errorMessage")
                updateStatus("error")
            } finally {
                shutdown()
            }
        }
        mainThread.start()
        vpnThreads.add(mainThread)

        return START_STICKY
    }

    private fun shutdown() {
        sendLog("Memulai proses shutdown VPN...")
        updateStatus("disconnected")
        vpnThreads.forEach { it.interrupt() }
        try { 
            if (sshSession?.isConnected == true) {
                sshSession?.disconnect()
                sendLog("Sesi SSH diputuskan.")
            }
        } catch (e: Exception) {
            sendLog("Exception saat disconnect SSH: ${e.message}")
        }
        try {
             vpnInterface?.close()
             sendLog("Antarmuka VPN ditutup.")
        } catch (e: Exception) {
            sendLog("Exception saat menutup interface: ${e.message}")
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        shutdown()
    }
    
    // Menghapus PacketProcessor dari constructor
    private class VpnOutput(private val vpnInput: FileInputStream, private val sshOutput: DataOutputStream) : Runnable {
        override fun run() {
            val buffer = ByteArray(32767)
            try {
                while (!Thread.currentThread().isInterrupted) {
                    val readBytes = vpnInput.read(buffer)
                    if (readBytes > 0) {
                        // Logika pengiriman paket tanpa PacketProcessor
                        sshOutput.writeInt(readBytes)
                        sshOutput.write(buffer, 0, readBytes)
                        sshOutput.flush()
                    }
                }
            } catch (e: Exception) {
                 if (!Thread.currentThread().isInterrupted) {
                    Log.e(TAG, "VpnOutput error", e)
                    sendLog("Error pada VpnOutput: ${e.message}")
                 }
            }
        }
    }

    private class VpnInput(private val sshInput: DataInputStream, private val vpnOutput: FileOutputStream) : Runnable {
        override fun run() {
            val buffer = ByteArray(32767)
            try {
                while (!Thread.currentThread().isInterrupted) {
                    val packetLength = sshInput.readInt()
                    if (packetLength > 0 && packetLength <= buffer.size) {
                        sshInput.readFully(buffer, 0, packetLength)
                        vpnOutput.write(buffer, 0, packetLength)
                    } 
                }
            } catch (e: java.io.EOFException) {
                sendLog("Koneksi SSH ditutup oleh server.")
            } catch (e: Exception) {
                 if (!Thread.currentThread().isInterrupted) {
                    Log.e(TAG, "VpnInput error", e)
                    sendLog("Error pada VpnInput: ${e.message}")
                 }
            }
        }
    }
}
