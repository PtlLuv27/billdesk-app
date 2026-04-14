import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_helper.dart';
import '../../../models/purchaser_model.dart';

class PurchaserNotifier extends Notifier<List<Purchaser>> {
  @override
  List<Purchaser> build() {
    // Load all purchasers globally on startup
    _loadPurchasers();
    return []; 
  }

  Future<void> _loadPurchasers() async {
    final purchasers = await DatabaseHelper.instance.getAllActivePurchasers();
    state = purchasers;
  }

  Future<void> addPurchaser(Purchaser newPurchaser) async {
    await DatabaseHelper.instance.insertPurchaser(newPurchaser);
    await _loadPurchasers(); // Refresh the global list
  }

  Future<void> updatePurchaser(Purchaser updatedPurchaser) async {
    await DatabaseHelper.instance.updatePurchaser(updatedPurchaser);
    await _loadPurchasers(); // Refresh the global list
  }

}

final purchaserProvider = NotifierProvider<PurchaserNotifier, List<Purchaser>>(() {
  return PurchaserNotifier();
});