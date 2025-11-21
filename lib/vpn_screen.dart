import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart'; // Import Google Fonts
import 'package:provider/provider.dart';
import 'vpn_provider.dart';
import 'main.dart'; // Import ThemeProvider

class VpnScreen extends StatefulWidget {
  const VpnScreen({super.key});

  @override
  State<VpnScreen> createState() => _VpnScreenState();
}

class _VpnScreenState extends State<VpnScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _widgetOptions = <Widget>[
    _HomeTab(),
    _LogsTab(),
    _HelpTab(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  String _getTitle(int index) {
    switch (index) {
      case 0:
        return 'YP Tunneling';
      case 1:
        return 'Logs';
      case 2:
        return 'Bantuan';
      default:
        return 'YP Tunneling';
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle(_selectedIndex)),
        actions: [
          IconButton(
            icon: Icon(themeProvider.themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => themeProvider.toggleTheme(),
            tooltip: 'Toggle Theme',
          ),
        ],
      ),
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dvr),
            label: 'Logs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.help_outline),
            label: 'Bantuan',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

class _HelpTab extends StatelessWidget {
  const _HelpTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          _InfoCard(
            icon: Icons.shield_outlined,
            title: 'Koneksi SSH',
            description: 'Inti dari tunnel, menyediakan koneksi terenkripsi yang aman antara perangkat Anda dan server Anda.',
          ),
          _InfoCard(
            icon: Icons.http_outlined,
            title: 'Proxy (Opsional)',
            description: 'Mengarahkan koneksi SSH melalui server HTTP Proxy. Berguna untuk melewati jaringan yang hanya mengizinkan lalu lintas web (misal: di beberapa kantor atau sekolah).',
          ),
          _InfoCard(
            icon: Icons.lan_outlined,
            title: 'Payload (Opsional)',
            description: 'Mengirimkan data tambahan yang terlihat seperti lalu lintas HTTP biasa di awal koneksi untuk menyamarkan jabat tangan (handshake) SSH agar tidak mudah dideteksi.',
          ),
          _InfoCard(
            icon: Icons.public_outlined,
            title: 'SNI (Opsional)',
            description: 'Server Name Indication digunakan untuk menentukan nama host tujuan saat jabat tangan TLS. Ini penting untuk melewati beberapa jenis firewall canggih.',
          ),
          _InfoCard(
            icon: Icons.dns_outlined,
            title: 'DNS Kustom (Opsional)',
            description: 'Menggunakan server DNS pilihan Anda (misalnya 1.1.1.1 dari Cloudflare atau 8.8.8.8 dari Google) untuk resolusi nama domain yang lebih cepat atau lebih aman.',
          ),
          _InfoCard(
            icon: Icons.contact_support_outlined,
            title: 'Kontak & Dukungan',
            description: 'Untuk pertanyaan, laporan bug, atau saran, silakan kirim email ke: snwn.info@gmail.com',
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _InfoCard({required this.icon, required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Text(title, style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 12),
            Text(description, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    final vpnProvider = Provider.of<VpnProvider>(context);

    return SingleChildScrollView(
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
              _buildSniConfig(vpnProvider, context),
              const SizedBox(height: 16),
              _buildDnsConfig(vpnProvider, context),
            ]
          ),
          const SizedBox(height: 32), // Spacer for the footer
          Text(
            'YP Tunnel app by Awang Kinton',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _LogsTab extends StatelessWidget {
  const _LogsTab();

  @override
  Widget build(BuildContext context) {
    final vpnProvider = Provider.of<VpnProvider>(context);
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final consoleColor = isDarkMode ? Colors.black.withOpacity(0.5) : Colors.grey[200];
    final textColor = isDarkMode ? Colors.white70 : Colors.black87;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
               IconButton(
                icon: const Icon(Icons.copy_all_outlined),
                onPressed: () {
                  final logs = Provider.of<VpnProvider>(context, listen: false).logs;
                  if (logs.isNotEmpty) {
                    Clipboard.setData(ClipboardData(text: logs.join('\n')));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Log disalin ke clipboard.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
                tooltip: 'Salin Log',
              ),
              IconButton(
                icon: const Icon(Icons.delete_sweep_outlined),
                onPressed: () {
                  Provider.of<VpnProvider>(context, listen: false).clearLogs();
                },
                tooltip: 'Bersihkan Log',
              ),
            ],
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: consoleColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withOpacity(0.4))
              ),
              child: vpnProvider.logs.isEmpty
                  ? Center(child: Text('Belum ada aktivitas.', style: TextStyle(color: textColor)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12.0),
                      itemCount: vpnProvider.logs.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3.0),
                          child: Text(
                            vpnProvider.logs[index],
                            style: GoogleFonts.sourceCodePro(
                              fontSize: 12,
                              color: textColor,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}


// --- Helper Widgets (shared or for Home tab) ---

Widget _buildExpansionCard({required String title, required IconData icon, required List<Widget> children}) {
  return Card(
    margin: const EdgeInsets.symmetric(vertical: 6.0),
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

Widget _buildSniConfig(VpnProvider vpnProvider, BuildContext context) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text("SNI (Opsional)", style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      TextField(
        controller: vpnProvider.sniController,
        decoration: const InputDecoration(
          labelText: 'Server Name Indication',
          hintText: 'Contoh: bug.com',
        ),
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

class _SshConfigCard extends StatelessWidget {
  const _SshConfigCard();

  @override
  Widget build(BuildContext context) {
    final vpnProvider = Provider.of<VpnProvider>(context, listen: false);
    final theme = Theme.of(context);

    return Card(
       margin: const EdgeInsets.symmetric(vertical: 6.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Konfigurasi Utama SSH', style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.primary)),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('server_field'),
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
