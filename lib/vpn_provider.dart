import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class VpnProvider with ChangeNotifier {
  static const _platform = MethodChannel('com.example.myapp/vpn');

  String _status = 'disconnected';
  String get status => _status;

  final List<String> _logs = [];
  List<String> get logs => _logs;

  // ... (controllers remain the same) ...
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
    final message = call.arguments as String;
    _addLog(message); // Log everything that comes from native

    // Handle status updates separately
    if (call.method == 'updateStatus') {
      _status = message;
    }
    notifyListeners();
  }

  void _addLog(String message) {
    final timestamp = DateFormat('HH:mm:ss').format(DateTime.now());
    _logs.insert(0, '$timestamp: $message');
    notifyListeners();
  }

  void clearLogs() { // <-- Diubah menjadi public
    _logs.clear();
    notifyListeners();
  }

  Future<void> startVpn() async {
    clearLogs(); // Memanggil versi public
    _addLog('Memulai koneksi VPN...');
    _status = 'connecting';
    notifyListeners();

    final processedPayload = payloadController.text.replaceAll('[crlf]', '\r\n');

    try {
      await _platform.invokeMethod('startVpn', <String, String>{
        'server': serverController.text,
        'sshPort': sshPortController.text,
        'tlsPort': tlsPortController.text,
        'username': usernameController.text,
        'password': passwordController.text,
        'proxyHost': proxyHostController.text,
        'proxyPort': proxyPortController.text,
        'payload': processedPayload,
        'dns': dnsController.text,
      });
       _addLog('Parameter koneksi dikirim ke sisi native.');
    } on PlatformException catch (e) {
      _status = 'error';
      _addLog('Error: ${e.message}');
      notifyListeners();
    }
  }

  Future<void> stopVpn() async {
    _addLog('Menghentikan koneksi VPN...');
    try {
      await _platform.invokeMethod('stopVpn');
      _addLog('Perintah stop berhasil dikirim.');
      _status = 'disconnected';
    } on PlatformException catch (e) {
      _addLog('Error saat menghentikan VPN: ${e.message}');
    }
    notifyListeners();
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
