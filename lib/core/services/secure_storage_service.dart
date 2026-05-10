import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final secureStorageProvider = Provider((ref) => SecureStorageService());

class SecureStorageService {
  final _storage = const FlutterSecureStorage();
  static const _accountsKey = 'saved_workspace_accounts';

  // 1. Save an account and its token
  Future<void> saveSession(String email, String refreshToken) async {
    final existingStr = await _storage.read(key: _accountsKey);
    Map<String, dynamic> accounts = existingStr != null ? jsonDecode(existingStr) : {};
    
    accounts[email] = refreshToken;
    
    await _storage.write(key: _accountsKey, value: jsonEncode(accounts));
  }

  // 2. Get a list of all saved emails for the UI
  Future<List<String>> getSavedEmails() async {
    final existingStr = await _storage.read(key: _accountsKey);
    if (existingStr == null) return [];
    
    Map<String, dynamic> accounts = jsonDecode(existingStr);
    return accounts.keys.toList();
  }

  // 3. Get the specific token when a user clicks an email
  Future<String?> getTokenForEmail(String email) async {
    final existingStr = await _storage.read(key: _accountsKey);
    if (existingStr == null) return null;
    
    Map<String, dynamic> accounts = jsonDecode(existingStr);
    return accounts[email];
  }

  // 4. Remove a specific session (Now safely inside the class!)
  Future<void> removeSession(String email) async {
    final existingStr = await _storage.read(key: _accountsKey);
    if (existingStr == null) return;
    
    Map<String, dynamic> accounts = jsonDecode(existingStr);
    accounts.remove(email); 
    
    await _storage.write(key: _accountsKey, value: jsonEncode(accounts));
  }
}