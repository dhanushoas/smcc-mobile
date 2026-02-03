import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'providers/settings_provider.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
    
    return MaterialApp(
      title: 'SMCC LIVE',
      debugShowCheckedModeBanner: false,
      theme: settings.isDarkMode 
          ? ThemeData.dark().copyWith(
              primaryColor: Colors.blue.shade800,
              scaffoldBackgroundColor: Color(0xFF121212),
              appBarTheme: AppBarTheme(backgroundColor: Color(0xFF1E1E1E)),
              cardTheme: CardTheme(color: Color(0xFF242424), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
              dialogTheme: DialogTheme(
                backgroundColor: Color(0xFF1E1E1E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                titleTextStyle: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white),
              ),
            )
          : ThemeData(
              primaryColor: Colors.blue.shade800,
              scaffoldBackgroundColor: Color(0xFFF0F2F5),
              useMaterial3: true,
              cardTheme: CardTheme(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
              dialogTheme: DialogTheme(
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                titleTextStyle: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black),
              ),
            ),
      home: HomeScreen(),
    );
  }
}
