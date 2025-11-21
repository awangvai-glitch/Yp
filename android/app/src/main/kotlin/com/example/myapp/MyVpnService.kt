package com.example.myapp

import android.app.PendingIntent
import android.content.Intent
import android.net.VpnService
import android.os.ParcelFileDescriptor
import java.io.FileInputStream
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.nio.channels.FileChannel

class MyVpnService : VpnService() {

    private var vpnInterface: ParcelFileDescriptor? = null
    private var vpnThread: Thread? = null

    companion object {
        var isRunning = false
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "disconnect") {
            stopVpn()
            return START_NOT_STICKY
        }

        startVpn()
        return START_STICKY
    }

    private fun startVpn() {
        if (vpnThread != null && vpnThread!!.isAlive) {
            return
        }

        isRunning = true

        vpnThread = Thread {
            try {
                val builder = Builder()
                builder.setSession("MyVpnService")
                builder.addAddress("10.8.0.2", 24)
                builder.addRoute("0.0.0.0", 0)
                builder.addDnsServer("8.8.8.8")

                vpnInterface = builder.establish() ?: return@Thread

                val `in` = FileInputStream(vpnInterface!!.fileDescriptor)
                val out = FileOutputStream(vpnInterface!!.fileDescriptor)

                // Just a placeholder loop to keep the service running.
                // In a real app, you would read from `in` and write to `out`
                // to handle network traffic.
                while (Thread.currentThread().isInterrupted == false) {
                    Thread.sleep(100)
                }

            } catch (e: Exception) {
                // Handle exceptions
            } finally {
                stopVpn()
            }
        }
        vpnThread?.start()
    }

    private fun stopVpn() {
        vpnThread?.interrupt()
        vpnInterface?.close()
        vpnInterface = null
        isRunning = false
        stopSelf()
    }

    override fun onDestroy() {
        stopVpn()
        super.onDestroy()
    }
}
