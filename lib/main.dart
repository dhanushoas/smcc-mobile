import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'providers/settings_provider.dart';
import 'services/api_service.dart';

import 'package:firebase_core/firebase_core.dart';
import 'services/notification_service.dart';

import 'package:google_fonts/google_fonts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // await Firebase.initializeApp();
  // await NotificationService.initialize();
  ApiService.warmup(); // Start waking up the server instantly
  await ApiService.init();
  runApp(
    ChangeNotifierProvider(
      create: (_) => SettingsProvider(),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    
    final Color primaryBlue = Color(0xFF2563EB); // From web index.css --primary
    
    return MaterialApp(
      title: 'SMCC LIVE',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryBlue,
          primary: primaryBlue,
          surface: settings.isDarkMode ? Color(0xFF0F172A) : Color(0xFFF8FAFC),
        ),
        scaffoldBackgroundColor: settings.isDarkMode ? Color(0xFF0F172A) : Color(0xFFF8FAFC),
        useMaterial3: true,
        textTheme: GoogleFonts.outfitTextTheme().apply(
          bodyColor: settings.isDarkMode ? Colors.white : Color(0xFF0F172A),
          displayColor: settings.isDarkMode ? Colors.white : Color(0xFF0F172A),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: settings.isDarkMode ? Color(0xFF1E293B) : Colors.white,
          foregroundColor: settings.isDarkMode ? Colors.white : Color(0xFF0F172A),
          elevation: 0,
          centerTitle: false,
          titleTextStyle: GoogleFonts.outfit(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: settings.isDarkMode ? Colors.white : Color(0xFF0F172A),
            letterSpacing: 0.5,
          ),
        ),
        cardTheme: CardTheme(
          color: settings.isDarkMode ? Color(0xFF1E293B) : Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        dialogTheme: DialogTheme(
          backgroundColor: settings.isDarkMode ? Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          titleTextStyle: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 20),
        ),
      ),
      home: HomeScreen(),
    );
  }
}
// Trigger build
