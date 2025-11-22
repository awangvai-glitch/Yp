import 'package:dartssh2/dartssh2.dart';
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

  SSHClient? _sshClient;

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
    if (_logs.length > 200) {
      _logs.removeLast();
    }
    notifyListeners();
  }

  void clearLogs() {
    _logs.clear();
    _addLog('Logs cleared.');
    notifyListeners();
  }

  Future<void> startVpn() async {
    if (kIsWeb) {
      _addLog('VPN functionality is not available on web.');
      return;
    }
    if (_status == 'connecting' || _status == 'connected') {
      _addLog('Already connected or connecting. Please disconnect first.');
      return;
    }

    clearLogs();
    _addLog('--- Initiating Connection ---');
    _status = 'connecting';
    notifyListeners();

    _addLog('Server: ${serverController.text}:${sshPortController.text}');
    _addLog('Username: ${usernameController.text}');

    try {
      _addLog('Establishing socket connection...');
      final socket = await SSHSocket.connect(
        serverController.text,
        int.parse(sshPortController.text),
        timeout: const Duration(seconds: 20),
      );
      _addLog('Socket connected.');

      _addLog('Initializing SSH client...');
      _sshClient = SSHClient(
        socket,
        username: usernameController.text,
        onPasswordRequest: () {
          _addLog('Password requested by server.');
          return passwordController.text;
        },
      );
      _addLog('SSH client initialized.');

      await _sshClient!.authenticated;
      _addLog('✅ Authentication successful!');

      try {
        _addLog('Starting native VpnService...');
        await _channel.invokeMethod('startVpn');
        _status = 'connected';
        _addLog('✅ VPN Service Active.');
      } on PlatformException catch (e) {
        _status = 'error';
        _addLog('❌ Native VpnService failed to start: ${e.message}');
        _sshClient?.close();
        _sshClient = null;
      }
    } catch (e) {
      _status = 'error';
      _addLog('❌ SSH Connection Failed: ${e.toString()}');
      _sshClient = null;
    } finally {
      notifyListeners();
    }
  }

  Future<void> stopVpn() async {
    if (kIsWeb) return;
    
    _addLog('--- Disconnecting ---');
    _status = 'disconnecting';
    notifyListeners();

    try {
      if (_sshClient != null) {
        _sshClient!.close(); // FIX: Removed await from non-Future method.
        _sshClient = null;
        _addLog('SSH client disconnected.');
      }

      await _channel.invokeMethod('stopVpn');
      _addLog('Native VPN service stopped.');

      _status = 'disconnected';
      _addLog('✅ Disconnected successfully.');
    } on PlatformException catch (e) {
      _addLog('Error during disconnection: ${e.message}');
      _status = 'error';
    } catch (e) {
      _addLog('Error closing SSH client: ${e.toString()}');
      _status = 'error';
    } finally {
      notifyListeners();
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
    sniController.dispose();
    dnsController.dispose();
    _sshClient?.close();
    super.dispose();
  }
}
