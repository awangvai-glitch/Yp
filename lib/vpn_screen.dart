import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'vpn_provider.dart';
import 'main.dart'; // Import ThemeProvider

class VpnScreen extends StatelessWidget {
  const VpnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vpnProvider = Provider.of<VpnProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('YP Tunneling'),
        actions: [
          IconButton(
            icon: Icon(themeProvider.themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => themeProvider.toggleTheme(),
            tooltip: 'Toggle Theme',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfoDialog(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _buildConnectionStatus(vpnProvider.status, context),
            const SizedBox(height: 20),
            
            _buildConnectButton(vpnProvider, context),
            const SizedBox(height: 20),

            const _SshConfigCard(),
            const SizedBox(height: 12),

            _buildExpansionCard(
              title: 'Konfigurasi Lanjutan',
              icon: Icons.settings_ethernet_outlined,
              children: [
                _buildProxyConfig(vpnProvider, context),
                const SizedBox(height: 16),
                _buildPayloadConfig(vpnProvider, context),
                const SizedBox(height: 16),
                _buildDnsConfig(vpnProvider, context),
              ]
            ),
            const SizedBox(height: 12),

            _buildLogMonitor(context, vpnProvider),
          ],
        ),
      ),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Informasi Koneksi'),
          content: const SingleChildScrollView(
            child: Text(
              'Aplikasi ini membuat tunnel aman menggunakan beberapa lapisan.\n\n'
              '1. **Koneksi SSH:** Inti dari tunnel, menyediakan koneksi terenkripsi ke server Anda.\n\n'
              '2. **Proxy (Opsional):** Mengarahkan koneksi SSH melalui server HTTP Proxy. Berguna untuk melewati jaringan yang hanya mengizinkan lalu lintas web.\n\n'
              '3. **Payload (Opsional):** Mengirimkan data yang terlihat seperti lalu lintas HTTP biasa di awal koneksi untuk menyamarkan jabat tangan (handshake) SSH/TLS.\n\n'
              '4. **DNS Kustom (Opsional):** Menggunakan server DNS pilihan Anda untuk kecepatan atau keamanan tambahan.'
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
  }

  Widget _buildExpansionCard({required String title, required IconData icon, required List<Widget> children}) {
    return Card(
      child: ExpansionTile(
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildLogMonitor(BuildContext context, VpnProvider vpnProvider) {
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.dvr),
        title: const Text('Log Aktivitas', style: TextStyle(fontWeight: FontWeight.bold)),
        trailing: IconButton(
          icon: const Icon(Icons.delete_sweep_outlined),
          onPressed: () {
            // Use the public clearLogs method
            Provider.of<VpnProvider>(context, listen: false).clearLogs();
          },
          tooltip: 'Bersihkan Log',
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              height: 200, // Fixed height for the log view
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withOpacity(0.4))
              ),
              child: vpnProvider.logs.isEmpty
                  ? const Center(child: Text('Belum ada aktivitas.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(8.0),
                      itemCount: vpnProvider.logs.length,
                      itemBuilder: (context, index) {
                        return Text(
                          vpnProvider.logs[index],
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildConnectionStatus(String status, BuildContext context) {
    Color statusColor;
    String statusText;
    IconData icon;

    switch (status) {
      case 'connected':
        statusColor = Colors.green;
        statusText = 'Terhubung';
        icon = Icons.gpp_good;
        break;
      case 'disconnected':
        statusColor = Colors.red;
        statusText = 'Terputus';
        icon = Icons.gpp_bad;
        break;
      case 'connecting':
        statusColor = Colors.orange;
        statusText = 'Menyambungkan...';
        icon = Icons.hourglass_empty;
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'Standby';
        icon = Icons.pause_circle_outline;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusColor, width: 1.5)
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: statusColor, size: 28),
          const SizedBox(width: 12),
          Text(
            statusText.toUpperCase(),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: statusColor, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectButton(VpnProvider vpnProvider, BuildContext context) {
    final isConnecting = vpnProvider.status == 'connecting';
    final isConnected = vpnProvider.status == 'connected';
    final theme = Theme.of(context);

    return ElevatedButton(
      onPressed: isConnecting
          ? null
          : () {
              if (isConnected) {
                vpnProvider.stopVpn();
              } else {
                vpnProvider.startVpn();
              }
            },
      style: ElevatedButton.styleFrom(
        backgroundColor: isConnected ? Colors.red.shade700 : theme.colorScheme.primary,
        minimumSize: const Size(double.infinity, 60),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 5.0
      ),
      child: Text(
        isConnecting ? 'MENYAMBUNGKAN...' : (isConnected ? 'PUTUSKAN' : 'SAMBUNGKAN'),
        style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)
      ),
    );
  }

    // Bagian-bagian konfigurasi yang di-refactor
  Widget _buildProxyConfig(VpnProvider vpnProvider, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Proxy (Opsional)", style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: vpnProvider.proxyHostController,
                decoration: const InputDecoration(labelText: 'Host Proxy'),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 100,
              child: TextField(
                controller: vpnProvider.proxyPortController,
                decoration: const InputDecoration(labelText: 'Port'),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPayloadConfig(VpnProvider vpnProvider, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Payload HTTP (Opsional)", style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: vpnProvider.payloadController,
          decoration: const InputDecoration(
            labelText: 'Payload',
            hintText: 'GET / HTTP/1.1[crlf]Host: domain.com[crlf][crlf]',
          ),
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildDnsConfig(VpnProvider vpnProvider, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("DNS Kustom (Opsional)", style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: vpnProvider.dnsController,
          decoration: const InputDecoration(
            labelText: 'Server DNS',
            hintText: 'Contoh: 1.1.1.1 atau 8.8.8.8',
          ),
          keyboardType: TextInputType.phone,
        ),
      ],
    );
  }
}


// Widget khusus untuk konfigurasi SSH
class _SshConfigCard extends StatelessWidget {
  const _SshConfigCard();

  @override
  Widget build(BuildContext context) {
    final vpnProvider = Provider.of<VpnProvider>(context, listen: false);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Konfigurasi Utama SSH', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: vpnProvider.serverController,
              decoration: const InputDecoration(labelText: 'Host Server SSH', prefixIcon: Icon(Icons.dns)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: vpnProvider.sshPortController,
                    decoration: const InputDecoration(labelText: 'Port SSH'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: vpnProvider.tlsPortController,
                    decoration: const InputDecoration(labelText: 'Port TLS/SSL'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: vpnProvider.usernameController,
              decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.person)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: vpnProvider.passwordController,
              decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock)),
              obscureText: true,
            ),
          ],
        ),
      ),
    );
  }
}

