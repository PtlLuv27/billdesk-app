import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../models/purchaser_model.dart';
import '../providers/invoice_provider.dart';
import '../providers/payment_provider.dart';

class PartyDetailsScreen extends ConsumerStatefulWidget {
  final Purchaser party;
  final List<Color> gradient;

  const PartyDetailsScreen({super.key, required this.party, required this.gradient});

  @override
  ConsumerState<PartyDetailsScreen> createState() => _PartyDetailsScreenState();
}

class _PartyDetailsScreenState extends ConsumerState<PartyDetailsScreen> {
  
  String formatAmount(double val) {
    final formatter = NumberFormat.decimalPattern('en_IN');
    return '₹${formatter.format(val.round())}/-';
  }

  @override
  Widget build(BuildContext context) {
    // 1. Fetch all invoices and payments for this specific party
    final allInvoices = ref.watch(invoiceProvider).where((i) => i.purchaserId == widget.party.id).toList();
    final allPayments = ref.watch(paymentProvider).where((p) => p.purchaserId == widget.party.id).toList();

    // 2. Calculate Net Balance
    double totalSales = 0.0;
    double totalPurchases = 0.0;
    double totalReceived = 0.0;
    double totalPaid = 0.0;

    for (var inv in allInvoices) {
      if (inv.type == 'sales') totalSales += inv.totalAmount;
      if (inv.type == 'purchase') totalPurchases += inv.totalAmount;
    }
    for (var pay in allPayments) {
      if (pay.type == 'received') totalReceived += pay.amount;
      if (pay.type == 'paid') totalPaid += pay.amount;
    }

    // Net Balance = (What they bought from us + What we paid them) - (What we bought from them + What they paid us)
    double netBalance = (totalSales + totalPaid) - (totalPurchases + totalReceived);

    // 3. Build Unified Timeline
    List<Map<String, dynamic>> timeline = [];
    
    for (var inv in allInvoices) {
      timeline.add({
        'isInvoice': true,
        'date': inv.billDate,
        'amount': inv.totalAmount,
        'type': inv.type, // 'sales' or 'purchase'
        'title': inv.billNo.trim().toUpperCase() == 'MANUAL' ? 'Manual Debit' : 'Bill #${inv.billNo}',
      });
    }
    
    for (var pay in allPayments) {
      timeline.add({
        'isInvoice': false,
        'date': pay.date,
        'amount': pay.amount,
        'type': pay.type, // 'received' or 'paid'
        'title': pay.notes.isNotEmpty ? 'Payment: ${pay.notes}' : 'Payment',
      });
    }

    // Sort newest first
    timeline.sort((a, b) => b['date'].compareTo(a['date']));

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      body: CustomScrollView(
        slivers: [
          // --- BEAUTIFUL GRADIENT APP BAR ---
          SliverAppBar(
            expandedHeight: 220.0,
            floating: false,
            pinned: true,
            backgroundColor: widget.gradient.first,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: widget.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 24, right: 24, top: 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        Text(widget.party.name, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text(widget.party.gstin.isEmpty ? 'GST: N/A' : 'GST: ${widget.party.gstin}', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                        Text('${widget.party.address1}, ${widget.party.address2}', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                        const Spacer(),
                        Text(
                          'Added on: ${DateFormat('dd MMM yyyy').format(DateTime.fromMillisecondsSinceEpoch(widget.party.lastUpdated))}',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- BALANCE CARD ---
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('NET BALANCE', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                              const SizedBox(height: 8),
                              Text(
                                formatAmount(netBalance.abs()),
                                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: netBalance >= 0 ? Colors.green.shade700 : Colors.red.shade700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                netBalance == 0 ? 'Account Settled' : (netBalance > 0 ? 'They owe us' : 'We owe them'),
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: netBalance >= 0 ? Colors.green.shade50 : Colors.red.shade50, shape: BoxShape.circle),
                          child: Icon(netBalance >= 0 ? Icons.call_received : Icons.call_made, color: netBalance >= 0 ? Colors.green : Colors.red, size: 32),
                        )
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                  const Text('Complete History', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF203A43))),
                  const SizedBox(height: 16),

                  // --- TIMELINE LIST ---
                  if (timeline.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40.0),
                        child: Text('No transactions yet.', style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    )
                  else
                    ...timeline.map((item) {
                      IconData icon;
                      Color color;
                      String subtitlePrefix;

                      // Configure styling based on transaction type
                      if (item['type'] == 'sales') {
                        icon = Icons.receipt_long;
                        color = Colors.blueAccent;
                        subtitlePrefix = 'Sale';
                      } else if (item['type'] == 'purchase') {
                        icon = Icons.shopping_cart;
                        color = Colors.pinkAccent;
                        subtitlePrefix = 'Purchase';
                      } else if (item['type'] == 'received') {
                        icon = Icons.payments;
                        color = Colors.green;
                        subtitlePrefix = 'Payment In';
                      } else { // 'paid'
                        icon = Icons.payments_outlined;
                        color = Colors.orange;
                        subtitlePrefix = 'Payment Out';
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: color.withOpacity(0.15),
                            child: Icon(icon, color: color),
                          ),
                          title: Text(item['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          subtitle: Text('$subtitlePrefix • ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.fromMillisecondsSinceEpoch(item['date']))}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                          trailing: Text(
                            formatAmount(item['amount']),
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: color),
                          ),
                        ),
                      );
                    }),
                    
                    const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}