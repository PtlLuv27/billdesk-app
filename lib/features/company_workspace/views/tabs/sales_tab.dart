import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart'; 
import '../../../../models/invoice_model.dart';
import '../../../../models/purchaser_model.dart';
import '../../providers/company_provider.dart';
import '../../providers/purchaser_provider.dart';
import '../../providers/invoice_provider.dart';
import '../editable_invoice_screen.dart';
import '../../../authentication/providers/auth_provider.dart';

class SalesTab extends ConsumerStatefulWidget {
  const SalesTab({super.key});

  @override
  ConsumerState<SalesTab> createState() => _SalesTabState();
}

class _SalesTabState extends ConsumerState<SalesTab> {
  final _formKey = GlobalKey<FormState>();
  
  Purchaser? _selectedPurchaser;
  
  DateTime _billDate = DateTime.now();
  
  // --- PARTY FIELDS CONTROLLERS ---
  final _partyAddressCtrl = TextEditingController();
  final _partyAddress2Ctrl = TextEditingController();
  final _partyParticularsCtrl = TextEditingController();
  final _partyGstinCtrl = TextEditingController();
  final _partyHsnNoCtrl = TextEditingController();
  final _partySgstCtrl = TextEditingController();
  final _partyCgstCtrl = TextEditingController();
  final _partyIgstCtrl = TextEditingController();

  // --- INVOICE FIELDS CONTROLLERS ---
  final _billNoController = TextEditingController();
  final _truckNoController = TextEditingController();
  final _driverNameController = TextEditingController();
  final _licNoController = TextEditingController(); 
  final _nosController = TextEditingController(text: '1');
  final _quantityController = TextEditingController();
  final _rateController = TextEditingController();
  final _labourController = TextEditingController(text: '0.0');
  
  String _selectedUnit = 'CBM';
  
  double _amount = 0.0;
  double _subTotal = 0.0;
  double _gstAmount = 0.0;
  
  // --- INDIVIDUAL GST AMOUNTS ---
  double _cgstAmount = 0.0;
  double _sgstAmount = 0.0;
  double _igstAmount = 0.0;
  
  double _totalAmount = 0.0;

  String formatIndianCurrency(double val) {
    final formatter = NumberFormat.decimalPattern('en_IN');
    return '${formatter.format(val)}/-';
  }

  // --- NEW: BULLETPROOF NUMBER PARSER ---
  // This automatically replaces commas with dots to prevent math errors!
  double _parseNumber(String val) {
    if (val.isEmpty) return 0.0;
    return double.tryParse(val.replaceAll(',', '.')) ?? 0.0;
  }

  @override
  void dispose() {
    _partyAddressCtrl.dispose();
    _partyAddress2Ctrl.dispose();
    _partyParticularsCtrl.dispose();
    _partyGstinCtrl.dispose();
    _partyHsnNoCtrl.dispose();
    _partySgstCtrl.dispose();
    _partyCgstCtrl.dispose();
    _partyIgstCtrl.dispose();
    
    _billNoController.dispose();
    _truckNoController.dispose();
    _driverNameController.dispose();
    _licNoController.dispose(); 
    _nosController.dispose();
    _quantityController.dispose();
    _rateController.dispose();
    _labourController.dispose();
    super.dispose();
  }

  void _calculateTotals() {
    setState(() {
      // Using the bulletproof parser
      double qty = _parseNumber(_quantityController.text);
      double rate = _parseNumber(_rateController.text);
      double labour = _parseNumber(_labourController.text);
      
      _amount = (rate * qty).roundToDouble();
      _subTotal = (_amount + labour).roundToDouble();
      
      if (_selectedPurchaser != null) {
        // Read GST values using the bulletproof parser
        double sgst = _parseNumber(_partySgstCtrl.text);
        double cgst = _parseNumber(_partyCgstCtrl.text);
        double igst = _parseNumber(_partyIgstCtrl.text);
        
        // Calculate individual amounts
        _sgstAmount = (_subTotal * (sgst / 100)).roundToDouble();
        _cgstAmount = (_subTotal * (cgst / 100)).roundToDouble();
        _igstAmount = (_subTotal * (igst / 100)).roundToDouble();
        
        _gstAmount = _sgstAmount + _cgstAmount + _igstAmount;
      } else {
        _sgstAmount = 0.0;
        _cgstAmount = 0.0;
        _igstAmount = 0.0;
        _gstAmount = 0.0;
      }
      _totalAmount = (_subTotal + _gstAmount).roundToDouble();
    });
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _billDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _billDate = picked);
    }
  }

  void _saveInvoice() async {
    if (_selectedPurchaser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select a purchaser from the dropdown!'),
        backgroundColor: Colors.redAccent,
      ));
      return;
    }

    if (_formKey.currentState!.validate()) {
      final currentUserId = ref.read(authProvider);
      if (currentUserId == null) return;

      final activeCompany = ref.read(activeCompanyProvider);
      if (activeCompany == null) return;

      final updatedPurchaser = Purchaser(
        id: _selectedPurchaser!.id,
        userId: _selectedPurchaser!.userId,
        name: _selectedPurchaser!.name,
        address1: _partyAddressCtrl.text.trim(), 
        address2: _partyAddress2Ctrl.text.trim(),
        particulars: _partyParticularsCtrl.text.trim(),
        gstin: _partyGstinCtrl.text.trim(),      
        hsnNo: _partyHsnNoCtrl.text.trim(),
        sgstRate: _parseNumber(_partySgstCtrl.text), // Uses bulletproof parser
        cgstRate: _parseNumber(_partyCgstCtrl.text), // Uses bulletproof parser
        igstRate: _parseNumber(_partyIgstCtrl.text), // Uses bulletproof parser
        lastUpdated: DateTime.now().millisecondsSinceEpoch,
      );

      await ref.read(purchaserProvider.notifier).updatePurchaser(updatedPurchaser);

      final invoice = Invoice(
        id: const Uuid().v4(),
        userId: currentUserId, 
        companyId: activeCompany.id,
        type: 'sales',
        purchaserId: updatedPurchaser.id, 
        billNo: _billNoController.text.trim(),
        billDate: _billDate.millisecondsSinceEpoch,
        truckNo: _truckNoController.text.trim(),
        driverName: _driverNameController.text.trim(),
        licNo: _licNoController.text.trim(), 
        nos: int.tryParse(_nosController.text) ?? 1,
        unit: _selectedUnit,
        quantity: _parseNumber(_quantityController.text), // Uses bulletproof parser
        rate: _parseNumber(_rateController.text),         // Uses bulletproof parser
        amount: _amount,
        labourCharge: _parseNumber(_labourController.text), // Uses bulletproof parser
        subTotal: _subTotal,
        gstAmount: _gstAmount,
        totalAmount: _totalAmount,
        lastUpdated: DateTime.now().millisecondsSinceEpoch,
      );

      await ref.read(invoiceProvider.notifier).addInvoice(invoice);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invoice saved successfully!')));
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditableInvoiceScreen(
              invoice: invoice, 
              company: activeCompany, 
              purchaser: updatedPurchaser, 
            ),
          ),
        );

        _formKey.currentState!.reset();
        setState(() {
          _selectedPurchaser = null;
          _partyAddressCtrl.clear();
          _partyAddress2Ctrl.clear();
          _partyParticularsCtrl.clear();
          _partyGstinCtrl.clear();
          _partyHsnNoCtrl.clear();
          _partySgstCtrl.clear();
          _partyCgstCtrl.clear();
          _partyIgstCtrl.clear();
          _billDate = DateTime.now();
          _calculateTotals();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final purchasers = ref.watch(purchaserProvider);

    return Scaffold(
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            const Text('Create Sales Invoice', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Divider(),
            
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today),
              label: Text('Bill Date: ${DateFormat('dd/MM/yyyy').format(_billDate)}'),
              onPressed: _selectDate,
              style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft, padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12)),
            ),
            const SizedBox(height: 16),
            
            LayoutBuilder(
              builder: (context, constraints) {
                return DropdownMenu<Purchaser>(
                  width: constraints.maxWidth, 
                  enableFilter: true, 
                  requestFocusOnTap: true,
                  label: const Text('Search & Select Purchaser'),
                  leadingIcon: const Icon(Icons.search),
                  dropdownMenuEntries: purchasers.map((p) => DropdownMenuEntry<Purchaser>(
                    value: p, 
                    label: p.name,
                  )).toList(),
                  onSelected: (val) {
                    setState(() {
                      _selectedPurchaser = val;
                      if (val != null) {
                        _partyAddressCtrl.text = val.address1;
                        _partyAddress2Ctrl.text = val.address2;
                        _partyParticularsCtrl.text = val.particulars;
                        _partyGstinCtrl.text = val.gstin;
                        _partyHsnNoCtrl.text = val.hsnNo;
                        _partySgstCtrl.text = val.sgstRate.toString();
                        _partyCgstCtrl.text = val.cgstRate.toString();
                        _partyIgstCtrl.text = val.igstRate.toString();
                        _calculateTotals(); 
                      }
                    });
                  },
                );
              }
            ),
            const SizedBox(height: 10),

            if (_selectedPurchaser != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Edit Party Details (Auto-Saves on Bill Creation)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: TextFormField(controller: _partyAddressCtrl, decoration: const InputDecoration(labelText: 'Address 1', isDense: true, filled: true, fillColor: Colors.white))),
                        const SizedBox(width: 8),
                        Expanded(child: TextFormField(controller: _partyAddress2Ctrl, decoration: const InputDecoration(labelText: 'Address 2', isDense: true, filled: true, fillColor: Colors.white))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(flex: 2, child: TextFormField(controller: _partyParticularsCtrl, decoration: const InputDecoration(labelText: 'Default Item / Particulars', isDense: true, filled: true, fillColor: Colors.white))),
                        const SizedBox(width: 8),
                        Expanded(child: TextFormField(controller: _partyHsnNoCtrl, decoration: const InputDecoration(labelText: 'HSN No.', isDense: true, filled: true, fillColor: Colors.white))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(controller: _partyGstinCtrl, decoration: const InputDecoration(labelText: 'GSTIN', isDense: true, filled: true, fillColor: Colors.white), textCapitalization: TextCapitalization.characters),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: TextFormField(controller: _partySgstCtrl, decoration: const InputDecoration(labelText: 'SGST %', isDense: true, filled: true, fillColor: Colors.white), keyboardType: TextInputType.number, onChanged: (_) => _calculateTotals())),
                        const SizedBox(width: 8),
                        Expanded(child: TextFormField(controller: _partyCgstCtrl, decoration: const InputDecoration(labelText: 'CGST %', isDense: true, filled: true, fillColor: Colors.white), keyboardType: TextInputType.number, onChanged: (_) => _calculateTotals())),
                        const SizedBox(width: 8),
                        Expanded(child: TextFormField(controller: _partyIgstCtrl, decoration: const InputDecoration(labelText: 'IGST %', isDense: true, filled: true, fillColor: Colors.white), keyboardType: TextInputType.number, onChanged: (_) => _calculateTotals())),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            Row(
              children: [
                Expanded(child: TextFormField(controller: _billNoController, decoration: const InputDecoration(labelText: 'Bill No.', border: OutlineInputBorder()), validator: (v) => v == null || v.isEmpty ? 'Required' : null, textInputAction: TextInputAction.next)),
                const SizedBox(width: 10),
                Expanded(child: TextFormField(controller: _truckNoController, decoration: const InputDecoration(labelText: 'Truck No.', border: OutlineInputBorder()), textInputAction: TextInputAction.next)),
              ],
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(child: TextFormField(controller: _driverNameController, decoration: const InputDecoration(labelText: 'Driver Name', border: OutlineInputBorder()), textInputAction: TextInputAction.next)),
                const SizedBox(width: 10),
                Expanded(child: TextFormField(controller: _licNoController, decoration: const InputDecoration(labelText: 'Lic No.', border: OutlineInputBorder()), textInputAction: TextInputAction.next)),
              ],
            ),
            const SizedBox(height: 10),
            
            Row(
              children: [
                Expanded(child: TextFormField(controller: _nosController, decoration: const InputDecoration(labelText: 'NOS.', border: OutlineInputBorder()), keyboardType: TextInputType.number, textInputAction: TextInputAction.next)),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Unit', border: OutlineInputBorder()),
                    initialValue: _selectedUnit,
                    items: ['CBM', 'KG'].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                    onChanged: (val) { setState(() => _selectedUnit = val!); _calculateTotals(); },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: TextFormField(controller: _quantityController, decoration: InputDecoration(labelText: 'Quantity ($_selectedUnit)', border: const OutlineInputBorder()), keyboardType: TextInputType.number, textInputAction: TextInputAction.next, onChanged: (_) => _calculateTotals())),
                const SizedBox(width: 10),
                Expanded(child: TextFormField(controller: _rateController, decoration: const InputDecoration(labelText: 'Rate (₹)', border: OutlineInputBorder()), keyboardType: TextInputType.number, textInputAction: TextInputAction.next, onChanged: (_) => _calculateTotals())),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _labourController,
              decoration: const InputDecoration(labelText: 'Labour Charge (₹)', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onChanged: (_) => _calculateTotals(),
            ),
            
            const SizedBox(height: 20),
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
              child: Column(
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Amount:'), Text('₹${formatIndianCurrency(_amount)}')]),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Sub Total:'), Text('₹${formatIndianCurrency(_subTotal)}')]),
                  
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('CGST (${_partyCgstCtrl.text.isEmpty ? "0" : _partyCgstCtrl.text}%):', style: TextStyle(color: Colors.grey.shade700)), Text('₹${formatIndianCurrency(_cgstAmount)}', style: TextStyle(color: Colors.grey.shade700))]),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('SGST (${_partySgstCtrl.text.isEmpty ? "0" : _partySgstCtrl.text}%):', style: TextStyle(color: Colors.grey.shade700)), Text('₹${formatIndianCurrency(_sgstAmount)}', style: TextStyle(color: Colors.grey.shade700))]),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('IGST (${_partyIgstCtrl.text.isEmpty ? "0" : _partyIgstCtrl.text}%):', style: TextStyle(color: Colors.grey.shade700)), Text('₹${formatIndianCurrency(_igstAmount)}', style: TextStyle(color: Colors.grey.shade700))]),
                  
                  const Divider(),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Total Amount:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), 
                    Text('₹${formatIndianCurrency(_totalAmount)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue))
                  ]),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _saveInvoice,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
              child: const Text('Save Invoice', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}