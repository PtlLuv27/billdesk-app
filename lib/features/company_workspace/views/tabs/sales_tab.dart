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
  List<TextEditingController> _extraParticularCtrls = [];
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
  
  double _cgstAmount = 0.0;
  double _sgstAmount = 0.0;
  double _igstAmount = 0.0;
  
  double _totalAmount = 0.0;

  String formatIndianCurrency(double val) {
    final formatter = NumberFormat.decimalPattern('en_IN');
    return '${formatter.format(val)}/-';
  }

  double _parseNumber(String val) {
    if (val.isEmpty) return 0.0;
    return double.tryParse(val.replaceAll(',', '.')) ?? 0.0;
  }

  @override
  void dispose() {
    _partyAddressCtrl.dispose();
    _partyAddress2Ctrl.dispose();
    _partyParticularsCtrl.dispose();
    for (var ctrl in _extraParticularCtrls) {
      ctrl.dispose();
    }
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
      double qty = _parseNumber(_quantityController.text);
      double rate = _parseNumber(_rateController.text);
      double labour = _parseNumber(_labourController.text);
      
      _amount = (rate * qty).roundToDouble();
      _subTotal = (_amount + labour).roundToDouble();
      
      if (_selectedPurchaser != null) {
        double sgst = _parseNumber(_partySgstCtrl.text);
        double cgst = _parseNumber(_partyCgstCtrl.text);
        double igst = _parseNumber(_partyIgstCtrl.text);
        
        _sgstAmount = (_subTotal * (sgst / 100));
        _cgstAmount = (_subTotal * (cgst / 100));
        _igstAmount = (_subTotal * (igst / 100));
        _gstAmount = _sgstAmount + _cgstAmount + _igstAmount;

        _sgstAmount = _sgstAmount.roundToDouble();
        _cgstAmount = _cgstAmount.roundToDouble();
        _igstAmount = _igstAmount.roundToDouble();
        _gstAmount = _gstAmount.roundToDouble();
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.blueAccent, onPrimary: Colors.white),
          ),
          child: child!,
        );
      },
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

      final combinedParticulars = [
        _partyParticularsCtrl.text.trim(),
        ..._extraParticularCtrls.map((c) => c.text.trim())
      ].where((e) => e.isNotEmpty).join(', ');

      // TEMPORARY SNAPSHOT: Edits apply ONLY to this invoice, not the database.
      final tempPurchaserSnapshot = Purchaser(
        id: _selectedPurchaser!.id,
        userId: _selectedPurchaser!.userId,
        name: _selectedPurchaser!.name,
        address1: _partyAddressCtrl.text.trim(), 
        address2: _partyAddress2Ctrl.text.trim(),
        particulars: combinedParticulars, 
        gstin: _partyGstinCtrl.text.trim(),      
        hsnNo: _partyHsnNoCtrl.text.trim(),
        sgstRate: _parseNumber(_partySgstCtrl.text), 
        cgstRate: _parseNumber(_partyCgstCtrl.text), 
        igstRate: _parseNumber(_partyIgstCtrl.text), 
        lastUpdated: _selectedPurchaser!.lastUpdated,
      );

      final invoice = Invoice(
        id: const Uuid().v4(),
        userId: currentUserId, 
        companyId: activeCompany.id,
        type: 'sales',
        purchaserId: _selectedPurchaser!.id, 
        billNo: _billNoController.text.trim(),
        billDate: _billDate.millisecondsSinceEpoch,
        truckNo: _truckNoController.text.trim(),
        driverName: _driverNameController.text.trim(),
        licNo: _licNoController.text.trim(), 
        nos: int.tryParse(_nosController.text) ?? 1,
        unit: _selectedUnit,
        quantity: _selectedUnit == 'NOS' ? _parseNumber(_nosController.text) : _parseNumber(_quantityController.text),
        rate: _parseNumber(_rateController.text),        
        amount: _amount,
        labourCharge: _parseNumber(_labourController.text), 
        subTotal: _subTotal,
        gstAmount: _gstAmount,
        totalAmount: _totalAmount,
        lastUpdated: DateTime.now().millisecondsSinceEpoch,
      );

      await ref.read(invoiceProvider.notifier).addInvoice(invoice);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invoice saved successfully!'), backgroundColor: Colors.green));
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditableInvoiceScreen(
              invoice: invoice, 
              company: activeCompany, 
              purchaser: tempPurchaserSnapshot, 
            ),
          ),
        );

        _formKey.currentState!.reset();
        setState(() {
          _selectedPurchaser = null;
          _partyAddressCtrl.clear();
          _partyAddress2Ctrl.clear();
          _partyParticularsCtrl.clear();
          
          for (var ctrl in _extraParticularCtrls) { ctrl.dispose(); }
          _extraParticularCtrls.clear();
          
          _partyGstinCtrl.clear();
          _partyHsnNoCtrl.clear();
          _partySgstCtrl.clear();
          _partyCgstCtrl.clear();
          _partyIgstCtrl.clear();
          _billDate = DateTime.now();
          _billNoController.clear();
          _truckNoController.clear();
          _driverNameController.clear();
          _licNoController.clear();
          _calculateTotals();
        });
      }
    }
  }

  // A clean, modern input decoration for the continuous form
  InputDecoration _customInputDeco(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
      prefixIcon: icon != null ? Icon(icon, color: Colors.blueAccent, size: 20) : null,
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blueAccent, width: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final purchasers = ref.watch(purchaserProvider);
    final sortedPurchasers = purchasers.toList()..sort((a, b) => a.name.compareTo(b.name));

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC), // Soft background to make white inputs pop
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            const Text('Create Sales Invoice', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF203A43))),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            
            // --- FULL WIDTH BILL DATE ---
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today, size: 18),
              label: Text(
                'Bill Date: ${DateFormat('dd/MM/yyyy').format(_billDate)}', 
                style: const TextStyle(fontWeight: FontWeight.bold)
              ),
              onPressed: _selectDate,
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft, 
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                backgroundColor: Colors.white,
                foregroundColor: Colors.blueAccent,
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            
            // --- PARTY DROPDOWN ---
            LayoutBuilder(
              builder: (context, constraints) {
                return DropdownMenu<Purchaser>(
                  width: constraints.maxWidth, 
                  expandedInsets: EdgeInsets.zero, 
                  enableFilter: true, 
                  requestFocusOnTap: true,
                  label: const Text('Search & Select Purchaser'),
                  leadingIcon: const Icon(Icons.search, color: Colors.blueAccent),
                  inputDecorationTheme: InputDecorationTheme(
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blueAccent, width: 2)),
                  ),
                  dropdownMenuEntries: sortedPurchasers.map((p) => DropdownMenuEntry<Purchaser>(
                    value: p, 
                    label: p.name,
                  )).toList(),
                  onSelected: (val) {
                    setState(() {
                      _selectedPurchaser = val;
                      if (val != null) {
                        _partyAddressCtrl.text = val.address1;
                        _partyAddress2Ctrl.text = val.address2;

                        final parts = val.particulars.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                        
                        for (var ctrl in _extraParticularCtrls) { ctrl.dispose(); }
                        _extraParticularCtrls.clear();

                        if (parts.isNotEmpty) {
                          _partyParticularsCtrl.text = parts.first; 
                          _extraParticularCtrls = parts.skip(1).map((e) => TextEditingController(text: e)).toList();
                        } else {
                          _partyParticularsCtrl.text = '';
                        }

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
            const SizedBox(height: 12),

            // --- CONDITIONALLY RENDERED PARTY DETAILS ---
            if (_selectedPurchaser != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50.withOpacity(0.4), 
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade100)
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                        const SizedBox(width: 6),
                        Text('Edits apply to this bill only', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blue.shade700, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: TextFormField(controller: _partyAddressCtrl, decoration: _customInputDeco('Address 1'))),
                        const SizedBox(width: 12),
                        Expanded(child: TextFormField(controller: _partyAddress2Ctrl, decoration: _customInputDeco('Address 2'))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2, 
                          child: TextFormField(
                            controller: _partyParticularsCtrl, 
                            decoration: _customInputDeco('Default Item / Particulars').copyWith(
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.add_circle, color: Colors.blueAccent),
                                onPressed: () => setState(() => _extraParticularCtrls.add(TextEditingController())),
                              )
                            )
                          )
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: TextFormField(controller: _partyHsnNoCtrl, decoration: _customInputDeco('HSN No.'))),
                      ],
                    ),
                    
                    if (_extraParticularCtrls.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ...List.generate(_extraParticularCtrls.length, (index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _extraParticularCtrls[index],
                                  decoration: _customInputDeco('Additional Item ${index + 1}').copyWith(
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.remove_circle, color: Colors.redAccent),
                                      onPressed: () => setState(() {
                                        _extraParticularCtrls[index].dispose();
                                        _extraParticularCtrls.removeAt(index);
                                      }),
                                    )
                                  )
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(child: SizedBox()), 
                            ],
                          )
                        );
                      })
                    ],

                    const SizedBox(height: 12),
                    TextFormField(controller: _partyGstinCtrl, decoration: _customInputDeco('GSTIN'), textCapitalization: TextCapitalization.characters),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: TextFormField(controller: _partySgstCtrl, decoration: _customInputDeco('SGST %'), keyboardType: TextInputType.number, onChanged: (_) => _calculateTotals())),
                        const SizedBox(width: 12),
                        Expanded(child: TextFormField(controller: _partyCgstCtrl, decoration: _customInputDeco('CGST %'), keyboardType: TextInputType.number, onChanged: (_) => _calculateTotals())),
                        const SizedBox(width: 12),
                        Expanded(child: TextFormField(controller: _partyIgstCtrl, decoration: _customInputDeco('IGST %'), keyboardType: TextInputType.number, onChanged: (_) => _calculateTotals())),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // --- BILL NO & TRUCK NO (MOVED UP) ---
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _billNoController, 
                    decoration: _customInputDeco('Bill No.'), 
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null, 
                    textInputAction: TextInputAction.next
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _truckNoController, 
                    decoration: _customInputDeco('Truck No.'), 
                    textInputAction: TextInputAction.next
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // --- INVOICE MATH ITEMS ---
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _nosController, 
                    decoration: _customInputDeco('NOS.'), 
                    keyboardType: TextInputType.number, 
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => _calculateTotals()
                  )
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: _customInputDeco('Unit'),
                    initialValue: _selectedUnit,
                    icon: const Icon(Icons.keyboard_arrow_down, color: Colors.blueAccent),
                    items: ['CBM', 'KG', 'NOS'].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                    onChanged: (val) { setState(() => _selectedUnit = val!); _calculateTotals(); },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (_selectedUnit != 'NOS') ...[
                  Expanded(
                    child: TextFormField(
                      controller: _quantityController, 
                      decoration: _customInputDeco('Quantity ($_selectedUnit)'), 
                      keyboardType: TextInputType.number, 
                      textInputAction: TextInputAction.next, 
                      onChanged: (_) => _calculateTotals()
                    )
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: TextFormField(
                    controller: _rateController, 
                    decoration: _customInputDeco('Rate (₹)'), 
                    keyboardType: TextInputType.number, 
                    textInputAction: TextInputAction.next, 
                    onChanged: (_) => _calculateTotals()
                  )
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _labourController,
              decoration: _customInputDeco('Labour Charge (₹)'),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onChanged: (_) => _calculateTotals(),
            ),
            const SizedBox(height: 12),
            
            // --- DRIVER NAME & LIC NO ---
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _driverNameController, 
                    decoration: _customInputDeco('Driver Name'), 
                    textInputAction: TextInputAction.next
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _licNoController, 
                    decoration: _customInputDeco('Lic No.'), 
                    textInputAction: TextInputAction.next
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // --- FINAL SUMMARY BOX ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.shade50.withOpacity(0.6), 
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.shade100, width: 1.5)
              ),
              child: Column(
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Amount:', style: TextStyle(color: Colors.blueGrey.shade700, fontWeight: FontWeight.w600)), Text('₹${formatIndianCurrency(_amount)}', style: const TextStyle(fontWeight: FontWeight.bold))]),
                  const SizedBox(height: 6),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Sub Total:', style: TextStyle(color: Colors.blueGrey.shade700, fontWeight: FontWeight.w600)), Text('₹${formatIndianCurrency(_subTotal)}', style: const TextStyle(fontWeight: FontWeight.bold))]),
                  
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('CGST (${_partyCgstCtrl.text.isEmpty ? "0" : _partyCgstCtrl.text}%):', style: TextStyle(color: Colors.grey.shade600)), Text('₹${formatIndianCurrency(_cgstAmount)}', style: TextStyle(color: Colors.grey.shade600))]),
                  const SizedBox(height: 4),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('SGST (${_partySgstCtrl.text.isEmpty ? "0" : _partySgstCtrl.text}%):', style: TextStyle(color: Colors.grey.shade600)), Text('₹${formatIndianCurrency(_sgstAmount)}', style: TextStyle(color: Colors.grey.shade600))]),
                  const SizedBox(height: 4),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('IGST (${_partyIgstCtrl.text.isEmpty ? "0" : _partyIgstCtrl.text}%):', style: TextStyle(color: Colors.grey.shade600)), Text('₹${formatIndianCurrency(_igstAmount)}', style: TextStyle(color: Colors.grey.shade600))]),
                  
                  const Divider(height: 24, thickness: 1.5),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Total Amount:', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF203A43))), 
                    Text('₹${formatIndianCurrency(_totalAmount)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Colors.blueAccent))
                  ]),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // --- SAVE BUTTON ---
            ElevatedButton(
              onPressed: _saveInvoice,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16), 
                backgroundColor: Colors.blueAccent, 
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
              child: const Text('Save Invoice', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}