import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'; // <-- Added import for Windows SQLite
import 'features/dashboard/global_dashboard_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // --- ADDED THIS BLOCK FOR WINDOWS SUPPORT ---
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  // ---------------------------------------------

  // ProviderScope is required for Riverpod to work!
  runApp(const ProviderScope(child: BillDeskApp()));
}

class BillDeskApp extends StatelessWidget {
  const BillDeskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BillDesk',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          elevation: 2,
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
        ),
      ),
      // This is the dashboard we just built
      home: const GlobalDashboardScreen(), 
    );
  }
}