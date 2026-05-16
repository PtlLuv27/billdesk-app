import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/invoice_model.dart';
// import '../../../models/company_model.dart';
import '../../../models/purchaser_model.dart';
import '../providers/invoice_provider.dart';
import '../providers/company_provider.dart';
import '../providers/purchaser_provider.dart';
import '../views/editable_invoice_screen.dart';
import '../views/editable_purchase_screen.dart';

class GstDetailScreen extends ConsumerStatefulWidget {
  final String gstType; 
  final DateTimeRange? dateRange;
  final String initialTypeFilter; 

  const GstDetailScreen({
    super.key,
    required this.gstType,
    required this.dateRange,
    required this.initialTypeFilter,
  });

  @override
  ConsumerState<GstDetailScreen> createState() => _GstDetailScreenState();
}

class _GstDetailScreenState extends ConsumerState<GstDetailScreen> {
  late String _typeFilter;
  String? _selectedPurchaserId;

  @override
  void initState() {
    super.initState();
    _typeFilter = widget.initialTypeFilter; 
  }

  String formatAmount(double val) {
    return NumberFormat.currency(locale: 'en_IN', symbol: '', decimalDigits: 2).format(val);
  }

  double _getInvoiceSpecificGst(Invoice invoice, Purchaser purchaser) {
    double sgstAmt = (invoice.subTotal * purchaser.sgstRate / 100).roundToDouble();
    double cgstAmt = (invoice.subTotal * purchaser.cgstRate / 100).roundToDouble();
    double igstAmt = (invoice.subTotal * purchaser.igstRate / 100).roundToDouble();

    double amt = 0.0;
    if (widget.gstType == 'SGST') amt = sgstAmt;
    else if (widget.gstType == 'CGST') amt = cgstAmt;
    else if (widget.gstType == 'IGST') amt = igstAmt;
    else amt = sgstAmt + cgstAmt + igstAmt; 

    return invoice.type == 'sales' ? amt : -amt;
  }

  Widget _buildHeaderCard(double balance, String? purchaserName) {
    final isPositive = balance >= 0;
    final Color primaryColor = isPositive ? const Color(0xFF2E7D32) : Colors.red.shade700;
    final Color bgColor = isPositive ? const Color(0xFFE8F5E9) : Colors.red.shade50;
    final Color borderColor = isPositive ? const Color(0xFFA5D6A7) : Colors.red.shade200;

    String titlePrefix = widget.gstType == 'TOTAL' ? 'TOTAL NET GST' : 'NET ${widget.gstType}';
    String suffix = purchaserName == null ? '(ALL PARTIES)' : '(${purchaserName.toUpperCase()})';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
            '$titlePrefix $suffix',
            style: TextStyle(color: Colors.blueGrey.shade700, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.0),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '₹${formatAmount(balance.abs())}',
              style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: primaryColor, height: 1.1),
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

    String? selectedPurchaserName;
    if (_selectedPurchaserId != null) {
      final p = allPurchasers.where((e) => e.id == _selectedPurchaserId).firstOrNull;
      selectedPurchaserName = p?.name;
    }

    var filteredInvoices = allInvoices.where((invoice) {
      // 🔥 REMOVED the line that was hiding 'MANUAL' entries!

      if (widget.dateRange != null) {
        final billDate = DateTime.fromMillisecondsSinceEpoch(invoice.billDate);
        final start = DateTime(widget.dateRange!.start.year, widget.dateRange!.start.month, widget.dateRange!.start.day);
        final end = DateTime(widget.dateRange!.end.year, widget.dateRange!.end.month, widget.dateRange!.end.day, 23, 59, 59);
        if (billDate.isBefore(start) || billDate.isAfter(end)) return false;
      }

      if (_typeFilter == 'Sales Only' && invoice.type != 'sales') return false;
      if (_typeFilter == 'Purchase Only' && invoice.type != 'purchase') return false;

      if (_selectedPurchaserId != null && invoice.purchaserId != _selectedPurchaserId) return false;

      final purchaser = allPurchasers.firstWhere(
        (p) => p.id == invoice.purchaserId,
        orElse: () => Purchaser(id: '', userId: '', name: 'Unknown', address1: '', address2: '', particulars: '', gstin: '', hsnNo: '', sgstRate: 0, cgstRate: 0, igstRate: 0, lastUpdated: 0)
      );
      final amt = _getInvoiceSpecificGst(invoice, purchaser);
      if (amt == 0) return false; 

      return true;
    }).toList();

    filteredInvoices.sort((a, b) => b.billDate.compareTo(a.billDate));

    double totalGstForCard = 0.0;
    for (var inv in filteredInvoices) {
      final purchaser = allPurchasers.firstWhere(
        (p) => p.id == inv.purchaserId,
        orElse: () => Purchaser(id: '', userId: '', name: 'Unknown', address1: '', address2: '', particulars: '', gstin: '', hsnNo: '', sgstRate: 0, cgstRate: 0, igstRate: 0, lastUpdated: 0)
      );
      totalGstForCard += _getInvoiceSpecificGst(inv, purchaser);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('${widget.gstType == 'TOTAL' ? 'Total Net' : widget.gstType} Details'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildHeaderCard(totalGstForCard, selectedPurchaserName),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Type',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    value: _typeFilter,
                    isExpanded: true,
                    items: ['Both', 'Sales Only', 'Purchase Only'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))).toList(),
                    onChanged: (val) => setState(() => _typeFilter = val!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    decoration: InputDecoration(
                      labelText: 'Party',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    value: _selectedPurchaserId,
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Parties', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                      ...allPurchasers.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name, style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis))),
                    ],
                    onChanged: (val) => setState(() => _selectedPurchaserId = val),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          const Divider(height: 1, thickness: 1),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${widget.gstType} Amount',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.indigo, letterSpacing: 1.0),
              ),
            ),
          ),

          Expanded(
            child: filteredInvoices.isEmpty
              ? const Center(child: Text('No transactions match these filters.', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  itemCount: filteredInvoices.length,
                  separatorBuilder: (context, index) => const Divider(height: 16),
                  itemBuilder: (context, index) {
                    final invoice = filteredInvoices[index];
                    final isSale = invoice.type == 'sales';
                    
                    // 🔥 UI Fix: Detect manual entries
                    final bool isManual = invoice.billNo.trim().toUpperCase() == 'MANUAL' || invoice.billNo.trim().isEmpty;
                    final String displayBillName = isManual ? 'Manual Entry' : 'Bill #${invoice.billNo}';
                    
                    final purchaser = allPurchasers.firstWhere(
                      (p) => p.id == invoice.purchaserId,
                      orElse: () => Purchaser(id: '', userId: '', name: 'Unknown Party', address1: '', address2: '', particulars: '', gstin: '', hsnNo: '', sgstRate: 0, cgstRate: 0, igstRate: 0, lastUpdated: 0)
                    );

                    final specificGstAmt = _getInvoiceSpecificGst(invoice, purchaser);

                    return InkWell(
                      onTap: () {
                        final company = ref.read(activeCompanyProvider);
                        if (isSale) {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => InvoicePreviewScreen(invoice: invoice, company: company!, purchaser: purchaser)));
                        } else {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => EditablePurchaseScreen(invoice: invoice, company: company!, purchaser: purchaser)));
                        }
                      },
                      child: Row(
                        children: [
                          Container(
                            height: 44, width: 44,
                            decoration: BoxDecoration(color: isSale ? Colors.blue.shade50 : Colors.red.shade50, shape: BoxShape.circle),
                            child: Icon(isSale ? Icons.arrow_upward : Icons.arrow_downward, color: isSale ? Colors.blue : Colors.red, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(displayBillName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                const SizedBox(height: 2),
                                Text(purchaser.name, style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 2),
                                Text(DateFormat('dd MMM yyyy').format(DateTime.fromMillisecondsSinceEpoch(invoice.billDate)), style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                              ],
                            ),
                          ),
                          Text(
                            '₹${formatAmount(specificGstAmt.abs())}',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: specificGstAmt >= 0 ? Colors.green.shade700 : Colors.red.shade700),
                          ),
                        ],
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}