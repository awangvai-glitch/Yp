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
    private var pendingConnectResult: MethodChannel.Result? = null

    companion object {
        // Gunakan HashMap<String, Any?> untuk mengakomodasi tipe data yang berbeda jika perlu
        var vpnArguments: HashMap<String, String>? = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startVpn" -> {
                    pendingConnectResult = result
                    val args = call.arguments as? HashMap<String, String>
                    if (args == null) {
                        result.error("INVALID_ARGUMENT", "Arguments cannot be null", null)
                        return@setMethodCallHandler
                    }
                    vpnArguments = args // Simpan argumen untuk onActivityResult

                    val intent = VpnService.prepare(this)
                    if (intent != null) {
                        // Minta izin ke pengguna
                        startActivityForResult(intent, 1)
                    } else {
                        // Izin sudah diberikan, langsung lanjutkan
                        onActivityResult(1, Activity.RESULT_OK, null)
                    }
                }
                "stopVpn" -> {
                    val intent = Intent(this, MyVpnService::class.java)
                    stopService(intent)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // Berikan referensi MethodChannel ke VpnService
        MyVpnService.setMethodChannel(channel)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 1) {
            if (resultCode == Activity.RESULT_OK) {
                // Pengguna memberikan izin
                val intent = Intent(this, MyVpnService::class.java).apply {
                    // Ambil semua argumen yang disimpan dan teruskan ke service
                    vpnArguments?.forEach { (key, value) ->
                        putExtra(key, value)
                    }
                }
                startService(intent)
                pendingConnectResult?.success(null)
            } else {
                // Pengguna menolak izin
                MyVpnService.updateStatus("disconnected")
                pendingConnectResult?.error("PERMISSION_DENIED", "User did not grant VPN permission", null)
            }
            // Bersihkan state setelah selesai
            pendingConnectResult = null
            vpnArguments = null
        }
    }
}
