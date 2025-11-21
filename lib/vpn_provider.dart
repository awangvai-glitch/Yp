import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class VpnProvider with ChangeNotifier {
  static const _channel = MethodChannel('com.example.myapp/vpn');

  String _status = 'disconnected';
  String get status => _status;

  final List<String> _logs = [];
  List<String> get logs => List.unmodifiable(_logs);

  final serverController = TextEditingController(text: '104.248.31.228');
  final sshPortController = TextEditingController(text: '22');
  final tlsPortController = TextEditingController(text: '443');
  final usernameController = TextEditingController(text: 'root');
  final passwordController = TextEditingController(text: 'm9f53d42');
  final proxyHostController = TextEditingController();
  final proxyPortController = TextEditingController();
  final payloadController = TextEditingController();
  final sniController = TextEditingController();
  final dnsController = TextEditingController(text: '1.1.1.1');

  VpnProvider() {
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
    _addLog('--- Initiating Connection ---');
    _status = 'connecting';
    notifyListeners();

    _addLog('Server: ${serverController.text}');
    _addLog('SSH Port: ${sshPortController.text}');
    _addLog('TLS/SSL Port: ${tlsPortController.text}');
    _addLog('Username: ${usernameController.text}');
    _addLog('Proxy Host: ${proxyHostController.text.isNotEmpty ? proxyHostController.text : "Not set"}');
    _addLog('Proxy Port: ${proxyPortController.text.isNotEmpty ? proxyPortController.text : "Not set"}');
    _addLog('SNI: ${sniController.text.isNotEmpty ? sniController.text : "Not set"}');
    _addLog('Custom DNS: ${dnsController.text.isNotEmpty ? dnsController.text : "Not set"}');

    final processedPayload = payloadController.text.replaceAll('[crlf]', '\r\n');
    _addLog('Processed Payload: ${processedPayload.isNotEmpty ? processedPayload : "Not set"}');
    _addLog('-----------------------------');

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
