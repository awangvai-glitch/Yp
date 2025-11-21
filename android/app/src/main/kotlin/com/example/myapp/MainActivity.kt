package com.example.myapp

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val TAG = "MainActivity"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Inisialisasi channel di companion object
        Companion.channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        Log.d(TAG, "Flutter Engine configured and MethodChannel initialized.")

        // Handler untuk panggilan dari Flutter
        Companion.channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startVpn" -> {
                    Log.d(TAG, "Received startVpn call, but VPN functionality is disabled.")
                    result.error("UNAVAILABLE", "VPN functionality is currently disabled.", null)
                }
                "stopVpn" -> {
                     Log.d(TAG, "Received stopVpn call, but VPN functionality is disabled.")
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    companion object {
        private const val CHANNEL = "com.example.myapp/vpn"
        private var channel: MethodChannel? = null

        // Fungsi statis untuk mengirim log ke Flutter
        fun sendLog(message: String) {
            // Pastikan dieksekusi di UI thread
            Handler(Looper.getMainLooper()).post {
                 // Log ke konsol Android karena fungsionalitas UI tidak aktif
                 Log.d("MainActivity-Companion", "Log to Flutter: $message")
                // channel?.invokeMethod("log", message)
            }
        }

        // Fungsi statis untuk memperbarui status koneksi di Flutter
        fun updateStatus(status: String) {
            Handler(Looper.getMainLooper()).post {
                 // Log ke konsol Android karena fungsionalitas UI tidak aktif
                 Log.d("MainActivity-Companion", "Status update to Flutter: $status")
                // channel?.invokeMethod("status", status)
            }
        }
    }
}
