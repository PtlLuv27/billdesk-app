import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../../../../core/database/database_helper.dart'; // Adjust path if needed
import '../../../../../models/user_model.dart'; // Adjust path if needed

// State is String?. If null, user is logged out. If it contains text, it is the logged-in userId.
class AuthNotifier extends Notifier<String?> {
  @override
  String? build() {
    return null; // Starts as null until checked
  }

  Future<void> checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString('loggedInUserId');
  }

  // Cryptographic hashing for local security
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  Future<String?> login(String email, String password) async {
    final db = await DatabaseHelper.instance.database;
    final hash = _hashPassword(password);
    
    // Check DB for matching email and hashed password
    final result = await db.query('users', where: 'email = ? AND passwordHash = ?', whereArgs: [email, hash]);

    if (result.isNotEmpty) {
      final userId = result.first['id'] as String;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('loggedInUserId', userId);
      state = userId; // Updates Riverpod state instantly
      return null; // Null means success (no error message)
    }
    return 'Invalid email or password.';
  }

  Future<String?> signUp(String name, String email, String password) async {
    final db = await DatabaseHelper.instance.database;
    
    // Ensure email is unique
    final existing = await db.query('users', where: 'email = ?', whereArgs: [email]);
    if (existing.isNotEmpty) return 'Email already in use.';

    final user = UserModel(
      id: const Uuid().v4(),
      name: name,
      email: email,
      passwordHash: _hashPassword(password),
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    await db.insert('users', user.toMap());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('loggedInUserId', user.id);
    state = user.id; 
    return null; // Success
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('loggedInUserId');
    state = null; // Logs out UI
  }
}

final authProvider = NotifierProvider<AuthNotifier, String?>(() => AuthNotifier());