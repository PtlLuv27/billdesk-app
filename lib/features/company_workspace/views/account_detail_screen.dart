import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../models/purchaser_model.dart';
import '../../../../models/payment_model.dart';
import '../providers/invoice_provider.dart';
import '../providers/payment_provider.dart';
import '../providers/company_provider.dart';

class AccountDetailScreen extends ConsumerStatefulWidget {
  final Purchaser purchaser;
  const AccountDetailScreen({super.key, required this.purchaser});

  @override
  ConsumerState<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends ConsumerState<AccountDetailScreen> {
  String _filter = 'Sales'; // 'Sales' (They owe us) or 'Purchases' (We owe them)

  void _showAddPaymentDialog(bool isReceiving) {
    final amtCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isReceiving ? 'Record Payment Received' : 'Record Payment Made', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(controller: amtCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (₹)', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Notes (e.g. Cash, Cheque No.)', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: isReceiving ? Colors.green : Colors.red),
              onPressed: () async {
                if (amtCtrl.text.isEmpty) return;
                final company = ref.read(activeCompanyProvider);
                final payment = Payment(
                  id: const Uuid().v4(), companyId: company!.id, purchaserId: widget.purchaser.id,
                  amount: double.parse(amtCtrl.text), date: DateTime.now().millisecondsSinceEpoch,
                  type: isReceiving ? 'received' : 'paid', notes: noteCtrl.text,
                );
                await ref.read(paymentProvider.notifier).addPayment(payment);
                if (mounted) Navigator.pop(context);
              },
              child: const Text('Save Payment', style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allInvoices = ref.watch(invoiceProvider).where((i) => i.purchaserId == widget.purchaser.id).toList();
    final allPayments = ref.watch(paymentProvider).where((p) => p.purchaserId == widget.purchaser.id).toList();

    final isSalesMode = _filter == 'Sales';
    
    // Filter data based on mode
    final relevantInvoices = allInvoices.where((i) => i.type == (isSalesMode ? 'sales' : 'purchase')).toList();
    final relevantPayments = allPayments.where((p) => p.type == (isSalesMode ? 'received' : 'paid')).toList();

    // Calculate Totals
    final totalBilled = relevantInvoices.fold(0.0, (sum, i) => sum + i.totalAmount);
    final totalPaid = relevantPayments.fold(0.0, (sum, p) => sum + p.amount);
    final outstanding = totalBilled - totalPaid;

    // Build Unified Timeline
    List<Map<String, dynamic>> timeline = [];
    for (var i in relevantInvoices) timeline.add({'isInvoice': true, 'date': i.billDate, 'title': 'Bill #${i.billNo}', 'amount': i.totalAmount});
    for (var p in relevantPayments) timeline.add({'isInvoice': false, 'date': p.date, 'title': 'Payment ${isSalesMode ? "Received" : "Made"}', 'amount': p.amount, 'notes': p.notes, 'id': p.id});
    
    // Sort newest to oldest
    timeline.sort((a, b) => b['date'].compareTo(a['date']));

    return Scaffold(
      appBar: AppBar(title: Text(widget.purchaser.name)),
      body: Column(
        children: [
          // Filter Toggle
          Padding(
            padding: const EdgeInsets.all(16),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'Sales', label: Text('Sales (They Owe Us)')),
                ButtonSegment(value: 'Purchases', label: Text('Purchases (We Owe Them)')),
              ],
              selected: {_filter},
              onSelectionChanged: (val) => setState(() => _filter = val.first),
            ),
          ),
          
          // Summary Cards
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: _statCard('Total Billed', totalBilled, Colors.blue)),
                const SizedBox(width: 8),
                Expanded(child: _statCard(isSalesMode ? 'Total Received' : 'Total Paid', totalPaid, isSalesMode ? Colors.green : Colors.orange)),
                const SizedBox(width: 8),
                Expanded(child: _statCard('Pending', outstanding, outstanding > 0 ? Colors.red : Colors.grey)),
              ],
            ),
          ),
          const Divider(height: 30),

          // Timeline
          Expanded(
            child: timeline.isEmpty 
              ? const Center(child: Text('No history found.'))
              : ListView.builder(
                  itemCount: timeline.length,
                  itemBuilder: (context, index) {
                    final item = timeline[index];
                    final isInvoice = item['isInvoice'];
                    
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isInvoice ? Colors.blue.shade100 : (isSalesMode ? Colors.green.shade100 : Colors.orange.shade100),
                        child: Icon(isInvoice ? Icons.receipt : Icons.payments, color: isInvoice ? Colors.blue : (isSalesMode ? Colors.green : Colors.orange)),
                      ),
                      title: Text(item['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.fromMillisecondsSinceEpoch(item['date']))}${!isInvoice && item['notes'] != '' ? "\nNote: ${item['notes']}" : ""}'),
                      trailing: Text(
                        '${isInvoice ? "+" : "-"} ₹${item['amount'].toStringAsFixed(0)}',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isInvoice ? Colors.black : (isSalesMode ? Colors.green : Colors.orange)),
                      ),
                      onLongPress: !isInvoice ? () async {
                        // Option to delete a payment
                        showDialog(context: context, builder: (_) => AlertDialog(
                          title: const Text('Delete Payment?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                            ElevatedButton(onPressed: () { ref.read(paymentProvider.notifier).deletePayment(item['id']); Navigator.pop(context); }, child: const Text('Delete')),
                          ],
                        ));
                      } : null,
                    );
                  }
              ),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddPaymentDialog(isSalesMode),
        icon: const Icon(Icons.add),
        label: Text(isSalesMode ? 'Receive Payment' : 'Make Payment'),
        backgroundColor: isSalesMode ? Colors.green : Colors.redAccent,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _statCard(String title, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.5))),
      child: Column(
        children: [
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('₹${amount.toStringAsFixed(0)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}