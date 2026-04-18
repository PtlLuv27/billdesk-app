import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database_helper.dart';
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
    await DatabaseHelper.instance.insertPayment(payment);
    final currentCompany = ref.read(activeCompanyProvider);
    if (currentCompany != null) await _loadPayments(currentCompany.id);
  }

  Future<void> deletePayment(String id) async {
    await DatabaseHelper.instance.deletePayment(id);
    final currentCompany = ref.read(activeCompanyProvider);
    if (currentCompany != null) await _loadPayments(currentCompany.id);
  }
}

final paymentProvider = NotifierProvider<PaymentNotifier, List<Payment>>(PaymentNotifier.new);