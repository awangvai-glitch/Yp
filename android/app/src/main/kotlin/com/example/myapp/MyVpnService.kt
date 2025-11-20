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
import java.net.InetAddress
import java.nio.ByteBuffer

class MyVpnService : VpnService() {

    private var vpnInterface: ParcelFileDescriptor? = null
    private var sshSession: Session? = null
    private val vpnThreads = mutableListOf<Thread>()
    private val packetProcessor = PacketProcessor()

    companion object {
        const val TAG = "MyVpnService"
        // [FIX] Mengubah dari private ke internal agar bisa diakses oleh MainActivity
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
                val username = intent.getStringExtra("username")!!
                val password = intent.getStringExtra("password")!!

                val jsch = JSch()
                sshSession = jsch.getSession(username, server, sshPort).apply {
                    setPassword(password)
                    setConfig("StrictHostKeyChecking", "no")
                    connect(30000)
                }
                if (sshSession?.isConnected != true) throw Exception("SSH connection failed")
                Log.i(TAG, "SSH Session connected.")

                vpnInterface = Builder().setSession("MySshVpn")
                    .addAddress("10.8.0.1", 24)
                    .addDnsServer("8.8.8.8")
                    .addRoute("0.0.0.0", 0)
                    .establish() ?: throw IllegalStateException("Failed to establish VPN interface")
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
                vpnThreads.add(Thread(VpnInput(sshInput, vpnOutput, packetProcessor)).apply { start() })

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
                            Log.d(TAG, "[VPN -> SSH] Sent ${readBytes} bytes for ${header.destinationAddress.hostAddress}")
                        } else {
                            Log.w(TAG, "[VPN -> SSH] Dropped non-IPv4 packet.")
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "VpnOutput error", e)
            }
        }
    }

    private class VpnInput(private val sshInput: DataInputStream, private val vpnOutput: FileOutputStream, private val processor: PacketProcessor) : Runnable {
        override fun run() {
            val buffer = ByteArray(32767)
            try {
                while (!Thread.currentThread().isInterrupted) {
                    val packetLength = sshInput.readInt()
                    if (packetLength > 0 && packetLength <= buffer.size) {
                        sshInput.readFully(buffer, 0, packetLength)
                        
                        val originalHeader = processor.parse(buffer, packetLength)
                        if (originalHeader != null) {
                            val newSourceAddress = originalHeader.destinationAddress
                            val newDestinationAddress = InetAddress.getByName("10.8.0.1") // Target our VPN client IP

                            originalHeader.sourceAddress = newSourceAddress
                            originalHeader.destinationAddress = newDestinationAddress

                            val headerLength = originalHeader.ihl * 4
                            val payloadSize = packetLength - headerLength
                            val payload = if (payloadSize > 0) {
                                val pl = ByteArray(payloadSize)
                                System.arraycopy(buffer, headerLength, pl, 0, payloadSize)
                                pl
                            } else {
                                null
                            }

                            val newPacket = processor.build(originalHeader, payload)
                            vpnOutput.write(newPacket)
                            Log.d(TAG, "[SSH -> VPN] Wrote ${newPacket.size} bytes to VPN interface.")
                        }
                    }
                }
            } catch (e: java.io.EOFException) {
                Log.i(TAG, "SSH connection closed.")
            } catch (e: Exception) {
                Log.e(TAG, "VpnInput error", e)
            }
        }
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
}
