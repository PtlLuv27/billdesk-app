import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/database/sync_engine.dart'; // <-- 1. IMPORT SYNC ENGINE
import '../../../models/invoice_model.dart';
import 'company_provider.dart';

class InvoiceNotifier extends Notifier<List<Invoice>> {
  @override
  List<Invoice> build() {
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
    
    // Send to Cloud
    SyncEngine.pushSingleRecord('invoices', newInvoice.toMap());

    final activeCompany = ref.read(activeCompanyProvider);
    if (activeCompany != null) await _loadInvoices(activeCompany.id);
  }

  Future<void> updateInvoice(Invoice updatedInvoice) async {
    await DatabaseHelper.instance.updateInvoice(updatedInvoice);
    
    // Send to Cloud
    SyncEngine.pushSingleRecord('invoices', updatedInvoice.toMap());

    final activeCompany = ref.read(activeCompanyProvider);
    if (activeCompany != null) await _loadInvoices(activeCompany.id); 
  }

  // Changed from (String id) to (Invoice invoice) to allow Soft Deletes!
  Future<void> deleteInvoice(Invoice invoice) async {
    final deletedInvoice = Invoice(
      id: invoice.id, userId: invoice.userId, companyId: invoice.companyId,
      type: invoice.type, purchaserId: invoice.purchaserId, billNo: invoice.billNo,
      billDate: invoice.billDate, truckNo: invoice.truckNo, driverName: invoice.driverName,
      licNo: invoice.licNo, nos: invoice.nos, unit: invoice.unit,
      quantity: invoice.quantity, rate: invoice.rate, amount: invoice.amount,
      labourCharge: invoice.labourCharge, subTotal: invoice.subTotal,
      gstAmount: invoice.gstAmount, totalAmount: invoice.totalAmount,
      lastUpdated: DateTime.now().millisecondsSinceEpoch,
      isDeleted: 1, // Soft Delete
    );

    // Update SQLite instead of hard deleting
    await DatabaseHelper.instance.updateInvoice(deletedInvoice);
    
    // Send Soft Delete to Cloud
    SyncEngine.pushSingleRecord('invoices', deletedInvoice.toMap());

    final activeCompany = ref.read(activeCompanyProvider);
    if (activeCompany != null) await _loadInvoices(activeCompany.id); 
  }
}

final invoiceProvider = NotifierProvider<InvoiceNotifier, List<Invoice>>(InvoiceNotifier.new);