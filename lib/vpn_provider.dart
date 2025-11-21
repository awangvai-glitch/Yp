import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class VpnProvider with ChangeNotifier {
  // The MethodChannel is now final and initialized directly.
  static const _channel = MethodChannel('com.example.myapp/vpn');

  String _status = 'disconnected';
  String get status => _status;

  final List<String> _logs = [];
  List<String> get logs => _logs;

  final serverController = TextEditingController(text: 'your_server_ip');
  final sshPortController = TextEditingController(text: '22');
  final tlsPortController = TextEditingController(text: '443');
  final usernameController = TextEditingController(text: 'root');
  final passwordController = TextEditingController(text: 'your_password');
  final proxyHostController = TextEditingController();
  final proxyPortController = TextEditingController();
  final payloadController = TextEditingController();
  final sniController = TextEditingController();
  final dnsController = TextEditingController(text: '1.1.1.1');

  // The constructor is simple again.
  VpnProvider() {
    // The handler is set directly on the channel.
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    final message = call.arguments as String? ?? '';
    switch (call.method) {
      case 'updateStatus':
        _status = message;
        _addLog('Status changed: $message');
        break;
      case 'addNativeLog':
        _addLog(message);
        break;
      default:
        _addLog('Unknown method call: ${call.method}');
    }
    notifyListeners();
  }

  void _addLog(String message) {
    final timestamp = DateFormat('HH:mm:ss').format(DateTime.now());
    _logs.insert(0, '$timestamp: $message');
    notifyListeners();
  }

  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  Future<void> startVpn() async {
    if (kIsWeb) {
      _addLog('VPN functionality is not available on web.');
      return;
    }
    clearLogs();
    _addLog('Starting VPN connection...');
    _status = 'connecting';
    notifyListeners();

    final processedPayload = payloadController.text.replaceAll('[crlf]', '\r\n');
    final args = <String, String>{
        'server': serverController.text,
        'sshPort': sshPortController.text,
        'tlsPort': tlsPortController.text,
        'username': usernameController.text,
        'password': passwordController.text,
        'proxyHost': proxyHostController.text,
        'proxyPort': proxyPortController.text,
        'payload': processedPayload,
        'sni': sniController.text, 
        'dns': dnsController.text,
      };

    try {
      // Invoke the method directly on the channel.
      await _channel.invokeMethod('startVpn', args);
      _addLog('Connection parameters sent to native code.');
    } on PlatformException catch (e) {
      _status = 'error';
      _addLog('Error: ${e.message}');
      notifyListeners();
    }
  }

  Future<void> stopVpn() async {
    if (kIsWeb) {
      _addLog('VPN functionality is not available on web.');
      return;
    }
    _addLog('Stopping VPN connection...');
    try {
       // Invoke the method directly on the channel.
      await _channel.invokeMethod('stopVpn');
      _addLog('Stop command sent successfully.');
      _status = 'disconnected';
    } on PlatformException catch (e) {
      _addLog('Error stopping VPN: ${e.message}');
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
    sniController.dispose();
    dnsController.dispose();
    super.dispose();
  }
}
