import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // --- ADDED THIS IMPORT ---
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'; 
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; 
import 'features/authentication/views/splash_screen.dart';
import 'package:protocol_handler/protocol_handler.dart';
import 'package:windows_single_instance/windows_single_instance.dart';

// --- NEW HELPER TO CATCH BOTH FLOWS (UPDATED FOR PKCE) ---
void _handleWindowsDeepLink(List<String> args) async {
  if (args.isNotEmpty) {
    final uriString = args.first;
    
    // Ensure we are only parsing our specific deep link
    if (uriString.startsWith('io.supabase.billdesk')) {
      // OAuth returns data in the fragment (#) or query (?). Convert to parse safely.
      final uri = Uri.parse(uriString.replaceFirst('#', '?'));
      
      // 1. Check for PKCE Flow (The new secure standard from Supabase)
      final code = uri.queryParameters['code'];
      if (code != null) {
        // Exchange the secure code for an actual session!
        await Supabase.instance.client.auth.exchangeCodeForSession(code);
        return;
      }

      // 2. Fallback for older Implicit Flow
      final refreshToken = uri.queryParameters['refresh_token'];
      if (refreshToken != null) {
         await Supabase.instance.client.auth.setSession(refreshToken);
      }
    }
  }
}

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- WINDOWS DEEP LINK FIX (Safeguarded against Web/Android) ---
  if (!kIsWeb && Platform.isWindows) {
    await protocolHandler.register('io.supabase.billdesk');

    // Prevent a second app window from opening and catch the redirect
    await WindowsSingleInstance.ensureSingleInstance(
      args, // Passing the actual browser arguments instead of []
      "billdesk_app_instance",
      onSecondWindow: (newArgs) {
        // Triggered if the app was ALREADY open in the background
        _handleWindowsDeepLink(newArgs);
      },
    );
    
    // Triggered if the app was COMPLETELY CLOSED and the browser launched it
    _handleWindowsDeepLink(args);
  }

  // Initialize SQLite for Windows/Linux
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Initialize Supabase Cloud
  await Supabase.initialize(
    url: 'https://kesvktyqczxkpayzwnzc.supabase.co', 
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imtlc3ZrdHlxY3p4a3BheXp3bnpjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY1OTU4MjUsImV4cCI6MjA5MjE3MTgyNX0.cncej1ADvBhZsL9i7BgkI-jtm3hBO2I66h0Ti37e28g',
  );

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