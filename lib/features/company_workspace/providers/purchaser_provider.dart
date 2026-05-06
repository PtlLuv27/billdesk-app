import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/database/sync_engine.dart'; // <-- 1. IMPORT SYNC ENGINE
import '../../../models/purchaser_model.dart';
import '../../authentication/providers/auth_provider.dart';

class PurchaserNotifier extends Notifier<List<Purchaser>> {
  @override
  List<Purchaser> build() {
    final userId = ref.watch(authProvider);
    
    if (userId != null) {
      _loadPurchasers(userId);
    }
    
    return []; 
  }

  Future<void> _loadPurchasers(String userId) async {
    final db = await DatabaseHelper.instance.database;
    // Uses camelCase isDeleted to match the updated database helper
    final maps = await db.query('purchasers', where: 'userId = ? AND isDeleted = 0', whereArgs: [userId]);
    state = maps.map((m) => Purchaser.fromMap(m)).toList();
  }

  Future<void> addPurchaser(Purchaser newPurchaser) async {
    // 1. Save locally
    await DatabaseHelper.instance.insertPurchaser(newPurchaser);
    
    // 2. Push to Cloud
    SyncEngine.pushSingleRecord('purchasers', newPurchaser.toMap());

    final userId = ref.read(authProvider);
    if (userId != null) await _loadPurchasers(userId); 
  }

  Future<void> updatePurchaser(Purchaser updatedPurchaser) async {
    // 1. Update locally
    await DatabaseHelper.instance.updatePurchaser(updatedPurchaser);
    
    // 2. Push to Cloud
    SyncEngine.pushSingleRecord('purchasers', updatedPurchaser.toMap());

    final userId = ref.read(authProvider);
    if (userId != null) await _loadPurchasers(userId); 
  }

  Future<void> deletePurchaser(Purchaser purchaser) async {
    final updatedPurchaser = Purchaser(
      id: purchaser.id, userId: purchaser.userId, name: purchaser.name,
      address1: purchaser.address1, address2: purchaser.address2,
      particulars: purchaser.particulars, gstin: purchaser.gstin,
      hsnNo: purchaser.hsnNo, sgstRate: purchaser.sgstRate,
      cgstRate: purchaser.cgstRate, igstRate: purchaser.igstRate,
      lastUpdated: DateTime.now().millisecondsSinceEpoch,
      isDeleted: 1, // Soft Delete Flag
    );
    
    // 1. Soft Delete locally
    await DatabaseHelper.instance.updatePurchaser(updatedPurchaser);
    
    // 2. Push Soft Delete to Cloud
    SyncEngine.pushSingleRecord('purchasers', updatedPurchaser.toMap());

    final userId = ref.read(authProvider);
    if (userId != null) await _loadPurchasers(userId); 
  }
}

final purchaserProvider = NotifierProvider<PurchaserNotifier, List<Purchaser>>(PurchaserNotifier.new);