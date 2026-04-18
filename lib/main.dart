import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'; 
// --- 1. ADD THIS IMPORT ---
import 'package:flutter_localizations/flutter_localizations.dart'; 
import 'features/authentication/views/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(const ProviderScope(child: BillDeskApp()));
}

class BillDeskApp extends StatelessWidget {
  const BillDeskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BillDesk',
      debugShowCheckedModeBanner: false,
      
      // --- 2. ADD THESE LOCALE SETTINGS ---
      locale: const Locale('en', 'IN'), // Forces Indian locale (DD/MM/YYYY)
      supportedLocales: const [
        Locale('en', 'IN'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // ------------------------------------

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          elevation: 2,
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
        ),
      ),
      home: const SplashScreen(), 
    );
  }
}