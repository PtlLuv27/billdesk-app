import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../models/company_model.dart';
import '../../../../models/payment_model.dart';
import 'company_provider.dart';

class PaymentNotifier extends Notifier<List<Payment>> {
  @override
  List<Payment> build() {
    // Listen for company changes to load the correct payments dynamically
    ref.listen<Company?>(activeCompanyProvider, (previous, next) {
      if (next != null) {
        loadPayments(next.id);
      } else {
        state = [];
      }
    });

    // Perform initial load if a company is already active on startup
    final currentCompany = ref.read(activeCompanyProvider);
    if (currentCompany != null) {
      loadPayments(currentCompany.id);
    }
    
    return [];
  }

  Future<void> loadPayments(String companyId) async {
    final data = await DatabaseHelper.instance.getPayments(companyId);
    state = data.map((e) => Payment.fromMap(e)).toList();
  }

  Future<void> addPayment(Payment payment) async {
    await DatabaseHelper.instance.insertPayment(payment.toMap());
    state = [...state, payment];
  }

  Future<void> deletePayment(String id) async {
    await DatabaseHelper.instance.deletePayment(id);
    state = state.where((p) => p.id != id).toList();
  }
}

// Modern Riverpod 2.x Provider Syntax
final paymentProvider = NotifierProvider<PaymentNotifier, List<Payment>>(() {
  return PaymentNotifier();
});