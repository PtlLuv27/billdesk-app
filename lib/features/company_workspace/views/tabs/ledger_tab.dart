import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../models/invoice_model.dart';
import '../../../../models/purchaser_model.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/company_provider.dart';
import '../../providers/purchaser_provider.dart';
import '../editable_invoice_screen.dart';
import '../editable_purchase_screen.dart'; // <-- Added import for Purchase Screen


class LedgerTab extends ConsumerStatefulWidget {
  const LedgerTab({super.key});

  @override
  ConsumerState<LedgerTab> createState() => _LedgerTabState();
}

class _LedgerTabState extends ConsumerState<LedgerTab> {
  DateTime? _startDate;
  DateTime? _endDate;
  String _typeFilter = 'Both'; // Both, Sales Only, Purchase Only
  String _taxFilter = 'With GST'; // With GST, Without GST
  
  // --- NEW: PURCHASER FILTER STATE ---
  String? _selectedPurchaserId; // null means 'All Parties'

  // --- ANALYTICS ENGINE ---
  List<Invoice> _getFilteredInvoices(List<Invoice> allInvoices) {
    return allInvoices.where((invoice) {
      // 1. Date Filter
      if (_startDate != null && _endDate != null) {
        final billDate = DateTime.fromMillisecondsSinceEpoch(invoice.billDate);
        // Normalize dates to ignore times
        final start = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
        final end = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
        if (billDate.isBefore(start) || billDate.isAfter(end)) return false;
      }
      
      // 2. Type Filter
      if (_typeFilter == 'Sales Only' && invoice.type != 'sales') return false;
      if (_typeFilter == 'Purchase Only' && invoice.type != 'purchase') return false;
      
      // 3. Purchaser / Party Filter
      if (_selectedPurchaserId != null && invoice.purchaserId != _selectedPurchaserId) {
        return false; // Hide this bill if it doesn't belong to the selected party
      }
      
      return true;
    }).toList();
  }

  double _calculateNetBalance(List<Invoice> filteredInvoices) {
    double totalSales = 0.0;
    double totalPurchases = 0.0;

    for (var invoice in filteredInvoices) {
      // Choose which column to pull based on Tax Filter
      double amountToAdd = _taxFilter == 'With GST' ? invoice.totalAmount : invoice.subTotal;

      if (invoice.type == 'sales') {
        totalSales += amountToAdd;
      } else if (invoice.type == 'purchase') {
        totalPurchases += amountToAdd;
      }
    }

    return totalSales - totalPurchases;
  }

  // --- UI HELPERS ---
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

  // --- EDIT BILL NO DIALOG ---
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
                // Re-build invoice with the new Bill No
                final updatedInvoice = Invoice(
                  id: invoice.id, companyId: invoice.companyId, type: invoice.type,
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
    // 1. Watch the live database
    final allInvoices = ref.watch(invoiceProvider);
    final allPurchasers = ref.watch(purchaserProvider); // Watch purchasers for the dropdown
    
    // 2. Apply filters
    final filteredInvoices = _getFilteredInvoices(allInvoices);
    
    // 3. Calculate Math
    final netBalance = _calculateNetBalance(filteredInvoices);

    return Scaffold(
      body: Column(
        children: [
          // --- FILTER CONTROLS ---
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey.shade100,
            child: Column(
              children: [
                // Date Filter Row
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
                
                // Type & Tax Filter Row
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
                
                // PURCHASER FILTER DROPDOWN
                DropdownButtonFormField<String?>(
                  decoration: const InputDecoration(
                    labelText: 'Filter by Party / Purchaser', 
                    isDense: true, 
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_search),
                  ),
                  value: _selectedPurchaserId,
                  isExpanded: true, // Prevents overflow if names are long
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
                  '₹${netBalance.toStringAsFixed(2)}',
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
            child: filteredInvoices.isEmpty
                ? const Center(child: Text('No transactions found for these filters.'))
                : ListView.builder(
                    itemCount: filteredInvoices.length,
                    itemBuilder: (context, index) {
                      final invoice = filteredInvoices[index];
                      final isSale = invoice.type == 'sales';
                      
                      // Find the purchaser name to display in the list securely
                      final purchaser = allPurchasers.firstWhere(
                        (p) => p.id == invoice.purchaserId, 
                        orElse: () => Purchaser(id: '', name: 'Unknown', address1: '', address2: '', particulars: '', gstin: '', hsnNo: '', sgstRate: 0, cgstRate: 0, igstRate: 0, lastUpdated: 0)
                      );
                      
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isSale ? Colors.blue.shade100 : Colors.red.shade100,
                          child: Icon(
                            isSale ? Icons.arrow_upward : Icons.arrow_downward,
                            color: isSale ? Colors.blue : Colors.red,
                          ),
                        ),
                        title: Text('Bill #${invoice.billNo} - ${purchaser.name}'),
                        subtitle: Text(DateFormat('dd MMM yyyy').format(DateTime.fromMillisecondsSinceEpoch(invoice.billDate))),
                        trailing: Text(
                          '₹${(_taxFilter == 'With GST' ? invoice.totalAmount : invoice.subTotal).toStringAsFixed(2)}',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isSale ? Colors.green : Colors.red),
                        ),
                        // --- ON TAP (Dynamic Routing) ---
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
                        // --- ON LONG PRESS (Quick Actions) ---
                        onLongPress: () {
                          showModalBottomSheet(
                            context: context,
                            builder: (context) => SafeArea(
                              child: Wrap(
                                children: [
                                  // 1. Display Date
                                  ListTile(
                                    leading: const Icon(Icons.calendar_month, color: Colors.blue),
                                    title: Text('Bill Date: ${DateFormat('dd MMM yyyy').format(DateTime.fromMillisecondsSinceEpoch(invoice.billDate))}'),
                                  ),
                                  const Divider(height: 1),
                                  // 2. Edit Name / Bill No
                                  ListTile(
                                    leading: const Icon(Icons.edit),
                                    title: const Text('Edit Bill No.'),
                                    onTap: () {
                                      Navigator.pop(context); // Close bottom sheet
                                      _showEditBillNoDialog(context, invoice, ref);
                                    },
                                  ),
                                  // 3. Delete Data
                                  ListTile(
                                    leading: const Icon(Icons.delete, color: Colors.red),
                                    title: const Text('Delete Data', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                    onTap: () async {
                                      Navigator.pop(context); // Close bottom sheet
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
    );
  }
}