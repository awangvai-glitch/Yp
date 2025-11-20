import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum VpnStatus {
  disconnected,
  connecting,
  connected,
  error,
}

class VpnProvider with ChangeNotifier {
  static const _platform = MethodChannel('com.example.myapp/vpn');

  VpnStatus _status = VpnStatus.disconnected;
  String _server = '';
  String _sshPort = '22';
  String _tlsPort = '443';
  String _username = '';
  String _password = '';

  VpnStatus get status => _status;
  String get server => _server;
  String get sshPort => _sshPort;
  String get tlsPort => _tlsPort;
  String get username => _username;
  String get password => _password;

  VpnProvider() {
    // Dengar status dari native side (akan diimplementasikan)
    _platform.setMethodCallHandler(_handlePlatformCall);
  }

  Future<void> _handlePlatformCall(MethodCall call) async {
    switch (call.method) {
      case 'updateStatus':
        final statusName = call.arguments as String;
        final newStatus = VpnStatus.values.firstWhere(
          (e) => e.name == statusName,
          orElse: () => VpnStatus.error,
        );
        setStatus(newStatus);
        break;
      default:
        break;
    }
  }

  void setServer(String value) {
    _server = value;
    notifyListeners();
  }

  void setSshPort(String value) {
    _sshPort = value;
    notifyListeners();
  }

  void setTlsPort(String value) {
    _tlsPort = value;
    notifyListeners();
  }

  void setUsername(String value) {
    _username = value;
    notifyListeners();
  }

  void setPassword(String value) {
    _password = value;
    notifyListeners();
  }

  void setStatus(VpnStatus newStatus) {
    _status = newStatus;
    notifyListeners();
  }

  Future<void> connect() async {
    setStatus(VpnStatus.connecting);
    try {
      await _platform.invokeMethod('startVpn', {
        'server': _server,
        'sshPort': _sshPort,
        'tlsPort': _tlsPort,
        'username': _username,
        'password': _password,
      });
      // Status akan diupdate oleh native side melalui _handlePlatformCall
    } on PlatformException catch (e) {
      print("Failed to start VPN: '${e.message}'.");
      setStatus(VpnStatus.error);
    }
  }

  Future<void> disconnect() async {
    try {
      await _platform.invokeMethod('stopVpn');
      setStatus(VpnStatus.disconnected);
    } on PlatformException catch (e) {
      print("Failed to stop VPN: '${e.message}'.");
      setStatus(VpnStatus.error);
    }
  }
}
