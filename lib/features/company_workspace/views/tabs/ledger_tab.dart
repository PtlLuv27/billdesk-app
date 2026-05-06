import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../models/invoice_model.dart';
import '../../../../models/purchaser_model.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/company_provider.dart';
import '../../providers/purchaser_provider.dart';
import '../editable_invoice_screen.dart';
import '../editable_purchase_screen.dart'; 

// --- RIVERPOD 3.x PROVIDER TO PERSIST DATES ACROSS TABS ---
class LedgerDateRangeNotifier extends Notifier<DateTimeRange?> {
  @override
  DateTimeRange? build() {
    return null; // Initial state is null (no dates selected)
  }

  void setDateRange(DateTimeRange? range) {
    state = range;
  }
}

final ledgerDateRangeProvider = NotifierProvider<LedgerDateRangeNotifier, DateTimeRange?>(
  LedgerDateRangeNotifier.new,
);

class LedgerTab extends ConsumerStatefulWidget {
  const LedgerTab({super.key});

  @override
  ConsumerState<LedgerTab> createState() => _LedgerTabState();
}

class _LedgerTabState extends ConsumerState<LedgerTab> {
  // Local state for UI filters (Dates are now handled by Riverpod)
  String _typeFilter = 'Both'; 
  String _taxFilter = 'With GST'; 
  String? _selectedPurchaserId; 
  bool _isNewestFirst = true;

  // --- COMMA FORMATTER (With 2 decimals for Ledger) ---
  String formatAmount(double val) {
    return NumberFormat.currency(locale: 'en_IN', symbol: '', decimalDigits: 2).format(val);
  }

  List<Invoice> _getFilteredInvoices(List<Invoice> allInvoices, DateTimeRange? dateRange) {
    return allInvoices.where((invoice) {
      // NOTE: We no longer filter out 'MANUAL' here so we can calculate the total balance later.
      
      if (dateRange != null) {
        final billDate = DateTime.fromMillisecondsSinceEpoch(invoice.billDate);
        final start = DateTime(dateRange.start.year, dateRange.start.month, dateRange.start.day);
        final end = DateTime(dateRange.end.year, dateRange.end.month, dateRange.end.day, 23, 59, 59);
        if (billDate.isBefore(start) || billDate.isAfter(end)) return false;
      }
      
      if (_typeFilter == 'Sales Only' && invoice.type != 'sales') return false;
      if (_typeFilter == 'Purchase Only' && invoice.type != 'purchase') return false;
      
      if (_selectedPurchaserId != null && invoice.purchaserId != _selectedPurchaserId) {
        return false; 
      }
      
      return true;
    }).toList();
  }

  double _calculateNetBalance(List<Invoice> invoicesToCalculate) {
    double totalSales = 0.0;
    double totalPurchases = 0.0;

    for (var invoice in invoicesToCalculate) {
      double amountToAdd = _taxFilter == 'With GST' ? invoice.totalAmount : invoice.subTotal;

      if (invoice.type == 'sales') {
        totalSales += amountToAdd;
      } else if (invoice.type == 'purchase') {
        totalPurchases += amountToAdd;
      }
    }

    return totalSales - totalPurchases;
  }

  Future<void> _selectDateRange() async {
    final currentRange = ref.read(ledgerDateRangeProvider);

    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: currentRange,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    
    if (picked != null) {
      // Save dates to Riverpod global state
      ref.read(ledgerDateRangeProvider.notifier).setDateRange(picked);
    }
  }

  void _showEditBillNoDialog(BuildContext context, Invoice invoice, WidgetRef ref) {
    final editCtrl = TextEditingController(text: invoice.billNo);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Bill Name/No.'),
        content: TextField(
          controller: editCtrl,
          decoration: const InputDecoration(labelText: 'New Bill No.', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (editCtrl.text.isNotEmpty) {
                final updatedInvoice = Invoice(
                  id: invoice.id, userId: invoice.userId, companyId: invoice.companyId, type: invoice.type,
                  purchaserId: invoice.purchaserId, billDate: invoice.billDate,
                  truckNo: invoice.truckNo, driverName: invoice.driverName,
                  licNo: invoice.licNo, nos: invoice.nos, unit: invoice.unit,
                  quantity: invoice.quantity, rate: invoice.rate, amount: invoice.amount,
                  labourCharge: invoice.labourCharge, subTotal: invoice.subTotal,
                  gstAmount: invoice.gstAmount, totalAmount: invoice.totalAmount,
                  lastUpdated: DateTime.now().millisecondsSinceEpoch,
                  billNo: editCtrl.text.trim(),
                  isDeleted: invoice.isDeleted,
                );
                
                await ref.read(invoiceProvider.notifier).updateInvoice(updatedInvoice);
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // --- UI HELPER FOR BALANCE CARDS ---
  Widget _buildBalanceCard(String title, double balance) {
    final isPositive = balance >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: isPositive ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isPositive ? Colors.green : Colors.red, width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54, height: 1.3),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '₹${formatAmount(balance)}',
              style: TextStyle(
                fontSize: 20, // Reduced from 32 to fit two boxes side-by-side cleanly
                fontWeight: FontWeight.bold,
                color: isPositive ? Colors.green.shade700 : Colors.red.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allInvoices = ref.watch(invoiceProvider);
    final allPurchasers = ref.watch(purchaserProvider); 
    
    // Watch the global date range state
    final dateRange = ref.watch(ledgerDateRangeProvider);
    
    // 1. Get ALL matched invoices (Including Manual)
    final allFilteredInvoices = _getFilteredInvoices(allInvoices, dateRange);
    
    // 2. Filter out MANUAL invoices for the main list and "Without Manual" calculation
    final displayInvoices = allFilteredInvoices.where((i) => i.billNo.trim().toUpperCase() != 'MANUAL').toList();
    
    // 3. Calculate both balances independently
    final netBalanceWithoutManual = _calculateNetBalance(displayInvoices);
    final netBalanceWithManual = _calculateNetBalance(allFilteredInvoices);

    // 4. Sort only the display invoices (the ones we actually show in the list)
    final sortedInvoices = List<Invoice>.from(displayInvoices);
    sortedInvoices.sort((a, b) {
      if (_isNewestFirst) {
        return b.billDate.compareTo(a.billDate); // Newest First
      } else {
        return a.billDate.compareTo(b.billDate); // Oldest First
      }
    });

    return Scaffold(
      body: Column(
        children: [
          // --- FILTER CONTROLS ---
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey.shade100,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_month),
                        label: Text(dateRange == null 
                            ? 'Select Date Range' 
                            : '${DateFormat('dd/MM/yy').format(dateRange.start)} - ${DateFormat('dd/MM/yy').format(dateRange.end)}'),
                        onPressed: _selectDateRange,
                      ),
                    ),
                    if (dateRange != null)
                      IconButton(
                        icon: const Icon(Icons.clear, color: Colors.redAccent),
                        tooltip: 'Clear Dates',
                        onPressed: () {
                          // Clear dates from Riverpod global state
                          ref.read(ledgerDateRangeProvider.notifier).setDateRange(null);
                        },
                      )
                  ],
                ),
                const SizedBox(height: 10),
                
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Transaction Type', isDense: true, border: OutlineInputBorder()),
                        value: _typeFilter,
                        items: ['Both', 'Sales Only', 'Purchase Only'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (val) => setState(() => _typeFilter = val!),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Tax Setting', isDense: true, border: OutlineInputBorder()),
                        value: _taxFilter,
                        items: ['With GST', 'Without GST'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (val) => setState(() => _taxFilter = val!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                
                DropdownButtonFormField<String?>(
                  decoration: const InputDecoration(
                    labelText: 'Filter by Party / Purchaser', 
                    isDense: true, 
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_search),
                  ),
                  value: _selectedPurchaserId,
                  isExpanded: true, 
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Parties', style: TextStyle(fontWeight: FontWeight.bold))),
                    ...allPurchasers.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))),
                  ],
                  onChanged: (val) => setState(() => _selectedPurchaserId = val),
                ),
              ],
            ),
          ),

          // --- ANALYTICS DASHBOARD (SIDE-BY-SIDE BOXES) ---
          Container(
            margin: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildBalanceCard(
                        _selectedPurchaserId == null ? 'NET BALANCE' : 'PARTY BALANCE\n(Without Manual)', 
                        netBalanceWithoutManual
                      )
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildBalanceCard(
                        _selectedPurchaserId == null ? 'BALANCE\n(With Manual Entries)' : 'PARTY BALANCE\n(With Manual)', 
                        netBalanceWithManual
                      )
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _taxFilter == 'With GST' ? '* Balances are Including Tax' : '* Balances are Sub Total Only', 
                  style: const TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic)
                ),
              ],
            ),
          ),

          // --- BILLS ARCHIVE LIST ---
          Expanded(
            child: sortedInvoices.isEmpty
                ? const Center(child: Text('No transactions found for these filters.'))
                : ListView.builder(
                    itemCount: sortedInvoices.length,
                    itemBuilder: (context, index) {
                      final invoice = sortedInvoices[index];
                      final isSale = invoice.type == 'sales';
                      
                      final purchaser = allPurchasers.firstWhere(
                        (p) => p.id == invoice.purchaserId, 
                        orElse: () => Purchaser(id: '', userId: '', name: 'Unknown', address1: '', address2: '', particulars: '', gstin: '', hsnNo: '', sgstRate: 0, cgstRate: 0, igstRate: 0, lastUpdated: 0)
                      );
                      
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isSale ? Colors.blue.shade100 : Colors.red.shade100,
                          child: Icon(
                            isSale ? Icons.arrow_upward : Icons.arrow_downward,
                            color: isSale ? Colors.blue : Colors.red,
                          ),
                        ),
                        
                        title: Text('Bill #${invoice.billNo}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text('${purchaser.name}\n${DateFormat('dd MMM yyyy').format(DateTime.fromMillisecondsSinceEpoch(invoice.billDate))}', style: TextStyle(color: Colors.grey.shade700)),
                        ),
                        isThreeLine: true,
                        
                        trailing: Text(
                          '₹${formatAmount(_taxFilter == 'With GST' ? invoice.totalAmount : invoice.subTotal)}',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isSale ? Colors.green : Colors.red),
                        ),
                        onTap: () {
                          final company = ref.read(activeCompanyProvider);

                          if (isSale) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditableInvoiceScreen(
                                  invoice: invoice,
                                  company: company!,
                                  purchaser: purchaser
                                )
                              ),
                            );
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditablePurchaseScreen(
                                  invoice: invoice,
                                  company: company!,
                                  purchaser: purchaser
                                )
                              ),
                            );
                          }
                        },
                        onLongPress: () {
                          showModalBottomSheet(
                            context: context,
                            builder: (context) => SafeArea(
                              child: Wrap(
                                children: [
                                  ListTile(
                                    leading: const Icon(Icons.calendar_month, color: Colors.blue),
                                    title: Text('Bill Date: ${DateFormat('dd MMM yyyy').format(DateTime.fromMillisecondsSinceEpoch(invoice.billDate))}'),
                                  ),
                                  const Divider(height: 1),
                                  ListTile(
                                    leading: const Icon(Icons.edit),
                                    title: const Text('Edit Bill No.'),
                                    onTap: () {
                                      Navigator.pop(context); 
                                      _showEditBillNoDialog(context, invoice, ref);
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.delete, color: Colors.red),
                                    title: const Text('Delete Data', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                    onTap: () async {
                                      Navigator.pop(context); 
                                      await ref.read(invoiceProvider.notifier).deleteInvoice(invoice);
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bill Deleted!')));
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _isNewestFirst = !_isNewestFirst; // Toggle sort order
          });
        },
        backgroundColor: const Color.fromARGB(255, 7, 195, 233), 
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        elevation: 4,
        tooltip: 'Reverse Order',
        child: const Icon(Icons.swap_vert, size: 28),
      ),
    );
  }
}