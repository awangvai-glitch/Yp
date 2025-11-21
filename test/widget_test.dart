import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:myapp/vpn_provider.dart';
import 'package:myapp/vpn_screen.dart';
import 'package:myapp/main.dart'; // For ThemeProvider

void main() {
  // Helper ini membangun UI yang diperlukan untuk tes, termasuk semua Provider.
  Future<void> pumpVpnScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          // Kita membiarkan VpnProvider dibuat secara normal.
          // Tes akan mengejek MethodChannel yang digunakannya di bawah tenda.
          ChangeNotifierProvider(create: (_) => VpnProvider()),
        ],
        child: const MaterialApp(
          home: VpnScreen(),
        ),
      ),
    );
  }

  group('VpnScreen Tests', () {
    // Variabel ini akan menangkap argumen yang dikirim ke method channel
    Map<String, String>? capturedArgs;

    // Tentukan nama channel yang digunakan di VpnProvider
    const vpnChannel = MethodChannel('com.example.myapp/vpn');

    // Siapkan mock handler SEBELUM setiap tes berjalan
    setUp(() {
      // Reset variabel untuk setiap tes
      capturedArgs = null;
      
      // Ini adalah inti dari perbaikan: mengejek panggilan method channel
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(vpnChannel, (MethodCall methodCall) async {
        print('Mock Channel: Menerima panggilan: ${methodCall.method}');
        
        if (methodCall.method == 'startVpn') {
          capturedArgs = Map<String, String>.from(methodCall.arguments);
          return null; // startVpn mengembalikan Future<void>
        }
        
        if (methodCall.method == 'stopVpn') {
          return null; // stopVpn juga mengembalikan Future<void>
        }

        return null;
      });
    });

    // Bersihkan mock handler SETELAH setiap tes
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(vpnChannel, null);
    });

    testWidgets('UI menampilkan tombol sambungkan dan judul yang benar', (tester) async {
      await pumpVpnScreen(tester);
      
      expect(find.text('YP Tunneling'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'SAMBUNGKAN'), findsOneWidget);
    });

    testWidgets('Mengetuk tombol sambungkan memanggil startVpn di method channel', (tester) async {
      await pumpVpnScreen(tester);
      const testHost = 'test.com';

      // Aksi
      await tester.enterText(find.byKey(const ValueKey('server_field')), testHost);
      await tester.tap(find.widgetWithText(ElevatedButton, 'SAMBUNGKAN'));
      await tester.pump();

      // Aserasi: Verifikasi bahwa method channel dipanggil dengan argumen yang benar
      expect(capturedArgs, isNotNull);
      expect(capturedArgs!['server'], testHost);
    });
  });
}
