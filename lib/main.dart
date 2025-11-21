import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'vpn_provider.dart';
import 'vpn_screen.dart';

void main() {
  runApp(
    // Gunakan MultiProvider untuk menyediakan semua state management di level teratas
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) => VpnProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

// ThemeProvider tetap sama
class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Warna dasar untuk menghasilkan skema warna Material 3
    const Color primarySeedColor = Colors.deepPurple;

    // Definisikan TextTheme yang konsisten menggunakan Google Fonts
    final TextTheme appTextTheme = TextTheme(
      displayLarge: GoogleFonts.oswald(fontSize: 57, fontWeight: FontWeight.bold),
      titleLarge: GoogleFonts.roboto(fontSize: 22, fontWeight: FontWeight.w500),
      bodyMedium: GoogleFonts.roboto(fontSize: 14),
      bodySmall: GoogleFonts.roboto(fontSize: 12),
      headlineSmall: GoogleFonts.oswald(fontSize: 24, fontWeight: FontWeight.w600),
    );

    // Tema Terang Modern
    final ThemeData lightTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primarySeedColor,
        brightness: Brightness.light,
      ),
      textTheme: appTextTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: primarySeedColor,
        foregroundColor: Colors.white,
        titleTextStyle: GoogleFonts.oswald(fontSize: 22, fontWeight: FontWeight.bold),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      // [FIXED] Menggunakan CardThemeData, bukan CardTheme
      cardTheme: CardThemeData(
        elevation: 2.0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    // Tema Gelap Modern
    final ThemeData darkTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primarySeedColor,
        brightness: Brightness.dark,
      ),
      textTheme: appTextTheme,
      appBarTheme: AppBarTheme(
         titleTextStyle: GoogleFonts.oswald(fontSize: 22, fontWeight: FontWeight.bold),
      ),
       inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      // [FIXED] Menggunakan CardThemeData, bukan CardTheme
      cardTheme: CardThemeData(
        elevation: 2.0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'YP Tunnel',
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeProvider.themeMode,
           // Provider untuk VpnScreen sekarang berada di atas MaterialApp
          home: const VpnScreen(),
        );
      },
    );
  }
}
