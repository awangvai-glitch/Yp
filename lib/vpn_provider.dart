import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VpnProvider with ChangeNotifier {
  static const _platform = MethodChannel('com.example.myapp/vpn');

  String _status = 'disconnected';
  String get status => _status;

  // Controllers for all text fields
  final serverController = TextEditingController(text: 'your_server_ip');
  final sshPortController = TextEditingController(text: '22');
  final tlsPortController = TextEditingController(text: '443');
  final usernameController = TextEditingController(text: 'root');
  final passwordController = TextEditingController(text: 'your_password');

  final proxyHostController = TextEditingController();
  final proxyPortController = TextEditingController();
  final payloadController = TextEditingController();
  final dnsController = TextEditingController(text: '1.1.1.1');

  VpnProvider() {
    _platform.setMethodCallHandler(_handleMethodCall);
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == 'updateStatus') {
      _status = call.arguments;
      notifyListeners();
    }
  }

  Future<void> startVpn() async {
    _status = 'connecting';
    notifyListeners();

    // Mengganti [crlf] dengan karakter asli \r\n
    final processedPayload = payloadController.text.replaceAll('[crlf]', '\r\n');

    try {
      await _platform.invokeMethod('startVpn', <String, String>{
        'server': serverController.text,
        'sshPort': sshPortController.text,
        'tlsPort': tlsPortController.text,
        'username': usernameController.text,
        'password': passwordController.text,
        // New parameters
        'proxyHost': proxyHostController.text,
        'proxyPort': proxyPortController.text,
        'payload': processedPayload,
        'dns': dnsController.text,
      });
    } on PlatformException catch (e) {
      _status = 'error';
      print("Failed to start VPN: '${e.message}'.");
      notifyListeners();
    }
  }

  Future<void> stopVpn() async {
    try {
      await _platform.invokeMethod('stopVpn');
      _status = 'disconnected';
      notifyListeners();
    } on PlatformException catch (e) {
      print("Failed to stop VPN: '${e.message}'.");
    }
  }

  @override
  void dispose() {
    serverController.dispose();
    sshPortController.dispose();
    tlsPortController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    proxyHostController.dispose();
    proxyPortController.dispose();
    payloadController.dispose();
    dnsController.dispose();
    super.dispose();
  }
}
