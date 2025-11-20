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
    private val packetProcessor = PacketProcessor()

    companion object {
        const val TAG = "MyVpnService"
        internal var methodChannel: MethodChannel? = null
        private val handler = Handler(Looper.getMainLooper())

        fun setMethodChannel(channel: MethodChannel) {
            methodChannel = channel
        }

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

                val server = intent?.getStringExtra("server")!!
                val sshPort = intent.getStringExtra("sshPort")!!.toInt()
                val tlsPort = intent.getStringExtra("tlsPort")?.toIntOrNull() ?: sshPort
                val username = intent.getStringExtra("username")!!
                val password = intent.getStringExtra("password")!!
                val proxyHost = intent.getStringExtra("proxyHost")
                val proxyPort = intent.getStringExtra("proxyPort")?.toIntOrNull()
                val payload = intent.getStringExtra("payload")
                val customDns = intent.getStringExtra("dns")

                val jsch = JSch()
                
                sshSession = jsch.getSession(username, server, sshPort).apply {
                    setPassword(password)
                    setConfig("StrictHostKeyChecking", "no")
                    
                    if (!proxyHost.isNullOrBlank() && proxyPort != null && proxyPort > 0) {
                        Log.i(TAG, "Setting up connection via proxy: $proxyHost:$proxyPort")
                        // PERBAIKAN: Memanggil metode setSocketFactory secara eksplisit
                        setSocketFactory(PayloadInjectingSocketFactory(payload, server, tlsPort))
                        this.host = proxyHost
                        this.port = proxyPort
                    } else {
                        Log.i(TAG, "Setting up direct connection to $server:$tlsPort")
                        this.host = server
                        this.port = tlsPort
                    }
                }
                
                Log.i(TAG, "Attempting to connect session to ${sshSession?.host}:${sshSession?.port}...")
                sshSession?.connect(30000)

                if (sshSession?.isConnected != true) throw Exception("SSH connection failed")
                Log.i(TAG, "SSH Session connected successfully.")

                val builder = Builder().setSession(this.javaClass.simpleName)
                    .addAddress("10.8.0.1", 24)
                    .addRoute("0.0.0.0", 0)

                if (!customDns.isNullOrBlank()) {
                    try {
                        builder.addDnsServer(customDns)
                        Log.i(TAG, "Using custom DNS: $customDns")
                    } catch (e: IllegalArgumentException) {
                        Log.w(TAG, "Invalid custom DNS '$customDns'. Falling back to 8.8.8.8")
                        builder.addDnsServer("8.8.8.8")
                    }
                } else {
                    builder.addDnsServer("8.8.8.8")
                }

                vpnInterface = builder.establish() ?: throw IllegalStateException("Failed to establish VPN interface")
                Log.i(TAG, "VPN interface established.")

                val channel = sshSession?.openChannel("shell") as ChannelShell
                channel.connect(10000)
                if (!channel.isConnected) throw Exception("SSH Shell Channel failed to connect")
                Log.i(TAG, "SSH Shell Channel connected.")

                val vpnInput = FileInputStream(vpnInterface!!.fileDescriptor)
                val vpnOutput = FileOutputStream(vpnInterface!!.fileDescriptor)
                val sshInput = DataInputStream(channel.inputStream)
                val sshOutput = DataOutputStream(channel.outputStream)

                vpnThreads.add(Thread(VpnOutput(vpnInput, sshOutput, packetProcessor)).apply { start() })
                vpnThreads.add(Thread(VpnInput(sshInput, vpnOutput)).apply { start() })

                updateStatus("connected")
                Log.i(TAG, "VPN is running.")

                while(channel.isConnected) {
                    Thread.sleep(1000)
                }

            } catch (e: Exception) {
                Log.e(TAG, "VPN main thread error", e)
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
        Log.i(TAG, "Shutting down VPN service...")
        updateStatus("disconnected")
        vpnThreads.forEach { it.interrupt() }
        try { sshSession?.disconnect() } catch (e: Exception) {}
        try { vpnInterface?.close() } catch (e: Exception) {}
    }

    override fun onDestroy() {
        super.onDestroy()
        shutdown()
    }
    
    private class VpnOutput(private val vpnInput: FileInputStream, private val sshOutput: DataOutputStream, private val processor: PacketProcessor) : Runnable {
        override fun run() {
            val buffer = ByteArray(32767)
            try {
                while (!Thread.currentThread().isInterrupted) {
                    val readBytes = vpnInput.read(buffer)
                    if (readBytes > 0) {
                        val header = processor.parse(buffer, readBytes)
                        if (header != null) {
                            sshOutput.writeInt(readBytes)
                            sshOutput.write(buffer, 0, readBytes)
                            sshOutput.flush()
                        }
                    }
                }
            } catch (e: Exception) {
                 Log.e(TAG, "VpnOutput error", e)
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
                Log.i(TAG, "SSH connection closed by peer.")
            } catch (e: Exception) {
                 Log.e(TAG, "VpnInput error", e)
            }
        }
    }
}
