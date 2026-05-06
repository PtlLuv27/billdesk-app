import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart'; // Ensure this path matches your project structure

class SyncEngine {
  static final _supabase = Supabase.instance.client;

  /// Call this when the app starts or when the dashboard loads.
  /// It synchronizes all tables between SQLite and Supabase.
  static Future<void> syncAll() async {
    if (_supabase.auth.currentUser == null) return;

    try {
      debugPrint("🔄 Starting Cloud Sync...");
      // Sync tables that have a 'lastUpdated' timestamp for conflict resolution
      await _syncTable('companies', hasLastUpdated: true);
      await _syncTable('purchasers', hasLastUpdated: true);
      await _syncTable('invoices', hasLastUpdated: true);
      
      // Payments doesn't have a lastUpdated column in your schema, 
      // so it will just push/pull missing records.
      await _syncTable('payments', hasLastUpdated: false);
      
      debugPrint("✅ Full Cloud Sync Complete!");
    } catch (e) {
      debugPrint("❌ Sync Error: $e");
    }
  }

  /// The core logic engine that compares local and cloud data
  static Future<void> _syncTable(String tableName, {required bool hasLastUpdated}) async {
    final db = await DatabaseHelper.instance.database;
    final userId = _supabase.auth.currentUser!.id;

    // 1. Fetch Local Data from SQLite
    final localRows = await db.query(tableName, where: 'userId = ?', whereArgs: [userId]);
    // Convert read-only SQLite maps to modifiable maps
    final localMap = {for (var row in localRows) row['id']: Map<String, dynamic>.from(row)};

    // 2. Fetch Cloud Data from Supabase
    final List<Map<String, dynamic>> cloudRows = await _supabase.from(tableName).select().eq('userId', userId);
    final cloudMap = {for (var row in cloudRows) row['id']: row};

    // 3. Compare and Resolve Conflicts
    for (var localId in localMap.keys) {
      final localData = localMap[localId]!;
      final cloudData = cloudMap[localId];

      if (cloudData == null) {
        // Exists locally but not in cloud -> Push to Cloud
        await _supabase.from(tableName).upsert(localData);
      } else if (hasLastUpdated) {
        // Exists in both -> Compare timestamps (Requirement #7)
        final localTime = localData['lastUpdated'] as int? ?? 0;
        final cloudTime = cloudData['lastUpdated'] as int? ?? 0;

        if (localTime > cloudTime) {
          // Local is newer -> Push to cloud
          await _supabase.from(tableName).upsert(localData);
        } else if (cloudTime > localTime) {
          // Cloud is newer -> Update local SQLite
          await db.update(tableName, cloudData, where: 'id = ?', whereArgs: [localId]);
        }
      }
    }

    // 4. Download missing Cloud records to Local
    for (var cloudId in cloudMap.keys) {
      if (!localMap.containsKey(cloudId)) {
         await db.insert(tableName, cloudMap[cloudId]!, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }
  }

  /// Use this in your providers to fire off a quick cloud update 
  /// immediately after saving to SQLite.
  static Future<void> pushSingleRecord(String tableName, Map<String, dynamic> data) async {
    try {
      await _supabase.from(tableName).upsert(data);
      debugPrint("✅ SUCCESS: Pushed to $tableName in the cloud!");
    } on PostgrestException catch (e) {
      // This catches Database errors (like missing columns or RLS security blocks)
      debugPrint("❌ SUPABASE DATABASE ERROR in $tableName: ${e.message}");
    } catch (e) {
      // This catches internet connection issues
      debugPrint("⚠️ OFFLINE: Could not push to $tableName. Will retry later. Error: $e");
    }
  }
}