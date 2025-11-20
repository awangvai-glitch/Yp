import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'vpn_provider.dart';

class VpnScreen extends StatelessWidget {
  const VpnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vpnProvider = Provider.of<VpnProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SSH/TLS VPN'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              onChanged: vpnProvider.setServer,
              decoration: const InputDecoration(labelText: 'Server'),
            ),
            TextField(
              onChanged: vpnProvider.setSshPort,
              decoration: const InputDecoration(labelText: 'SSH Port', hintText: '22'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              onChanged: vpnProvider.setTlsPort,
              decoration: const InputDecoration(labelText: 'TLS Port', hintText: '443'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              onChanged: vpnProvider.setUsername,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            TextField(
              onChanged: vpnProvider.setPassword,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (vpnProvider.status == VpnStatus.connected) {
                  vpnProvider.disconnect();
                } else {
                  vpnProvider.connect();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: vpnProvider.status == VpnStatus.connected
                    ? Colors.red
                    : Colors.green,
              ),
              child: Text(vpnProvider.status == VpnStatus.connected
                  ? 'Disconnect'
                  : 'Connect'),
            ),
            const SizedBox(height: 20),
            Text('Status: ${vpnProvider.status.name}'),
          ],
        ),
      ),
    );
  }
}
