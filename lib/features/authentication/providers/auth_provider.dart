import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthNotifier extends Notifier<String?> {
  final _supabase = Supabase.instance.client;

  @override
  String? build() {
    // Automatically listen for login/logout events from Supabase
    _supabase.auth.onAuthStateChange.listen((data) {
      final Session? session = data.session;
      state = session?.user.id;
    });
    
    // Return current user ID on initial load
    return _supabase.auth.currentUser?.id;
  }

  // --- 1. EMAIL & PASSWORD LOGIN ---
  Future<String?> login(String email, String password) async {
    try {
      await _supabase.auth.signInWithPassword(email: email.trim(), password: password);
      return null; // Success
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'An unexpected error occurred.';
    }
  }

  // --- 2. EMAIL & PASSWORD SIGN UP ---
  Future<String?> signUp(String name, String email, String password) async {
    try {
      await _supabase.auth.signUp(
        email: email.trim(), 
        password: password,
        data: {'full_name': name.trim()}, // Saves the user's name to their cloud profile
      );
      return null; 
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'An unexpected error occurred.';
    }
  }

  // --- 3. FORGOT PASSWORD LOGIC ---
  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      // await _supabase.auth.resetPasswordForEmail(
      //   email.trim(),
      //   // --- THE FIX: Tell the email to link back to the app! ---
      //   redirectTo: 'io.supabase.billdesk://login-callback/', 
      // );
      await Supabase.instance.client.auth.resetPasswordForEmail(
  email,
  // THIS TELLS THE EMAIL LINK TO OPEN THE APP
  redirectTo: 'io.supabase.billdesk://login-callback/', 
);
      return null; // Success
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Error sending reset email.';
    }
  }

  // --- 4. GOOGLE SIGN IN ---
  Future<String?> signInWithGoogle() async {
    try {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        // Add the trailing slash here so it matches the dashboard exactly!
        redirectTo: 'io.supabase.billdesk://login-callback/', 
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'An unexpected error occurred during Google Sign-In.';
    }
  }

  // --- 5. LOGOUT ---
  Future<void> logout() async {
    await _supabase.auth.signOut();
  }
}

final authProvider = NotifierProvider<AuthNotifier, String?>(AuthNotifier.new);