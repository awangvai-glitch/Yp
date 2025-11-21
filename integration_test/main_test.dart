import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:myapp/main.dart'; // Import original main

/// This is a special entry point for integration tests.
/// It sets up a mock MethodChannel to simulate native VPN behavior,
/// bypassing the need for system-level VPN permissions during tests.
void main() {
  // 1. Intercept the MethodChannel that communicates with native code.
  const MethodChannel channel = MethodChannel('com.example.myapp/vpn');

  // 2. We use `TestDefaultBinaryMessenger` to mock the channel's behavior.
  TestDefaultBinaryMessenger.instance.setMockMethodCallHandler(channel, (MethodCall methodCall) async {
    print('Mock MethodChannel intercepted: ${methodCall.method}');

    // 3. Simulate the native behavior for starting the VPN.
    if (methodCall.method == 'startVpn') {
      // In a real scenario, the native side would try to connect and then send status updates.
      // Here, we simulate a successful connection after a short delay.
      Future.delayed(const Duration(milliseconds: 500), () {
        // [FIXED] Use the correct method for each piece of data.
        channel.invokeMethod('updateStatus', 'connected');
      });
       Future.delayed(const Duration(milliseconds: 600), () {
        // [FIXED] Send logs via the dedicated 'addNativeLog' method.
        channel.invokeMethod('addNativeLog', 'Berhasil terhubung (simulasi tes)');
      });
      return Future.value();
    }

    // 4. Simulate the native behavior for stopping the VPN.
    if (methodCall.method == 'stopVpn') {
      Future.delayed(const Duration(milliseconds: 100), () {
        channel.invokeMethod('updateStatus', 'disconnected');
      });
      return Future.value();
    }

    return null;
  });

  // 5. After setting up the mock, run the actual app.
  runApp(const MyApp());
}
