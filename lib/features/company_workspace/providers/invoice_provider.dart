import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_helper.dart';
import '../../../models/invoice_model.dart';
import 'company_provider.dart';

class InvoiceNotifier extends Notifier<List<Invoice>> {
  @override
  List<Invoice> build() {
    // Watch the active company
    final activeCompany = ref.watch(activeCompanyProvider);
    
    if (activeCompany != null) {
      _loadInvoices(activeCompany.id);
    }
    
    return []; 
  }

  Future<void> _loadInvoices(String companyId) async {
    final invoices = await DatabaseHelper.instance.getInvoicesByCompany(companyId);
    state = invoices;
  }

  Future<void> addInvoice(Invoice newInvoice) async {
    await DatabaseHelper.instance.insertInvoice(newInvoice);
    
    // Refresh the list
    final activeCompany = ref.read(activeCompanyProvider);
    if (activeCompany != null) {
      await _loadInvoices(activeCompany.id);
    }
  }

  Future<void> updateInvoice(Invoice updatedInvoice) async {
    await DatabaseHelper.instance.updateInvoice(updatedInvoice);
    final activeCompany = ref.read(activeCompanyProvider);
    if (activeCompany != null) {
      await _loadInvoices(activeCompany.id); // Refresh the UI
    }
  }

  Future<void> deleteInvoice(String id) async {
    await DatabaseHelper.instance.deleteInvoice(id);
    final activeCompany = ref.read(activeCompanyProvider);
    if (activeCompany != null) {
      await _loadInvoices(activeCompany.id); // Refresh the list
    }
  }

}

final invoiceProvider = NotifierProvider<InvoiceNotifier, List<Invoice>>(() {
  return InvoiceNotifier();
});