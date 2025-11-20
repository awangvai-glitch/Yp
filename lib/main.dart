import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'vpn_provider.dart';
import 'vpn_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => VpnProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter VPN',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VPN Home'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const VpnScreen()),
            );
          },
          child: const Text('Go to VPN Settings'),
        ),
      ),
    );
  }
}
