import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart'; 
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart'; 
import '../../../../models/invoice_model.dart';
import '../../../../models/purchaser_model.dart';
import '../../providers/company_provider.dart';
import '../../providers/purchaser_provider.dart';
import '../../providers/invoice_provider.dart';
import '../editable_purchase_screen.dart';
import '../../../authentication/providers/auth_provider.dart'; 
import '../../../../core/database/sync_engine.dart'; 

class PurchaseTab extends ConsumerStatefulWidget {
  const PurchaseTab({super.key});

  @override
  ConsumerState<PurchaseTab> createState() => _PurchaseTabState();
}

class _PurchaseTabState extends ConsumerState<PurchaseTab> {
  final _formKey = GlobalKey<FormState>();
  
  bool _isCustomVendor = false; 
  Purchaser? _selectedVendor;
  DateTime _billDate = DateTime.now(); 
  
  final _customVendorController = TextEditingController();
  final _billNoController = TextEditingController();
  final _amountController = TextEditingController(); 
  
  // --- 🔥 NEW: SEPARATE GST CONTROLLERS ---
  final _partySgstCtrl = TextEditingController(text: '0.0');
  final _partyCgstCtrl = TextEditingController(text: '0.0');
  final _partyIgstCtrl = TextEditingController(text: '0.0'); 
  
  double _cgstAmount = 0.0;
  double _sgstAmount = 0.0;
  double _igstAmount = 0.0;
  double _gstAmount = 0.0;
  double _totalAmount = 0.0;

  // --- COMMA FORMATTER ---
  String formatAmount(double val) {
    final formatter = NumberFormat.decimalPattern('en_IN');
    return '${formatter.format(val.round())}/-';
  }

  @override
  void dispose() {
    _customVendorController.dispose();
    _billNoController.dispose();
    _amountController.dispose();
    _partySgstCtrl.dispose();
    _partyCgstCtrl.dispose();
    _partyIgstCtrl.dispose();
    super.dispose();
  }

  Future<void> _syncData() async {
    await SyncEngine.syncAll();
    ref.invalidate(invoiceProvider);
    ref.invalidate(purchaserProvider);
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _billDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.redAccent, onPrimary: Colors.white),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _billDate = picked);
    }
  }

  // --- 🔥 UPDATED: CALCULATE SEPARATE GSTS ---
  void _calculateTotal() {
    setState(() {
      double subTotal = double.tryParse(_amountController.text) ?? 0.0;
      
      double sgst = double.tryParse(_partySgstCtrl.text) ?? 0.0;
      double cgst = double.tryParse(_partyCgstCtrl.text) ?? 0.0;
      double igst = double.tryParse(_partyIgstCtrl.text) ?? 0.0;
      
      _sgstAmount = (subTotal * (sgst / 100));
      _cgstAmount = (subTotal * (cgst / 100));
      _igstAmount = (subTotal * (igst / 100));
      
      _gstAmount = _sgstAmount + _cgstAmount + _igstAmount;
      _sgstAmount = _sgstAmount.roundToDouble();
      _cgstAmount = _cgstAmount.roundToDouble();
      _igstAmount = _igstAmount.roundToDouble();
      _gstAmount = _gstAmount.roundToDouble();
      
      _totalAmount = (subTotal + _gstAmount).roundToDouble();
    });
  }

  Future<void> _savePurchaseBill() async {
    if (_formKey.currentState!.validate()) {
      if (!_isCustomVendor && _selectedVendor == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a vendor', style: TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent));
        return;
      }

      final currentUserId = ref.read(authProvider);
      if (currentUserId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: You must be logged in!')));
        return;
      }

      final activeCompany = ref.read(activeCompanyProvider);
      if (activeCompany == null) return;

      Purchaser finalVendor;

      if (_isCustomVendor) {
        finalVendor = Purchaser(
          id: const Uuid().v4(),
          userId: currentUserId, 
          name: _customVendorController.text.trim(),
          address1: '', address2: '', particulars: '', gstin: '', hsnNo: '',
          sgstRate: double.tryParse(_partySgstCtrl.text) ?? 0.0, 
          cgstRate: double.tryParse(_partyCgstCtrl.text) ?? 0.0, 
          igstRate: double.tryParse(_partyIgstCtrl.text) ?? 0.0,
          lastUpdated: DateTime.now().millisecondsSinceEpoch,
        );
        await ref.read(purchaserProvider.notifier).addPurchaser(finalVendor);
      } else {
        finalVendor = _selectedVendor!;
      }

      final invoice = Invoice(
        id: const Uuid().v4(),
        userId: currentUserId, 
        companyId: activeCompany.id,
        type: 'purchase',
        purchaserId: finalVendor.id,
        billNo: _billNoController.text.trim(),
        billDate: _billDate.millisecondsSinceEpoch, 
        truckNo: '', driverName: '', licNo: '', nos: 1, unit: 'NA', quantity: 1,
        rate: double.tryParse(_amountController.text) ?? 0.0,
        amount: double.tryParse(_amountController.text) ?? 0.0,
        labourCharge: 0.0,
        subTotal: double.tryParse(_amountController.text) ?? 0.0,
        gstAmount: _gstAmount, 
        totalAmount: _totalAmount,
        lastUpdated: DateTime.now().millisecondsSinceEpoch,
        isDeleted: 0,
      );

      await ref.read(invoiceProvider.notifier).addInvoice(invoice);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Purchase Bill Logged!'), backgroundColor: Colors.green.shade700));
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => EditablePurchaseScreen(invoice: invoice, company: activeCompany, purchaser: finalVendor)),
        );
        
        _formKey.currentState!.reset();
        setState(() {
          _selectedVendor = null;
          _totalAmount = 0.0;
          _gstAmount = 0.0;
          _sgstAmount = 0.0;
          _cgstAmount = 0.0;
          _igstAmount = 0.0;
          _customVendorController.clear();
          _billNoController.clear();
          _amountController.clear();
          _partySgstCtrl.text = '0.0';
          _partyCgstCtrl.text = '0.0';
          _partyIgstCtrl.text = '0.0';
          _billDate = DateTime.now();
        });
      }
    }
  }

  InputDecoration _customInputDeco(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
      prefixIcon: icon != null ? Icon(icon, color: Colors.redAccent, size: 20) : null,
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent, width: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vendors = ref.watch(purchaserProvider);
    final sortedVendors = vendors.toList()..sort((a, b) => a.name.compareTo(b.name));

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC), 
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
          color: Colors.redAccent,
          backgroundColor: Colors.white,
          child: Form(
            key: _formKey,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(), 
              padding: const EdgeInsets.all(16.0),
              children: [
                const Text('Log Inbound Purchase', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF203A43))),
                const SizedBox(height: 8),
                const Divider(),
                const SizedBox(height: 8),

                // --- FULL WIDTH BILL DATE ---
                OutlinedButton.icon(
                  icon: Icon(Icons.calendar_today, size: 18, color: Colors.red.shade700),
                  label: Text(
                    'Bill Date: ${DateFormat('dd/MM/yyyy').format(_billDate)}', 
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade800)
                  ),
                  onPressed: _selectDate,
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft, 
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    backgroundColor: Colors.white,
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                
                // --- VENDOR TOGGLE ---
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: RadioListTile<bool>(
                          title: const Text('Existing Vendor', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          value: false,
                          groupValue: _isCustomVendor,
                          onChanged: (val) => setState(() => _isCustomVendor = val!),
                          contentPadding: EdgeInsets.zero,
                          activeColor: Colors.redAccent,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<bool>(
                          title: const Text('Custom Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          value: true,
                          groupValue: _isCustomVendor,
                          onChanged: (val) => setState(() { _isCustomVendor = val!; _selectedVendor = null; }),
                          contentPadding: EdgeInsets.zero,
                          activeColor: Colors.redAccent,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                
                // --- VENDOR INPUT ---
                if (!_isCustomVendor)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return DropdownMenu<Purchaser>(
                        width: constraints.maxWidth, 
                        expandedInsets: EdgeInsets.zero, 
                        enableFilter: true, 
                        requestFocusOnTap: true,
                        label: const Text('Search & Select Vendor'),
                        leadingIcon: const Icon(Icons.search, color: Colors.redAccent),
                        inputDecorationTheme: InputDecorationTheme(
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent, width: 2)),
                        ),
                        dropdownMenuEntries: sortedVendors.map((v) => DropdownMenuEntry<Purchaser>(
                          value: v, 
                          label: v.name,
                        )).toList(),
                        onSelected: (val) {
                          setState(() {
                            _selectedVendor = val;
                            if (val != null) {
                              _partySgstCtrl.text = val.sgstRate.toString();
                              _partyCgstCtrl.text = val.cgstRate.toString();
                              _partyIgstCtrl.text = val.igstRate.toString();
                              _calculateTotal();
                            }
                          });
                        },
                      );
                    }
                  )
                else
                  TextFormField(
                    controller: _customVendorController,
                    decoration: _customInputDeco('Enter Vendor Name', icon: Icons.business),
                    validator: (v) => _isCustomVendor && v!.isEmpty ? 'Required' : null,
                    textInputAction: TextInputAction.next,
                  ),

                const SizedBox(height: 12),
                
                // --- BILL NO ---
                TextFormField(
                  controller: _billNoController,
                  decoration: _customInputDeco('Supplier Bill No.', icon: Icons.numbers),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                
                // --- AMOUNT & GST ---
                TextFormField(
                  controller: _amountController,
                  decoration: _customInputDeco('Amount (W/O GST)'),
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => _calculateTotal(),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),

                // 🔥 NEW: INDIVIDUAL GST FIELDS
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: _partySgstCtrl, decoration: _customInputDeco('SGST %'), keyboardType: TextInputType.number, onChanged: (_) => _calculateTotal())),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(controller: _partyCgstCtrl, decoration: _customInputDeco('CGST %'), keyboardType: TextInputType.number, onChanged: (_) => _calculateTotal())),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(controller: _partyIgstCtrl, decoration: _customInputDeco('IGST %'), keyboardType: TextInputType.number, onChanged: (_) => _calculateTotal())),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // --- FINAL SUMMARY BOX ---
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50.withOpacity(0.6), 
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.shade100, width: 1.5)
                  ),
                  child: Column(
                    children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Sub Total:', style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.w600)), Text('₹${formatAmount(double.tryParse(_amountController.text) ?? 0.0)}', style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold))]),
                      
                      const SizedBox(height: 12),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('CGST (${_partyCgstCtrl.text.isEmpty ? "0" : _partyCgstCtrl.text}%):', style: TextStyle(color: Colors.red.shade400)), Text('₹${formatAmount(_cgstAmount)}', style: TextStyle(color: Colors.red.shade400))]),
                      const SizedBox(height: 4),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('SGST (${_partySgstCtrl.text.isEmpty ? "0" : _partySgstCtrl.text}%):', style: TextStyle(color: Colors.red.shade400)), Text('₹${formatAmount(_sgstAmount)}', style: TextStyle(color: Colors.red.shade400))]),
                      const SizedBox(height: 4),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('IGST (${_partyIgstCtrl.text.isEmpty ? "0" : _partyIgstCtrl.text}%):', style: TextStyle(color: Colors.red.shade400)), Text('₹${formatAmount(_igstAmount)}', style: TextStyle(color: Colors.red.shade400))]),
                      
                      const Divider(height: 24, thickness: 1.5),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text('Total Expense:', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF203A43))), 
                        Text('₹${formatAmount(_totalAmount)}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Colors.red.shade700))
                      ]),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // --- SAVE BUTTON ---
                ElevatedButton.icon(
                  onPressed: _savePurchaseBill,
                  icon: const Icon(Icons.save),
                  label: const Text('Log Purchase', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16), 
                    backgroundColor: Colors.red.shade600, 
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}