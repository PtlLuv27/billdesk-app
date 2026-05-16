import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart'; 
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../models/purchaser_model.dart';
import '../../../../models/payment_model.dart';
import '../../../../models/invoice_model.dart';
import '../providers/invoice_provider.dart';
import '../providers/payment_provider.dart';
import '../providers/company_provider.dart';
import '../../authentication/providers/auth_provider.dart'; 
import '../../../core/database/sync_engine.dart'; 
import '../providers/purchaser_provider.dart';

class AccountDetailScreen extends ConsumerStatefulWidget {
  final Purchaser purchaser;
  const AccountDetailScreen({super.key, required this.purchaser});

  @override
  ConsumerState<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends ConsumerState<AccountDetailScreen> {
  String _filter = 'Sales'; 
  bool _showFilters = false; // 🔥 Toggles the filter panel visibility
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    // 🔥 Set default date range to the current Financial Year (April 1st to March 31st)
    final now = DateTime.now();
    int startYear = now.month < 4 ? now.year - 1 : now.year;
    _dateRange = DateTimeRange(
      start: DateTime(startYear, 4, 1),
      end: DateTime(startYear + 1, 3, 31, 23, 59, 59),
    );
  }

  String formatIndianCurrency(double val) {
    final formatter = NumberFormat.decimalPattern('en_IN');
    return '₹${formatter.format(val.round())}/-';
  }

  Future<void> _syncData() async {
    await SyncEngine.syncAll();
    ref.invalidate(invoiceProvider);
    ref.invalidate(paymentProvider);
    ref.invalidate(purchaserProvider);
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _dateRange,
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
      setState(() {
        // Adjust the end date to cover the entire last day
        _dateRange = DateTimeRange(
          start: picked.start,
          end: DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59),
        );
      });
    }
  }

  void _showAddPaymentDialog(bool isReceiving) {
    final amtCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now(); 

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(isReceiving ? 'Record Payment Received (Credit)' : 'Record Payment Made (Credit)', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(controller: amtCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (₹)', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Notes (e.g. Cash, Cheque No.)', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              
              InkWell(
                onTap: () async {
                  final pickedDate = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                  if (pickedDate != null) {
                    final pickedTime = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(selectedDate));
                    if (pickedTime != null) {
                      setModalState(() {
                        selectedDate = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
                      });
                    }
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Date & Time', border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_month)),
                  child: Text(DateFormat('dd MMM yyyy, hh:mm a').format(selectedDate)),
                ),
              ),
              const SizedBox(height: 16),
              
              ElevatedButton(
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: isReceiving ? Colors.green : Colors.orange),
                onPressed: () async {
                  if (amtCtrl.text.isEmpty) return;
                  
                  final currentUserId = ref.read(authProvider);
                  if (currentUserId == null) return;

                  final company = ref.read(activeCompanyProvider);
                  if (company == null) return; 

                  final payment = Payment(
                    id: const Uuid().v4(), 
                    userId: currentUserId, 
                    companyId: company.id, 
                    purchaserId: widget.purchaser.id,
                    amount: double.parse(amtCtrl.text), 
                    date: selectedDate.millisecondsSinceEpoch, 
                    type: isReceiving ? 'received' : 'paid', 
                    notes: noteCtrl.text,
                  );
                  await ref.read(paymentProvider.notifier).addPayment(payment);
                  if (mounted) Navigator.pop(context);
                },
                child: const Text('Save Payment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddDebitDialog(bool isSalesMode) {
    final amtCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now(); 

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Record Manual Debit (Bill/Charge)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(controller: amtCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Total Amount (₹)', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Bill No. / Description', border: OutlineInputBorder())),
              const SizedBox(height: 10),

              InkWell(
                onTap: () async {
                  final pickedDate = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                  if (pickedDate != null) {
                    final pickedTime = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(selectedDate));
                    if (pickedTime != null) {
                      setModalState(() {
                        selectedDate = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
                      });
                    }
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Date & Time', border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_month)),
                  child: Text(DateFormat('dd MMM yyyy, hh:mm a').format(selectedDate)),
                ),
              ),
              const SizedBox(height: 16),

              ElevatedButton(
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.blueAccent),
                onPressed: () async {
                  if (amtCtrl.text.isEmpty) return;
                  
                  final currentUserId = ref.read(authProvider);
                  if (currentUserId == null) return;

                  final company = ref.read(activeCompanyProvider);
                  if (company == null) return; 

                  // 🔥 Reverse GST Calculation Math
                  final totalAmt = double.parse(amtCtrl.text);
                  final p = widget.purchaser;
                  
                  final totalGstPercentage = p.cgstRate + p.sgstRate + p.igstRate;
                  final calculatedSubTotal = totalAmt / (1 + (totalGstPercentage / 100));
                  
                  final sgstAmt = calculatedSubTotal * (p.sgstRate / 100);
                  final cgstAmt = calculatedSubTotal * (p.cgstRate / 100);
                  final igstAmt = calculatedSubTotal * (p.igstRate / 100);
                  final totalGstAmt = sgstAmt + cgstAmt + igstAmt;

                  final invoice = Invoice(
                    id: const Uuid().v4(),
                    userId: currentUserId,
                    companyId: company.id,
                    type: isSalesMode ? 'sales' : 'purchase',
                    purchaserId: widget.purchaser.id,
                    billNo: noteCtrl.text.isEmpty ? 'MANUAL' : noteCtrl.text,
                    billDate: selectedDate.millisecondsSinceEpoch, 
                    truckNo: '', driverName: '', licNo: '', 
                    nos: 1, unit: 'NA', quantity: 1, 
                    rate: calculatedSubTotal, // Rate = SubTotal
                    amount: calculatedSubTotal, // Amount = SubTotal
                    labourCharge: 0, 
                    subTotal: calculatedSubTotal, 
                    gstAmount: totalGstAmt, 
                    totalAmount: totalAmt, 
                    lastUpdated: DateTime.now().millisecondsSinceEpoch,
                    isDeleted: 0,
                  );  
                  
                  await ref.read(invoiceProvider.notifier).addInvoice(invoice);
                  if (mounted) Navigator.pop(context);
                },
                child: const Text('Save Debit Entry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editAmount(double currentAmount, Function(double) onSave) async {
    final ctrl = TextEditingController(text: currentAmount.toStringAsFixed(0));
    await showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Amount'),
        content: TextField(controller: ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(border: OutlineInputBorder(), prefixText: '₹ ')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
            onPressed: () {
              final val = double.tryParse(ctrl.text);
              if (val != null) onSave(val);
              Navigator.pop(ctx);
            }, 
            child: const Text('Save')
          )
        ]
      )
    );
  }

  Future<void> _editDateTime(int currentTimestamp, Function(int) onSave) async {
    final currentDt = DateTime.fromMillisecondsSinceEpoch(currentTimestamp);
    
    final pickedDate = await showDatePicker(context: context, initialDate: currentDt, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(currentDt));
      if (pickedTime != null) {
        final finalDt = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
        onSave(finalDt.millisecondsSinceEpoch);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Fetch raw data
    final allInvoices = ref.watch(invoiceProvider).where((i) => i.purchaserId == widget.purchaser.id).toList();
    final allPayments = ref.watch(paymentProvider).where((p) => p.purchaserId == widget.purchaser.id).toList();

    // 2. Filter by selected Dates
    final dateFilteredInvoices = allInvoices.where((i) {
      if (_dateRange == null) return true;
      final dt = DateTime.fromMillisecondsSinceEpoch(i.billDate);
      return dt.isAfter(_dateRange!.start) && dt.isBefore(_dateRange!.end);
    }).toList();

    final dateFilteredPayments = allPayments.where((p) {
      if (_dateRange == null) return true;
      final dt = DateTime.fromMillisecondsSinceEpoch(p.date);
      return dt.isAfter(_dateRange!.start) && dt.isBefore(_dateRange!.end);
    }).toList();

    final isSalesMode = _filter == 'Sales';
    
    // 3. Filter by Transaction Type (Sales vs Purchases)
    final relevantInvoices = dateFilteredInvoices.where((i) => i.type == (isSalesMode ? 'sales' : 'purchase')).toList();
    final relevantPayments = dateFilteredPayments.where((p) => p.type == (isSalesMode ? 'received' : 'paid')).toList();

    relevantInvoices.sort((a, b) => b.billDate.compareTo(a.billDate));
    relevantPayments.sort((a, b) => b.date.compareTo(a.date));

    final totalBilled = relevantInvoices.fold(0.0, (sum, i) => sum + i.totalAmount);
    final totalPaid = relevantPayments.fold(0.0, (sum, p) => sum + p.amount);
    final outstanding = totalBilled - totalPaid;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(widget.purchaser.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          // 🔥 NEW: Filter Toggle Button
          IconButton(
            icon: Icon(_showFilters ? Icons.filter_list_off : Icons.filter_list),
            color: _showFilters ? Colors.blueAccent : Colors.black87,
            onPressed: () {
              setState(() {
                _showFilters = !_showFilters;
              });
            },
          )
        ],
      ),
      body: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse, 
            PointerDeviceKind.trackpad,
          },
        ),
        child: RefreshIndicator(
          onRefresh: _syncData,
          color: Colors.blueAccent,
          backgroundColor: Colors.white,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(), 
            children: [
              // 🔥 NEW: Expandable Filter Section
              if (_showFilters)
                Container(
                  color: Colors.blue.shade50,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_month, size: 20),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _dateRange == null 
                                ? 'Select Date Range' 
                                : '${DateFormat('dd MMM yy').format(_dateRange!.start)}  -  ${DateFormat('dd MMM yy').format(_dateRange!.end)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.blueAccent,
                            side: BorderSide(color: Colors.blueAccent.shade200, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _selectDateRange,
                        ),
                      ),
                      if (_dateRange != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.redAccent),
                          style: IconButton.styleFrom(backgroundColor: Colors.red.shade50),
                          tooltip: 'Clear Dates',
                          onPressed: () => setState(() => _dateRange = null),
                        )
                      ]
                    ],
                  ),
                ),

              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Sales', label: Text('Sales (They Owe)')),
                    ButtonSegment(value: 'Purchases', label: Text('Purchases (We Owe)')),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (val) => setState(() => _filter = val.first),
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: Colors.blue.shade50,
                    selectedForegroundColor: Colors.blueAccent,
                  ),
                ),
              ),
              
              Container(
                color: Colors.white,
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                child: Row(
                  children: [
                    Expanded(child: _statCard('Total Billed', totalBilled, Colors.blue)),
                    const SizedBox(width: 8),
                    Expanded(child: _statCard(isSalesMode ? 'Total Received' : 'Total Paid', totalPaid, isSalesMode ? Colors.green : Colors.orange)),
                    const SizedBox(width: 8),
                    Expanded(child: _statCard('Pending', outstanding, outstanding > 0 ? Colors.red : Colors.grey.shade600)),
                  ],
                ),
              ),
              
              Container(
                color: Colors.grey.shade200,
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        isSalesMode ? 'CREDIT (Received)' : 'CREDIT (Paid)', 
                        textAlign: TextAlign.center, 
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isSalesMode ? Colors.green.shade700 : Colors.orange.shade700, letterSpacing: 0.5)
                      )
                    ),
                    Container(width: 1.5, height: 20, color: Colors.grey.shade400),
                    const Expanded(
                      child: Text(
                        'DEBIT (Bills/Invoices)', 
                        textAlign: TextAlign.center, 
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueAccent, letterSpacing: 0.5)
                      )
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1),

              IntrinsicHeight( 
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch, 
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            right: BorderSide(color: Colors.grey.shade400, width: 1.5) 
                          )
                        ),
                        child: relevantPayments.isEmpty 
                          ? const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('No payments.', style: TextStyle(color: Colors.grey, fontSize: 12))))
                          : Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Column(
                                children: relevantPayments.map((p) => _buildPaymentTile(p, isSalesMode)).toList(),
                              ),
                            ),
                      ),
                    ),
                    
                    Expanded(
                      child: relevantInvoices.isEmpty
                        ? const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('No bills.', style: TextStyle(color: Colors.grey, fontSize: 12))))
                        : Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              children: relevantInvoices.map((i) => _buildInvoiceTile(i)).toList(),
                            ),
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 100), 
            ],
          ),
        ),
      ),
      
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            FloatingActionButton.extended(
              heroTag: 'btnLeft',
              onPressed: () => _showAddPaymentDialog(isSalesMode),
              icon: const Icon(Icons.arrow_downward),
              label: const Text('Add Credit', style: TextStyle(fontWeight: FontWeight.bold)),
              backgroundColor: isSalesMode ? Colors.green : Colors.orange,
              foregroundColor: Colors.white,
              elevation: 4,
            ),
            FloatingActionButton.extended(
              heroTag: 'btnRight',
              onPressed: () => _showAddDebitDialog(isSalesMode),
              icon: const Icon(Icons.arrow_upward),
              label: const Text('Add Debit', style: TextStyle(fontWeight: FontWeight.bold)),
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              elevation: 4,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String title, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05), 
        borderRadius: BorderRadius.circular(12), 
        border: Border.all(color: color.withOpacity(0.3))
      ),
      child: Column(
        children: [
          Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
          const SizedBox(height: 6),
          Text(formatIndianCurrency(amount), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  Widget _buildPaymentTile(Payment p, bool isSalesMode) {
    final color = isSalesMode ? Colors.green : Colors.orange;
    return InkWell(
      onLongPress: () {
        showModalBottomSheet(
          context: context,
          builder: (ctx) => SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.edit, color: Colors.blue),
                  title: const Text('Edit Amount'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _editAmount(p.amount, (newAmt) {
                      final updated = Payment(id: p.id, userId: p.userId, companyId: p.companyId, purchaserId: p.purchaserId, amount: newAmt, date: p.date, type: p.type, notes: p.notes);
                      ref.read(paymentProvider.notifier).addPayment(updated); 
                    });
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.calendar_month, color: Colors.blue),
                  title: const Text('Edit Date & Time'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _editDateTime(p.date, (newDate) {
                      final updated = Payment(id: p.id, userId: p.userId, companyId: p.companyId, purchaserId: p.purchaserId, amount: p.amount, date: newDate, type: p.type, notes: p.notes);
                      ref.read(paymentProvider.notifier).addPayment(updated);
                    });
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Delete Transaction', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  onTap: () {
                    ref.read(paymentProvider.notifier).deletePayment(p.id);
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10, left: 8, right: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.payments_rounded, size: 14, color: color),
                const SizedBox(width: 4),
                Text('Credit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: color)),
              ],
            ),
            const SizedBox(height: 6),
            Text('+ ${formatIndianCurrency(p.amount)}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: color)),
            const SizedBox(height: 6),
            Text(DateFormat('dd MMM yyyy\nhh:mm a').format(DateTime.fromMillisecondsSinceEpoch(p.date)), style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
            if (p.notes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                child: Text('Note: ${p.notes}', style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.grey.shade800)),
              )
            ]
          ]
        )
      )
    );
  }

  Widget _buildInvoiceTile(Invoice i) {
    return InkWell(
      onLongPress: () {
        showModalBottomSheet(
          context: context,
          builder: (ctx) => SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.edit, color: Colors.blue),
                  title: const Text('Edit Amount'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _editAmount(i.totalAmount, (newAmt) {
                      final updated = Invoice(
                        id: i.id, userId: i.userId, companyId: i.companyId, type: i.type, purchaserId: i.purchaserId, billNo: i.billNo, billDate: i.billDate, truckNo: i.truckNo, driverName: i.driverName, licNo: i.licNo, nos: i.nos, unit: i.unit, quantity: i.quantity, rate: i.rate, 
                        amount: newAmt, labourCharge: i.labourCharge, subTotal: newAmt, gstAmount: 0, totalAmount: newAmt,
                        lastUpdated: DateTime.now().millisecondsSinceEpoch, isDeleted: i.isDeleted
                      );
                      ref.read(invoiceProvider.notifier).updateInvoice(updated);
                    });
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.calendar_month, color: Colors.blue),
                  title: const Text('Edit Date & Time'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _editDateTime(i.billDate, (newDate) {
                      final updated = Invoice(
                        id: i.id, userId: i.userId, companyId: i.companyId, type: i.type, purchaserId: i.purchaserId, billNo: i.billNo, billDate: newDate, truckNo: i.truckNo, driverName: i.driverName, licNo: i.licNo, nos: i.nos, unit: i.unit, quantity: i.quantity, rate: i.rate, amount: i.amount, labourCharge: i.labourCharge, subTotal: i.subTotal, gstAmount: i.gstAmount, totalAmount: i.totalAmount, lastUpdated: DateTime.now().millisecondsSinceEpoch, isDeleted: i.isDeleted
                      );
                      ref.read(invoiceProvider.notifier).updateInvoice(updated);
                    });
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Delete Transaction', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  onTap: () {
                    ref.read(invoiceProvider.notifier).deleteInvoice(i); 
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10, left: 4, right: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.withOpacity(0.2)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long_rounded, size: 14, color: Colors.blueAccent),
                const SizedBox(width: 4),
                Expanded(child: Text('Bill #${i.billNo}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blueAccent), overflow: TextOverflow.ellipsis)),
              ],
            ),
            const SizedBox(height: 6),
            Text(formatIndianCurrency(i.totalAmount), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.black87)),
            const SizedBox(height: 6),
            Text(DateFormat('dd MMM yyyy\nhh:mm a').format(DateTime.fromMillisecondsSinceEpoch(i.billDate)), style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          ]
        )
      )
    );
  }
}