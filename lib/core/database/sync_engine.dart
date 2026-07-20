import 'package:flutter/foundation.dart';
import 'dart:convert'; // 🔥 REQUIRED FOR JSON CONVERSIONS
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart'; 

class SyncEngine {
  static final _supabase = Supabase.instance.client;

  static Future<void> syncAll() async {
    if (_supabase.auth.currentUser == null) return;

    try {
      debugPrint("🔄 Starting Cloud Sync...");
      
      await _syncTable('companies', hasLastUpdated: true);
      await _syncTable('purchasers', hasLastUpdated: true);
      await _syncTable('invoices', hasLastUpdated: true);
      await _syncTable('payments', hasLastUpdated: false);
      
      debugPrint("✅ Full Cloud Sync Complete!");
    } catch (e) {
      debugPrint("❌ Sync Error: $e");
    }
  }

  static Future<void> _syncTable(String tableName, {required bool hasLastUpdated}) async {
    final db = await DatabaseHelper.instance.database;
    final userId = _supabase.auth.currentUser!.id;

    final localRows = await db.query(tableName, where: 'userId = ?', whereArgs: [userId]);
    final localMap = {for (var row in localRows) row['id']: Map<String, dynamic>.from(row)};

    final List<Map<String, dynamic>> cloudRows = await _supabase.from(tableName).select().eq('userId', userId);
    final cloudMap = {for (var row in cloudRows) row['id']: row};

    for (var localId in localMap.keys) {
      final localData = localMap[localId]!;
      final cloudData = cloudMap[localId];

      if (cloudData == null) {
        // Push Local to Cloud (Ensure JSON strings are converted back to maps for Supabase)
        await _supabase.from(tableName).upsert(_prepareForSupabase(localData));
      } else if (hasLastUpdated) {
        final localTime = localData['lastUpdated'] as int? ?? 0;
        final cloudTime = cloudData['lastUpdated'] as int? ?? 0;

        if (localTime > cloudTime) {
          await _supabase.from(tableName).upsert(_prepareForSupabase(localData));
        } else if (cloudTime > localTime) {
          // Cloud to SQLite (Ensure Supabase maps are converted to JSON strings for SQLite)
          await db.update(tableName, _prepareForSqlite(cloudData), where: 'id = ?', whereArgs: [localId]);
        }
      }
    }

    // Download missing Cloud records to Local
    for (var cloudId in cloudMap.keys) {
      if (!localMap.containsKey(cloudId)) {
         await db.insert(tableName, _prepareForSqlite(cloudMap[cloudId]!), conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }
  }

  static Future<void> pushSingleRecord(String tableName, Map<String, dynamic> data) async {
    try {
      await _supabase.from(tableName).upsert(_prepareForSupabase(data));
      debugPrint("✅ SUCCESS: Pushed to $tableName in the cloud!");
    } on PostgrestException catch (e) {
      debugPrint("❌ SUPABASE DATABASE ERROR in $tableName: ${e.message}");
    } catch (e) {
      debugPrint("⚠️ OFFLINE: Could not push to $tableName. Will retry later. Error: $e");
    }
  }

  // --- 🔥 TRANSLATORS: SUPER IMPORTANT FOR MIXING SQLITE (TEXT) AND SUPABASE (JSONB) ---

  /// Prepares Cloud Data to be saved locally (Turns Map/Lists into Strings for SQLite)
  static Map<String, dynamic> _prepareForSqlite(Map<String, dynamic> cloudData) {
    final sanitized = Map<String, dynamic>.from(cloudData);
    sanitized.forEach((key, value) {
      if (value is Map || value is List) {
        sanitized[key] = jsonEncode(value);
      }
    });
    return sanitized;
  }

  /// Prepares Local Data to be pushed to the cloud (Turns Strings into Maps for Supabase JSONB columns)
  static Map<String, dynamic> _prepareForSupabase(Map<String, dynamic> localData) {
    final sanitized = Map<String, dynamic>.from(localData);
    
    if (sanitized['purchaser_snapshot'] is String) {
      try { sanitized['purchaser_snapshot'] = jsonDecode(sanitized['purchaser_snapshot']); } catch (_) {}
    }
    if (sanitized['company_snapshot'] is String) {
      try { sanitized['company_snapshot'] = jsonDecode(sanitized['company_snapshot']); } catch (_) {}
    }
    
    return sanitized;
  }
}