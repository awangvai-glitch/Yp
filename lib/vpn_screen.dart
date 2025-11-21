import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/main.dart'; // FIX: Corrected import path
import 'package:myapp/vpn_provider.dart'; // FIX: Corrected import path

class VpnScreen extends StatelessWidget {
  const VpnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('YP Tunnel'),
          actions: [
            IconButton(
              icon: Icon(themeProvider.themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode),
              onPressed: () => themeProvider.toggleTheme(),
              tooltip: 'Toggle Theme',
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.settings_outlined), text: 'Config'),
              Tab(icon: Icon(Icons.receipt_long_outlined), text: 'Logs'),
              Tab(icon: Icon(Icons.help_outline), text: 'Help'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildConfigTab(context),
            _buildLogsTab(context),
            _buildHelpTab(context),
          ],
        ),
        bottomNavigationBar: _buildBottomBar(context),
      ),
    );
  }

  // --- CONFIG TAB --- //
  Widget _buildConfigTab(BuildContext context) {
    final provider = Provider.of<VpnProvider>(context);

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildConfigSection(
          context,
          title: 'Server Connection',
          children: [
            _buildTextField(provider.serverController, 'Server'),
            const SizedBox(height: 12),
            _buildTextField(provider.sshPortController, 'SSH Port', keyboardType: TextInputType.number),
            const SizedBox(height: 12),
             _buildTextField(provider.tlsPortController, 'TLS/SSL Port', keyboardType: TextInputType.number),
          ],
        ),
        _buildConfigSection(
          context,
          title: 'Authentication',
          children: [
            _buildTextField(provider.usernameController, 'Username'),
            const SizedBox(height: 12),
            _buildTextField(provider.passwordController, 'Password', obscureText: true),
          ],
        ),
         _buildConfigSection(
          context,
          title: 'Proxy (Optional)',
          children: [
            _buildTextField(provider.proxyHostController, 'Proxy Host'),
            const SizedBox(height: 12),
            _buildTextField(provider.proxyPortController, 'Proxy Port', keyboardType: TextInputType.number),
          ],
        ),
        _buildConfigSection(
          context,
          title: 'Advanced (Optional)',
          children: [
             _buildTextField(provider.sniController, 'SNI (Server Name Indication)'),
            const SizedBox(height: 12),
            _buildTextField(provider.dnsController, 'Custom DNS'),
             const SizedBox(height: 12),
            _buildTextField(provider.payloadController, 'Payload', maxLines: 3),
              const SizedBox(height: 8),
              Text(
            'Hint: Use [crlf] for new lines.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
          ),
          ],
        ),
      ],
    );
  }

  Widget _buildConfigSection(BuildContext context, {required String title, required List<Widget> children}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {bool obscureText = false, int? maxLines = 1, TextInputType? keyboardType}) {
    return TextField(
        controller: controller,
        obscureText: obscureText,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
        ),
      );
  }

  // --- LOGS TAB --- //
  Widget _buildLogsTab(BuildContext context) {
    final provider = context.watch<VpnProvider>();
    return Column(
        children: [
          Expanded(
            child: Container(
              color: Theme.of(context).cardTheme.color,
              margin: const EdgeInsets.all(12.0),
              padding: const EdgeInsets.all(12.0),
              child: ListView.builder(
                reverse: true,
                itemCount: provider.logs.length,
                itemBuilder: (context, index) {
                  return Text(
                    provider.logs[index],
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: ElevatedButton(
              onPressed: () => provider.clearLogs(),
              child: const Text('Clear Logs'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48) // Make button wide
              ),
            ),
          ),
        ],
      );
  }

  // --- HELP TAB --- //
  Widget _buildHelpTab(BuildContext context) {
     return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
         _buildConfigSection(
          context,
          title: 'Instructions',
          children: const [
             Text('1. Fill in your SSH account details in the \"Config\" tab.'),
             SizedBox(height: 8),
             Text('2. All fields are required except those marked as (Optional).'),
             SizedBox(height: 8),
             Text('3. Payload: Use [crlf] for new lines (CRLF).'),
             SizedBox(height: 8),
             Text('4. Press the play button to connect.'),
             SizedBox(height: 8),
             Text('5. Check the \"Logs\" tab for connection status and troubleshooting.'),
          ]
        ),
         _buildConfigSection(
          context,
          title: 'Contact & Support',
          children: const [
             Text('Email: snwn.info@gmail.com'),
             SizedBox(height: 8),
             Text('Instagram: @iwansrv'),
          ]
        ),
      ]
    );
  }

  // --- BOTTOM BAR --- //
  Widget _buildBottomBar(BuildContext context) {
    final provider = Provider.of<VpnProvider>(context);
    final bool isConnecting = provider.status == 'connecting';
    final bool isConnected = provider.status == 'connected';

    Color fabColor = isConnected ? Colors.red.shade400 : Theme.of(context).colorScheme.primary;
    IconData fabIcon = isConnected ? Icons.stop : Icons.play_arrow;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
         color: Theme.of(context).scaffoldBackgroundColor,
         border: Border(top: BorderSide(color: Theme.of(context).dividerColor, width: 1.5))
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Status', style: Theme.of(context).textTheme.bodySmall),
                  Text(provider.status.toUpperCase(), style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
              FloatingActionButton(
                onPressed: () {
                  if (isConnected || isConnecting) {
                    provider.stopVpn();
                  } else {
                    provider.startVpn();
                  }
                },
                backgroundColor: fabColor,
                child: isConnecting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Icon(fabIcon, size: 30),
              ),
            ],
          ),
           const SizedBox(height: 12),
           const Divider(),
           const SizedBox(height: 8),
           Row(
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
                Text('POWERED By YP TUNNEL', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                const Text('  •  ', style: TextStyle(fontSize: 10)),
                Text('App create by Awang Kinton', style: Theme.of(context).textTheme.bodySmall),
             ]
           )
        ],
      ),
    );
  }
}
