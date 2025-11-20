package com.example.myapp

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.myapp/vpn"
    private lateinit var channel: MethodChannel

    // Gunakan variabel instance untuk menghindari masalah dengan state statis
    private var vpnLaunchArgs: HashMap<String, String>? = null
    private var vpnLaunchResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        // Berikan referensi MethodChannel ke VpnService agar bisa mengirim log/status
        MyVpnService.setMethodChannel(channel)

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startVpn" -> {
                    val args = call.arguments as? HashMap<String, String>
                    if (args == null) {
                        result.error("INVALID_ARGUMENT", "Argumen tidak boleh null", null)
                        return@setMethodCallHandler
                    }

                    // Simpan argumen dan hasil untuk digunakan setelah izin diberikan
                    vpnLaunchArgs = args
                    vpnLaunchResult = result

                    val intent = VpnService.prepare(this)
                    if (intent != null) {
                        // Izin belum diberikan, tampilkan dialog sistem
                        startActivityForResult(intent, 1)
                    } else {
                        // Izin sudah ada, langsung mulai service
                        startVpnService()
                    }
                }
                "stopVpn" -> {
                    val intent = Intent(this, MyVpnService::class.java)
                    stopService(intent)
                    result.success(null) // Memberi tahu Flutter bahwa perintah stop berhasil
                }
                else -> result.notImplemented()
            }
        }
    }

    // Fungsi terpusat untuk memulai layanan VPN
    private fun startVpnService() {
        if (vpnLaunchArgs == null || vpnLaunchResult == null) {
            // Ini bisa terjadi jika aktivitas Android dihancurkan & dibuat ulang oleh OS
            MyVpnService.sendLog("Error: State aplikasi hilang. Coba lagi.")
            vpnLaunchResult?.error("STATE_LOST", "Silakan coba sambungkan lagi.", null)
            MyVpnService.updateStatus("disconnected")
            cleanupVpnLaunchState()
            return
        }

        val intent = Intent(this, MyVpnService::class.java).apply {
            vpnLaunchArgs?.forEach { (key, value) ->
                putExtra(key, value)
            }
        }
        startService(intent)
        vpnLaunchResult?.success(null) // Memberi tahu Flutter bahwa proses start berhasil dimulai
        cleanupVpnLaunchState() // Bersihkan setelah digunakan
    }

    // Fungsi untuk membersihkan state setelah proses launch selesai atau gagal
    private fun cleanupVpnLaunchState() {
        vpnLaunchArgs = null
        vpnLaunchResult = null
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 1) {
            if (resultCode == Activity.RESULT_OK) {
                // Pengguna memberikan izin, sekarang mulai service
                startVpnService()
            } else {
                // Pengguna menolak izin
                MyVpnService.sendLog("Izin VPN ditolak oleh pengguna.")
                vpnLaunchResult?.error("PERMISSION_DENIED", "Izin VPN tidak diberikan.", null)
                MyVpnService.updateStatus("disconnected")
                cleanupVpnLaunchState()
            }
        }
    }
}
