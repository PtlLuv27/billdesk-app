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

class LedgerTab extends ConsumerStatefulWidget {
  const LedgerTab({super.key});

  @override
  ConsumerState<LedgerTab> createState() => _LedgerTabState();
}

class _LedgerTabState extends ConsumerState<LedgerTab> {
  DateTime? _startDate;
  DateTime? _endDate;
  String _typeFilter = 'Both'; 
  String _taxFilter = 'With GST'; 
  
  String? _selectedPurchaserId; 

  // --- NEW: TRACK SORT ORDER ---
  bool _isNewestFirst = true;

  // --- COMMA FORMATTER (With 2 decimals for Ledger) ---
  String formatAmount(double val) {
    return NumberFormat.currency(locale: 'en_IN', symbol: '', decimalDigits: 2).format(val);
  }

  List<Invoice> _getFilteredInvoices(List<Invoice> allInvoices) {
    return allInvoices.where((invoice) {
      if (_startDate != null && _endDate != null) {
        final billDate = DateTime.fromMillisecondsSinceEpoch(invoice.billDate);
        final start = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
        final end = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
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

  double _calculateNetBalance(List<Invoice> filteredInvoices) {
    double totalSales = 0.0;
    double totalPurchases = 0.0;

    for (var invoice in filteredInvoices) {
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
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
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

  @override
  Widget build(BuildContext context) {
    final allInvoices = ref.watch(invoiceProvider);
    final allPurchasers = ref.watch(purchaserProvider); 
    
    final filteredInvoices = _getFilteredInvoices(allInvoices);
    
    // --- NEW: APPLY DYNAMIC SORTING ---
    final sortedInvoices = List<Invoice>.from(filteredInvoices);
    sortedInvoices.sort((a, b) {
      if (_isNewestFirst) {
        return b.billDate.compareTo(a.billDate); // Newest First
      } else {
        return a.billDate.compareTo(b.billDate); // Oldest First
      }
    });

    final netBalance = _calculateNetBalance(sortedInvoices);

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
                        label: Text(_startDate == null 
                            ? 'Select Date Range' 
                            : '${DateFormat('dd/MM/yy').format(_startDate!)} - ${DateFormat('dd/MM/yy').format(_endDate!)}'),
                        onPressed: _selectDateRange,
                      ),
                    ),
                    if (_startDate != null)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() { _startDate = null; _endDate = null; }),
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

          // --- ANALYTICS DASHBOARD ---
          Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: netBalance >= 0 ? Colors.green.shade50 : Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: netBalance >= 0 ? Colors.green : Colors.red, width: 2),
            ),
            child: Column(
              children: [
                Text(
                  _selectedPurchaserId == null ? 'NET BALANCE' : 'PARTY BALANCE', 
                  style: const TextStyle(letterSpacing: 1.5, fontWeight: FontWeight.bold, color: Colors.black54)
                ),
                const SizedBox(height: 5),
                Text(
                  '₹${formatAmount(netBalance)}',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: netBalance >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                ),
                Text(_taxFilter == 'With GST' ? '(Including Tax)' : '(Sub Total Only)', style: const TextStyle(fontSize: 12)),
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
                        
                        // --- NEW: TITLE SHOWS ONLY BILL NO, SUBTITLE SHOWS PURCHASER & DATE ---
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
                                      await ref.read(invoiceProvider.notifier).deleteInvoice(invoice.id);
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
      
      // --- NEW: INVERT BUTTON FAB ---
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _isNewestFirst = !_isNewestFirst; // Toggle sort order
          });
        },
        backgroundColor: const Color.fromARGB(255, 7, 195, 233), // Colored to match your uploaded image
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        elevation: 4,
        tooltip: 'Reverse Order',
        child: const Icon(Icons.swap_vert, size: 28),
      ),
    );
  }
}