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
        // Variabel statis untuk menyimpan argumen, agar bisa diakses di onActivityResult
        var vpnArguments: HashMap<String, String>? = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler {
            call, result ->
            when (call.method) {
                "startVpn" -> {
                    pendingConnectResult = result
                    val args = call.arguments as? HashMap<String, String>
                    if (args == null) {
                        result.error("INVALID_ARGUMENT", "Arguments cannot be null", null)
                        return@setMethodCallHandler
                    }
                    vpnArguments = args

                    val intent = VpnService.prepare(this)
                    if (intent != null) {
                        startActivityForResult(intent, 1)
                    } else {
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

        // Inisialisasi MyVpnService dengan method channel
        MyVpnService.setMethodChannel(channel)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 1 && resultCode == Activity.RESULT_OK) {
            val intent = Intent(this, MyVpnService::class.java).apply {
                putExtra("server", vpnArguments?.get("server"))
                putExtra("sshPort", vpnArguments?.get("sshPort"))
                putExtra("tlsPort", vpnArguments?.get("tlsPort"))
                putExtra("username", vpnArguments?.get("username"))
                putExtra("password", vpnArguments?.get("password"))
            }
            startService(intent)
            pendingConnectResult?.success(null)
        } else {
            MyVpnService.methodChannel?.invokeMethod("updateStatus", "disconnected")
            pendingConnectResult?.error("PERMISSION_DENIED", "User did not grant VPN permission", null)
        }
        pendingConnectResult = null
        vpnArguments = null
    }
}
