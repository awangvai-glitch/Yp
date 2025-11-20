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
        title: const Text('Advanced Tunneling VPN'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              // Show info dialog
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
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _buildConnectionStatus(vpnProvider.status),
            const SizedBox(height: 20),

            // Server SSH Configuration
            _buildSectionCard(
              title: '1. Konfigurasi Server SSH',
              children: [
                TextField(
                  controller: vpnProvider.serverController,
                  decoration: const InputDecoration(labelText: 'Host Server SSH'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: vpnProvider.sshPortController,
                        decoration: const InputDecoration(labelText: 'Port SSH'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: vpnProvider.tlsPortController,
                        decoration: const InputDecoration(labelText: 'Port TLS/SSL'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: vpnProvider.usernameController,
                  decoration: const InputDecoration(labelText: 'Username SSH'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: vpnProvider.passwordController,
                  decoration: const InputDecoration(labelText: 'Password SSH'),
                  obscureText: true,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Proxy Configuration
            _buildSectionCard(
              title: '2. Konfigurasi Proxy (Opsional)',
              children: [
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
                        decoration: const InputDecoration(labelText: 'Port Proxy'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Payload Configuration
            _buildSectionCard(
              title: '3. Payload HTTP (Opsional)',
              children: [
                TextField(
                  controller: vpnProvider.payloadController,
                  decoration: const InputDecoration(
                    labelText: 'Payload',
                    hintText: 'GET / HTTP/1.1[crlf]Host: domain.com[crlf][crlf]',
                  ),
                   maxLines: 3,
                ),
              ]
            ),
            const SizedBox(height: 20),

            // DNS Configuration
            _buildSectionCard(
              title: '4. DNS Kustom (Opsional)',
              children: [
                TextField(
                  controller: vpnProvider.dnsController,
                  decoration: const InputDecoration(
                    labelText: 'Server DNS',
                    hintText: 'Contoh: 1.1.1.1 atau 8.8.8.8',
                  ),
                   keyboardType: TextInputType.phone,
                ),
              ]
            ),

            const SizedBox(height: 30),
            _buildConnectButton(vpnProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required List<Widget> children}) {
    return Card(
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatus(String status) {
    Color statusColor;
    String statusText;

    switch (status) {
      case 'connected':
        statusColor = Colors.green;
        statusText = 'Terhubung';
        break;
      case 'disconnected':
        statusColor = Colors.red;
        statusText = 'Terputus';
        break;
      case 'connecting':
        statusColor = Colors.orange;
        statusText = 'Menyambungkan...';
        break;
      case 'error':
        statusColor = Colors.red.shade800;
        statusText = 'Gagal Terhubung';
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'Tidak Diketahui';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          statusText,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildConnectButton(VpnProvider vpnProvider) {
    final isConnecting = vpnProvider.status == 'connecting';
    final isConnected = vpnProvider.status == 'connected';

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
        backgroundColor: isConnected ? Colors.red : Colors.blue,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Text(
        isConnecting ? 'MENYAMBUNGKAN...' : (isConnected ? 'PUTUSKAN' : 'SAMBUNGKAN'),
        style: const TextStyle(fontSize: 18, color: Colors.white),
      ),
    );
  }
}
