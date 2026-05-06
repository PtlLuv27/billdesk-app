// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:supabase_flutter/supabase_flutter.dart'; // <-- 1. IMPORT SUPABASE
// import '../providers/auth_provider.dart';
// import '../../dashboard/global_dashboard_screen.dart';
// import 'login_screen.dart';
// import 'verify_otp_screen.dart'; // <-- 2. IMPORT THE NEW PASSWORD SCREEN

// class AuthWrapper extends ConsumerStatefulWidget {
//   const AuthWrapper({super.key});

//   @override
//   ConsumerState<AuthWrapper> createState() => _AuthWrapperState();
// }

// class _AuthWrapperState extends ConsumerState<AuthWrapper> {
//   late final StreamSubscription<AuthState> _authSubscription;

//   @override
//   void initState() {
//     super.initState();

//     // --- CATCH DEEP LINKS & PASSWORD RESETS ---
//     _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
//       final AuthChangeEvent event = data.event;
      
//       // If the phone wakes up because the user clicked a "Reset Password" link in Gmail...
//       if (event == AuthChangeEvent.passwordRecovery) {
//         if (mounted) {
//           // Push them directly to the screen to type their new password
//           Navigator.push(
//             context,
//             MaterialPageRoute(builder: (context) => const UpdatePasswordScreen()),
//           );
//         }
//       }
//     });
//   }

//   @override
//   void dispose() {
//     _authSubscription.cancel(); // Always clean up your listeners!
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     // Watch the Supabase authentication state
//     final userId = ref.watch(authProvider);

//     // If userId exists, bypass login and go straight to the Dashboard!
//     if (userId != null) {
//       return const GlobalDashboardScreen();
//     } else {
//       return const LoginScreen(); 
//     }
//   }
// }

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../../dashboard/global_dashboard_screen.dart';
import 'login_screen.dart';

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the Supabase authentication state from your provider
    final userId = ref.watch(authProvider);

    // If userId exists, bypass login and go straight to the Dashboard!
    if (userId != null) {
      return const GlobalDashboardScreen();
    } else {
      return const LoginScreen(); 
    }
  }
}