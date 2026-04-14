import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../models/invoice_model.dart';
import '../../../../models/purchaser_model.dart';
import '../../providers/company_provider.dart';
import '../../providers/purchaser_provider.dart';
import '../../providers/invoice_provider.dart';
import '../editable_purchase_screen.dart';

class PurchaseTab extends ConsumerStatefulWidget {
  const PurchaseTab({super.key});

  @override
  ConsumerState<PurchaseTab> createState() => _PurchaseTabState();
}

class _PurchaseTabState extends ConsumerState<PurchaseTab> {
  final _formKey = GlobalKey<FormState>();
  
  bool _isCustomVendor = false; // Toggle state
  Purchaser? _selectedVendor;
  
  final _customVendorController = TextEditingController();
  final _billNoController = TextEditingController();
  final _amountController = TextEditingController(); 
  final _gstPercentController = TextEditingController(text: '0.0'); 
  
  double _calculatedGstRupees = 0.0;
  double _totalAmount = 0.0;

  @override
  void dispose() {
    _customVendorController.dispose();
    _billNoController.dispose();
    _amountController.dispose();
    _gstPercentController.dispose();
    super.dispose();
  }

  void _calculateTotal() {
    setState(() {
      double subTotal = double.tryParse(_amountController.text) ?? 0.0;
      double gstPercent = double.tryParse(_gstPercentController.text) ?? 0.0;
      
      _calculatedGstRupees = (subTotal * (gstPercent / 100)).roundToDouble();
      _totalAmount = (subTotal + _calculatedGstRupees).roundToDouble();
    });
  }

  Future<void> _savePurchaseBill() async {
    if (_formKey.currentState!.validate()) {
      if (!_isCustomVendor && _selectedVendor == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a vendor')));
        return;
      }

      final activeCompany = ref.read(activeCompanyProvider);
      if (activeCompany == null) return;

      Purchaser finalVendor;

      // 1. Handle Vendor Logic
      if (_isCustomVendor) {
        // Create an empty vendor profile on the fly
        finalVendor = Purchaser(
          id: const Uuid().v4(),
          name: _customVendorController.text.trim(),
          address1: '', address2: '', particulars: '', gstin: '', hsnNo: '',
          sgstRate: 0, cgstRate: 0, igstRate: 0,
          lastUpdated: DateTime.now().millisecondsSinceEpoch,
        );
        await ref.read(purchaserProvider.notifier).addPurchaser(finalVendor);
      } else {
        finalVendor = _selectedVendor!;
      }

      // 2. Build Invoice
      final invoice = Invoice(
        id: const Uuid().v4(),
        companyId: activeCompany.id,
        type: 'purchase',
        purchaserId: finalVendor.id,
        billNo: _billNoController.text.trim(),
        billDate: DateTime.now().millisecondsSinceEpoch,
        truckNo: '', driverName: '', licNo: '', nos: 1, unit: 'NA', quantity: 1,
        rate: double.tryParse(_amountController.text) ?? 0.0,
        amount: double.tryParse(_amountController.text) ?? 0.0,
        labourCharge: 0.0,
        subTotal: double.tryParse(_amountController.text) ?? 0.0,
        gstAmount: _calculatedGstRupees, 
        totalAmount: _totalAmount,
        lastUpdated: DateTime.now().millisecondsSinceEpoch,
      );

      // 3. Save & Navigate
      await ref.read(invoiceProvider.notifier).addInvoice(invoice);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Purchase Bill Logged!')));
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => EditablePurchaseScreen(invoice: invoice, company: activeCompany, purchaser: finalVendor)),
        );
        
        // Reset Form
        _formKey.currentState!.reset();
        setState(() {
          _selectedVendor = null;
          _totalAmount = 0.0;
          _calculatedGstRupees = 0.0;
          _customVendorController.clear();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vendors = ref.watch(purchaserProvider);

    return Scaffold(
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            const Text('Log Inbound Purchase', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Divider(),
            
            // --- VENDOR SELECTION TOGGLE ---
            Row(
              children: [
                Expanded(
                  child: RadioListTile<bool>(
                    title: const Text('Existing Vendor', style: TextStyle(fontSize: 12)),
                    value: false,
                    groupValue: _isCustomVendor,
                    onChanged: (val) => setState(() => _isCustomVendor = val!),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                Expanded(
                  child: RadioListTile<bool>(
                    title: const Text('Custom Name', style: TextStyle(fontSize: 12)),
                    value: true,
                    groupValue: _isCustomVendor,
                    onChanged: (val) => setState(() { _isCustomVendor = val!; _selectedVendor = null; }),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            
            // --- VENDOR INPUT FIELDS ---
            if (!_isCustomVendor)
              DropdownButtonFormField<Purchaser>(
                decoration: const InputDecoration(labelText: 'Select Vendor/Supplier', border: OutlineInputBorder()),
                value: _selectedVendor,
                items: vendors.map((v) => DropdownMenuItem(value: v, child: Text(v.name))).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedVendor = val;
                    if (val != null) {
                      _gstPercentController.text = (val.igstRate + val.cgstRate + val.sgstRate).toString();
                      _calculateTotal();
                    }
                  });
                },
              )
            else
              TextFormField(
                controller: _customVendorController,
                decoration: const InputDecoration(labelText: 'Enter Vendor Name', border: OutlineInputBorder()),
                validator: (v) => _isCustomVendor && v!.isEmpty ? 'Required' : null,
              ),

            const SizedBox(height: 15),
            
            // --- BILL NO ---
            TextFormField(
              controller: _billNoController,
              decoration: const InputDecoration(labelText: 'Supplier Bill No.', border: OutlineInputBorder()),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 15),
            
            // --- AMOUNTS ---
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _amountController,
                    decoration: const InputDecoration(labelText: 'Amount (W/O GST)', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _calculateTotal(),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: _gstPercentController,
                    decoration: const InputDecoration(labelText: 'GST %', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _calculateTotal(),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // --- MATH DISPLAY ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
              child: Column(
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Calculated GST:'), Text('₹${_calculatedGstRupees.toStringAsFixed(0)}')]),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                    children: [
                      const Text('Total Expense:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), 
                      Text('₹${_totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red))
                    ]
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _savePurchaseBill,
              icon: const Icon(Icons.save),
              label: const Text('Log Purchase', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}