import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../models/invoice_model.dart';
import '../../../../models/purchaser_model.dart';
import '../../providers/company_provider.dart';
import '../../providers/purchaser_provider.dart';
import '../../providers/invoice_provider.dart';
import '../editable_invoice_screen.dart';

class SalesTab extends ConsumerStatefulWidget {
  const SalesTab({super.key});

  @override
  ConsumerState<SalesTab> createState() => _SalesTabState();
}

class _SalesTabState extends ConsumerState<SalesTab> {
  final _formKey = GlobalKey<FormState>();
  
  Purchaser? _selectedPurchaser;
  
  // Text Controllers
  final _billNoController = TextEditingController();
  final _truckNoController = TextEditingController();
  final _driverNameController = TextEditingController();
  final _licNoController = TextEditingController(); // <-- ADDED LIC NO CONTROLLER
  final _nosController = TextEditingController(text: '1');
  final _quantityController = TextEditingController();
  final _rateController = TextEditingController();
  final _labourController = TextEditingController(text: '0.0');
  
  String _selectedUnit = 'CBM';
  
  // Math Engine State Variables
  double _amount = 0.0;
  double _subTotal = 0.0;
  double _gstAmount = 0.0;
  double _totalAmount = 0.0;

  @override
  void dispose() {
    _billNoController.dispose();
    _truckNoController.dispose();
    _driverNameController.dispose();
    _licNoController.dispose(); // <-- ADDED TO DISPOSE
    _nosController.dispose();
    _quantityController.dispose();
    _rateController.dispose();
    _labourController.dispose();
    super.dispose();
  }

  // --- AUTOMATED MATH ENGINE ---
  void _calculateTotals() {
    setState(() {
      double qty = double.tryParse(_quantityController.text) ?? 0.0;
      double rate = double.tryParse(_rateController.text) ?? 0.0;
      double labour = double.tryParse(_labourController.text) ?? 0.0;
      
      // 1 & 2. Amount and SubTotal (Rounded)
      _amount = (rate * qty).roundToDouble();
      _subTotal = (_amount + labour).roundToDouble();
      
      // 3. GST Math (Sum of percentages, applied to SubTotal, then Rounded)
      if (_selectedPurchaser != null) {
        double totalGstPercent = _selectedPurchaser!.sgstRate + 
                                 _selectedPurchaser!.cgstRate + 
                                 _selectedPurchaser!.igstRate;
        _gstAmount = (_subTotal * (totalGstPercent / 100)).roundToDouble();
      } else {
        _gstAmount = 0.0;
      }
      
      // 4. Total Amount (Rounded)
      _totalAmount = (_subTotal + _gstAmount).roundToDouble();
    });
  }

  void _saveInvoice() {
    if (_formKey.currentState!.validate() && _selectedPurchaser != null) {
      final activeCompany = ref.read(activeCompanyProvider);
      if (activeCompany == null) return;

      // 1. CAPTURE THE PURCHASER SAFELY
      // We save it to a local variable so it survives the form reset below
      final savedPurchaser = _selectedPurchaser!;

      final invoice = Invoice(
        id: const Uuid().v4(),
        companyId: activeCompany.id,
        type: 'sales',
        purchaserId: savedPurchaser.id, // Used safe variable
        billNo: _billNoController.text.trim(),
        billDate: DateTime.now().millisecondsSinceEpoch,
        truckNo: _truckNoController.text.trim(),
        driverName: _driverNameController.text.trim(),
        licNo: _licNoController.text.trim(), // <-- SAVES LIC NO TO DATABASE
        nos: int.tryParse(_nosController.text) ?? 1,
        unit: _selectedUnit,
        quantity: double.tryParse(_quantityController.text) ?? 0.0,
        rate: double.tryParse(_rateController.text) ?? 0.0,
        amount: _amount,
        labourCharge: double.tryParse(_labourController.text) ?? 0.0,
        subTotal: _subTotal,
        gstAmount: _gstAmount,
        totalAmount: _totalAmount,
        lastUpdated: DateTime.now().millisecondsSinceEpoch,
      );

      ref.read(invoiceProvider.notifier).addInvoice(invoice);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invoice ${_billNoController.text} saved successfully!')),
      );
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EditableInvoiceScreen(
            invoice: invoice, 
            company: activeCompany, 
            purchaser: savedPurchaser, // Used safe variable here!
          ),
        ),
      );

      // Reset form after saving
      _formKey.currentState!.reset();
      setState(() {
        _selectedPurchaser = null;
        _calculateTotals();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get global purchasers for the dropdown
    final purchasers = ref.watch(purchaserProvider);

    return Scaffold(
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            const Text('Create Sales Invoice', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Divider(),
            
            // 1. Purchaser Selection
            DropdownButtonFormField<Purchaser>(
              decoration: const InputDecoration(labelText: 'Select Purchaser', border: OutlineInputBorder()),
              value: _selectedPurchaser,
              items: purchasers.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
              onChanged: (val) {
                setState(() {
                  _selectedPurchaser = val;
                  _calculateTotals(); // Recalculate if tax rates change
                });
              },
              validator: (val) => val == null ? 'Please select a purchaser' : null,
            ),
            const SizedBox(height: 10),
            
            // 2. Invoice Meta Data (Bill & Truck)
            Row(
              children: [
                Expanded(child: TextFormField(controller: _billNoController, decoration: const InputDecoration(labelText: 'Bill No.', border: OutlineInputBorder()), validator: (v) => v == null || v.isEmpty ? 'Required' : null)),
                const SizedBox(width: 10),
                Expanded(child: TextFormField(controller: _truckNoController, decoration: const InputDecoration(labelText: 'Truck No.', border: OutlineInputBorder()))),
              ],
            ),
            const SizedBox(height: 10),

            // --- NEW: Driver Name and Lic No Row ---
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _driverNameController,
                    decoration: const InputDecoration(labelText: 'Driver Name', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _licNoController,
                    decoration: const InputDecoration(labelText: 'Lic No.', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            
            // 3. Variables & Math Engine Inputs
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _nosController,
                    decoration: const InputDecoration(labelText: 'NOS.', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Unit', border: OutlineInputBorder()),
                    value: _selectedUnit,
                    items: ['CBM', 'KG'].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                    onChanged: (val) {
                      setState(() => _selectedUnit = val!);
                      _calculateTotals(); 
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _quantityController,
                    decoration: InputDecoration(labelText: 'Quantity ($_selectedUnit)', border: const OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _calculateTotals(),
                  )
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _rateController,
                    decoration: const InputDecoration(labelText: 'Rate (₹)', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _calculateTotals(),
                  )
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _labourController,
              decoration: const InputDecoration(labelText: 'Labour Charge (₹)', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
              onChanged: (_) => _calculateTotals(),
            ),
            
            // 4. Live Calculation Display
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
              child: Column(
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Amount:'), Text('₹${_amount.toStringAsFixed(2)}')]),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Sub Total (W/O GST):'), Text('₹${_subTotal.toStringAsFixed(2)}')]),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('GST Amount:'), Text('₹${_gstAmount.toStringAsFixed(2)}')]),
                  const Divider(),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Total Amount:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), 
                    Text('₹${_totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue))
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