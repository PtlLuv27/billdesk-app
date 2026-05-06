import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // <-- IMPORT SUPABASE FOR HARD DELETE
import '../../../../core/database/database_helper.dart';
import '../../../../core/database/sync_engine.dart'; // <-- IMPORT SYNC ENGINE
import '../../../../models/payment_model.dart';
import 'company_provider.dart';

class PaymentNotifier extends Notifier<List<Payment>> {
  @override
  List<Payment> build() {
    final currentCompany = ref.watch(activeCompanyProvider);
    
    if (currentCompany != null) {
      _loadPayments(currentCompany.id);
    }
    
    return [];
  }

  Future<void> _loadPayments(String companyId) async {
    final data = await DatabaseHelper.instance.getPaymentsByCompany(companyId);
    state = data;
  }

  Future<void> addPayment(Payment payment) async {
    // 1. Save locally
    await DatabaseHelper.instance.insertPayment(payment);
    
    // 2. Push to Cloud
    SyncEngine.pushSingleRecord('payments', payment.toMap());

    final currentCompany = ref.read(activeCompanyProvider);
    if (currentCompany != null) await _loadPayments(currentCompany.id);
  }

  Future<void> deletePayment(String id) async {
    // 1. Hard Delete locally
    await DatabaseHelper.instance.deletePayment(id);
    
    // 2. Hard Delete from Cloud
    try {
      await Supabase.instance.client.from('payments').delete().eq('id', id);
    } catch (e) {
      debugPrint("Offline: Could not delete payment from cloud immediately.");
    }

    final currentCompany = ref.read(activeCompanyProvider);
    if (currentCompany != null) await _loadPayments(currentCompany.id);
  }
}

final paymentProvider = NotifierProvider<PaymentNotifier, List<Payment>>(PaymentNotifier.new);