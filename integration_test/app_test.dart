import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:myapp/vpn_provider.dart';
import 'package:provider/provider.dart';

// Import the MOCKED entry point for the test environment.
import './main_test.dart' as test_app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Full connection flow with mocked native layer', (WidgetTester tester) async {
    // 1. Run the app using our special test entry point with the mocked channel.
    test_app.main();
    await tester.pumpAndSettle();

    // 2. Get provider and context for direct state checking.
    final BuildContext context = tester.element(find.byType(Scaffold));
    final vpnProvider = Provider.of<VpnProvider>(context, listen: false);

    // 3. Verify initial state.
    expect(vpnProvider.status, 'disconnected');
    expect(find.text('SAMBUNGKAN'), findsOneWidget);

    // 4. Fill the form.
    await tester.enterText(find.widgetWithText(TextField, 'Host/IP'), 'testhost.com');
    await tester.enterText(find.widgetWithText(TextField, 'Port'), '22');
    await tester.enterText(find.widgetWithText(TextField, 'Username'), 'testuser');
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'testpass');
    await tester.pump();

    // 5. Tap the connect button.
    await tester.tap(find.text('SAMBUNGKAN'));
    // Allow time for the mock channel's Future.delayed to complete.
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // 6. [CRITICAL TEST] Verify the final state based on the MOCK.
    // The UI should now show 'PUTUSKAN' because the mock sends 'connected'.
    expect(find.text('PUTUSKAN'), findsOneWidget, reason: 'UI should update to show Disconnect button');
    expect(vpnProvider.status, 'connected', reason: 'Provider status should be 'connected' from mock');

    // 7. Navigate to logs and verify the simulated log message.
    await tester.tap(find.byIcon(Icons.dvr));
    await tester.pumpAndSettle();
    expect(find.textContaining('Berhasil terhubung (simulasi tes)', findRichText: true), findsOneWidget);

    print('Test passed!');
  });
}
