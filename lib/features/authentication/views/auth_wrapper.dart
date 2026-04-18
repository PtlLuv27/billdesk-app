import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../../dashboard/global_dashboard_screen.dart';
import 'sign_up_screen.dart';

class AuthWrapper extends ConsumerStatefulWidget {
  const AuthWrapper({super.key});

  @override
  ConsumerState<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends ConsumerState<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    // Check the local hard drive on boot to see if the user is already logged in!
    Future.microtask(() => ref.read(authProvider.notifier).checkLoginStatus());
  }

  @override
  Widget build(BuildContext context) {
    // Watch the authentication state (returns userId if logged in, null if not)
    final userId = ref.watch(authProvider);

    // If userId exists, show the Dashboard. If null, show the Login Screen!
    if (userId != null) {
      return const GlobalDashboardScreen();
    } else {
      return const SignUpScreen();
    }
  }
}