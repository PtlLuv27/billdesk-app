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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.blueAccent,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      ref.read(ledgerDateRangeProvider.notifier).setDateRange(picked);
    }
  }

  void _showEditBillNoDialog(BuildContext context, Invoice invoice, WidgetRef ref) {
    final editCtrl = TextEditingController(text: invoice.billNo);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Bill Name/No.', style: TextStyle(fontWeight: FontWeight.bold)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: TextField(
          controller: editCtrl,
          decoration: InputDecoration(
            labelText: 'New Bill No.', 
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
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

  // --- REBUILT NET BALANCE CARD (Matches Screenshot exactly) ---
  Widget _buildNetBalanceCard(double balance) {
    final isPositive = balance >= 0;
    // Using the clean green styling from the image
    final Color primaryColor = isPositive ? const Color(0xFF2E7D32) : Colors.red.shade700;
    final Color bgColor = isPositive ? const Color(0xFFE8F5E9) : Colors.red.shade50;
    final Color borderColor = isPositive ? const Color(0xFFA5D6A7) : Colors.red.shade200;
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _selectedPurchaserId == null ? 'NET BALANCE' : 'PARTY BALANCE',
            style: TextStyle(
              color: Colors.blueGrey.shade600, 
              fontSize: 13, 
              fontWeight: FontWeight.w800, 
              letterSpacing: 1.5
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '₹${formatAmount(balance.abs())}',
              style: TextStyle(
                fontSize: 36, 
                fontWeight: FontWeight.w900, 
                color: primaryColor, 
                height: 1.1
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _taxFilter == 'With GST' ? '(Including Tax)' : '(Sub Total Only)',
            style: TextStyle(
              color: Colors.blueGrey.shade600, 
              fontSize: 13, 
              fontWeight: FontWeight.w500
            ),
          ),
        ],
      ),
    );
  }

  // Adjusted filter decoration to match the flat UI in the screenshot
  InputDecoration _filterDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      floatingLabelBehavior: FloatingLabelBehavior.always, // Labels sit on top of the border
      labelStyle: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600, fontSize: 14),
      prefixIcon: icon != null ? Icon(icon, color: Colors.blueGrey.shade700, size: 20) : null,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allInvoices = ref.watch(invoiceProvider);
    final allPurchasers = ref.watch(purchaserProvider); 
    
    final dateRange = ref.watch(ledgerDateRangeProvider);
    
    final allFilteredInvoices = _getFilteredInvoices(allInvoices, dateRange);
    final displayInvoices = allFilteredInvoices.where((i) => i.billNo.trim().toUpperCase() != 'MANUAL').toList();
    final netBalance = _calculateNetBalance(allFilteredInvoices);

    final sortedInvoices = List<Invoice>.from(displayInvoices);
    sortedInvoices.sort((a, b) {
      if (_isNewestFirst) {
        return b.billDate.compareTo(a.billDate); 
      } else {
        return a.billDate.compareTo(b.billDate); 
      }
    });

    return Scaffold(
      backgroundColor: Colors.white, // Setting to white to match screenshot
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                // --- FILTER SECTION ---
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.calendar_month, size: 20),
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  dateRange == null 
                                    ? 'Select Date Range' 
                                    : '${DateFormat('dd MMM yy').format(dateRange.start)}  -  ${DateFormat('dd MMM yy').format(dateRange.end)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.blueAccent,
                                side: BorderSide(color: Colors.blueAccent.shade100, width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), // Rounded button
                              ),
                              onPressed: _selectDateRange,
                            ),
                          ),
                          if (dateRange != null) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: Colors.redAccent),
                              style: IconButton.styleFrom(backgroundColor: Colors.red.shade50),
                              tooltip: 'Clear Dates',
                              onPressed: () => ref.read(ledgerDateRangeProvider.notifier).setDateRange(null),
                            )
                          ]
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              decoration: _filterDecoration('Transaction Type'),
                              initialValue: _typeFilter,
                              isExpanded: true, 
                              icon: const Icon(Icons.arrow_drop_down, color: Colors.black54),
                              items: ['Both', 'Sales Only', 'Purchase Only'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)))).toList(),
                              onChanged: (val) => setState(() => _typeFilter = val!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              decoration: _filterDecoration('Tax Setting'),
                              initialValue: _taxFilter,
                              isExpanded: true, 
                              icon: const Icon(Icons.arrow_drop_down, color: Colors.black54),
                              items: ['With GST', 'Without GST'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)))).toList(),
                              onChanged: (val) => setState(() => _taxFilter = val!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String?>(
                        decoration: _filterDecoration('Filter by Party / Purchaser', icon: Icons.person_search),
                        initialValue: _selectedPurchaserId,
                        isExpanded: true, 
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.black54),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All Parties', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent))),
                          ...allPurchasers.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)))),
                        ],
                        onChanged: (val) => setState(() => _selectedPurchaserId = val),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // --- NEW FLAT NET BALANCE CARD ---
                _buildNetBalanceCard(netBalance),
                
                const SizedBox(height: 8),
              ],
            ),
          ),

          // --- BILLS ARCHIVE LIST ---
          sortedInvoices.isEmpty
            ? SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text('No transactions found.', style: TextStyle(color: Colors.grey.shade600, fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              )
            : SliverPadding(
                padding: const EdgeInsets.only(bottom: 100), // Only bottom padding, no side margins
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final invoice = sortedInvoices[index];
                      final isSale = invoice.type == 'sales';
                      
                      final purchaser = allPurchasers.firstWhere(
                        (p) => p.id == invoice.purchaserId, 
                        orElse: () => Purchaser(id: '', userId: '', name: 'Unknown Party', address1: '', address2: '', particulars: '', gstin: '', hsnNo: '', sgstRate: 0, cgstRate: 0, igstRate: 0, lastUpdated: 0)
                      );
                      
                      // Using InkWell directly without a Card container to match the flat screenshot look
                      return InkWell(
                        onTap: () {
                          final company = ref.read(activeCompanyProvider);
                          if (isSale) {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => EditableInvoiceScreen(invoice: invoice, company: company!, purchaser: purchaser)));
                          } else {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => EditablePurchaseScreen(invoice: invoice, company: company!, purchaser: purchaser)));
                          }
                        },
                        onLongPress: () {
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.white,
                            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                            builder: (context) => SafeArea(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                                    const SizedBox(height: 16),
                                    ListTile(
                                      leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle), child: const Icon(Icons.calendar_month, color: Colors.blueAccent)),
                                      title: Text('Bill Date: ${DateFormat('dd MMM yyyy').format(DateTime.fromMillisecondsSinceEpoch(invoice.billDate))}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                    ListTile(
                                      leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle), child: const Icon(Icons.edit, color: Colors.orange)),
                                      title: const Text('Edit Bill Name/No.', style: TextStyle(fontWeight: FontWeight.bold)),
                                      onTap: () {
                                        Navigator.pop(context); 
                                        _showEditBillNoDialog(context, invoice, ref);
                                      },
                                    ),
                                    ListTile(
                                      leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle), child: const Icon(Icons.delete, color: Colors.red)),
                                      title: const Text('Delete Transaction', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                      onTap: () async {
                                        Navigator.pop(context); 
                                        await ref.read(invoiceProvider.notifier).deleteInvoice(invoice);
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transaction Deleted'), backgroundColor: Colors.redAccent));
                                        }
                                      },
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start, // Align to top
                            children: [
                              // --- CIRCULAR ICON ---
                              Container(
                                height: 48,
                                width: 48,
                                decoration: BoxDecoration(
                                  color: isSale ? Colors.blue.shade50 : Colors.red.shade50,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isSale ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                  color: isSale ? Colors.blue : Colors.red,
                                ),
                              ),
                              const SizedBox(width: 16),
                              
                              // --- BILL NO, NAME, DATE ---
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Bill #${invoice.billNo}', 
                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.black),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      purchaser.name, 
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      DateFormat('dd MMM yyyy').format(DateTime.fromMillisecondsSinceEpoch(invoice.billDate)), 
                                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              
                              // --- AMOUNT TEXT ---
                              Text(
                                '₹${formatAmount(_taxFilter == 'With GST' ? invoice.totalAmount : invoice.subTotal)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold, 
                                  fontSize: 16, 
                                  color: isSale ? const Color(0xFF2E7D32) : Colors.red.shade700 // Matching the exact green
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: sortedInvoices.length,
                  ),
                ),
              ),
        ],
      ),
      
      // Cyan FAB
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _isNewestFirst = !_isNewestFirst; 
          });
        },
        backgroundColor: const Color(0xFF00BCD4), 
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        elevation: 4,
        tooltip: 'Reverse Order',
        child: const Icon(Icons.swap_vert, size: 28),
      ),
    );
  }
}