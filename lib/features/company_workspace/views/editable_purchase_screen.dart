import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../../../../models/invoice_model.dart';
import '../../../../models/company_model.dart';
import '../../../../models/purchaser_model.dart';
import '../providers/purchaser_provider.dart';
import '../providers/invoice_provider.dart';
import '../providers/company_provider.dart'; 
import '../../../../core/utils/pdf_generator.dart';

class EditablePurchaseScreen extends ConsumerStatefulWidget {
  final Invoice invoice;
  final Company company;
  final Purchaser purchaser;

  const EditablePurchaseScreen({super.key, required this.invoice, required this.company, required this.purchaser});

  @override
  ConsumerState<EditablePurchaseScreen> createState() => _EditablePurchaseScreenState();
}

class _EditablePurchaseScreenState extends ConsumerState<EditablePurchaseScreen> {
  // Vendor Controllers
  late TextEditingController _vendorNameCtrl;
  late TextEditingController _gstinCtrl;
  late TextEditingController _billNoCtrl;
  late TextEditingController _amountCtrl;
  late TextEditingController _gstPercentCtrl;

  // Company Controllers
  late TextEditingController _compGstinCtrl;
  late TextEditingController _compBankCtrl;
  late TextEditingController _compAccCtrl;
  late TextEditingController _compIfscCtrl;

  late double _calculatedGstRupees;
  late double _totalAmount;

  @override
  void initState() {
    super.initState();
    _vendorNameCtrl = TextEditingController(text: widget.purchaser.name);
    _gstinCtrl = TextEditingController(text: widget.purchaser.gstin);
    _billNoCtrl = TextEditingController(text: widget.invoice.billNo);
    _amountCtrl = TextEditingController(text: widget.invoice.subTotal.toString());
    
    // Reverse engineer flat GST %
    double flatGstPercent = widget.invoice.subTotal > 0 
      ? (widget.invoice.gstAmount / widget.invoice.subTotal) * 100 
      : 0.0;
    _gstPercentCtrl = TextEditingController(text: flatGstPercent.toStringAsFixed(1));

    _calculatedGstRupees = widget.invoice.gstAmount;
    _totalAmount = widget.invoice.totalAmount;

    // Initialize Company Controllers
    _compGstinCtrl = TextEditingController(text: widget.company.gstin);
    _compBankCtrl = TextEditingController(text: widget.company.bankName);
    _compAccCtrl = TextEditingController(text: widget.company.accountNumber);
    _compIfscCtrl = TextEditingController(text: widget.company.ifscCode);
  }

  @override
  void dispose() {
    _vendorNameCtrl.dispose();
    _gstinCtrl.dispose();
    _billNoCtrl.dispose();
    _amountCtrl.dispose();
    _gstPercentCtrl.dispose();
    
    // Dispose Company Controllers
    _compGstinCtrl.dispose();
    _compBankCtrl.dispose();
    _compAccCtrl.dispose();
    _compIfscCtrl.dispose();
    super.dispose();
  }

  void _recalculate() {
    setState(() {
      double subTotal = double.tryParse(_amountCtrl.text) ?? 0.0;
      double percent = double.tryParse(_gstPercentCtrl.text) ?? 0.0;
      _calculatedGstRupees = (subTotal * (percent / 100)).roundToDouble();
      _totalAmount = (subTotal + _calculatedGstRupees).roundToDouble();
    });
  }

  Future<Map<String, dynamic>> _saveAllChanges() async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    final updatedPurchaser = Purchaser(
      id: widget.purchaser.id,
      userId: widget.purchaser.userId, // <-- 1. ADDED USER ID
      name: _vendorNameCtrl.text.trim(),
      gstin: _gstinCtrl.text.trim(),
      address1: widget.purchaser.address1, address2: widget.purchaser.address2,
      particulars: widget.purchaser.particulars, hsnNo: widget.purchaser.hsnNo,
      sgstRate: widget.purchaser.sgstRate, cgstRate: widget.purchaser.cgstRate, igstRate: widget.purchaser.igstRate,
      lastUpdated: timestamp, isDeleted: widget.purchaser.isDeleted,
    );

    final updatedInvoice = Invoice(
      id: widget.invoice.id, 
      userId: widget.invoice.userId, // <-- 2. ADDED USER ID
      companyId: widget.company.id, type: 'purchase',
      purchaserId: widget.purchaser.id, billNo: _billNoCtrl.text.trim(),
      billDate: widget.invoice.billDate, truckNo: '', driverName: '', licNo: '', nos: 1, unit: 'NA', quantity: 1,
      rate: double.tryParse(_amountCtrl.text) ?? 0.0,
      amount: double.tryParse(_amountCtrl.text) ?? 0.0,
      labourCharge: 0.0,
      subTotal: double.tryParse(_amountCtrl.text) ?? 0.0,
      gstAmount: _calculatedGstRupees, totalAmount: _totalAmount,
      lastUpdated: timestamp, isDeleted: widget.invoice.isDeleted,
    );

    final updatedCompany = Company(
      id: widget.company.id,
      userId: widget.company.userId, // <-- 3. ADDED USER ID
      name: widget.company.name,
      address1: widget.company.address1,
      address2: widget.company.address2,
      mobileNumber: widget.company.mobileNumber,
      pin: widget.company.pin,
      gstin: _compGstinCtrl.text.trim(),
      bankName: _compBankCtrl.text.trim(),
      accountNumber: _compAccCtrl.text.trim(),
      ifscCode: _compIfscCtrl.text.trim(),
      lastUpdated: timestamp,
      isDeleted: widget.company.isDeleted,
    );

    await ref.read(purchaserProvider.notifier).updatePurchaser(updatedPurchaser);
    await ref.read(invoiceProvider.notifier).updateInvoice(updatedInvoice);
    await ref.read(companyProvider.notifier).updateCompany(updatedCompany); 
    
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Changes Saved!')));

    return {
      'invoice': updatedInvoice,
      'company': updatedCompany,
      'purchaser': updatedPurchaser,
    };
  }

  Widget _cell(TextEditingController ctrl, {bool isNum = false, TextAlign align = TextAlign.left, FontWeight fw = FontWeight.normal}) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            FocusScope.of(context).nextFocus();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            FocusScope.of(context).previousFocus();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: TextFormField(
        controller: ctrl,
        textAlign: align,
        keyboardType: isNum ? TextInputType.number : TextInputType.text,
        textCapitalization: TextCapitalization.characters, 
        textInputAction: TextInputAction.next, 
        onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
        decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
        onChanged: (_) => _recalculate(),
        style: TextStyle(fontWeight: fw, fontSize: 14),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Purchase #${widget.invoice.billNo}', style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.redAccent,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () async {
              final updatedData = await _saveAllChanges();
              final pdfBytes = await PdfGenerator.generatePurchaseVoucher(
                updatedData['invoice'], 
                updatedData['company'], 
                updatedData['purchaser']
              );
              await Printing.layoutPdf(onLayout: (format) async => pdfBytes, name: 'Purchase_${widget.invoice.billNo}.pdf');
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(border: Border.all(color: Colors.redAccent, width: 2)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(padding: const EdgeInsets.all(8), color: Colors.red.shade50, child: const Text('PURCHASE VOUCHER', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red))),
              const Divider(height: 0, thickness: 2, color: Colors.redAccent),
              
              Padding(
                padding: const EdgeInsets.all(12),
                child: Table(
                  columnWidths: const {0: FlexColumnWidth(3), 1: FlexColumnWidth(7)},
                  children: [
                    TableRow(children: [const Text('VENDOR NAME:', style: TextStyle(fontWeight: FontWeight.bold)), _cell(_vendorNameCtrl, fw: FontWeight.bold)]),
                    TableRow(children: [const Text('VENDOR GSTIN:'), _cell(_gstinCtrl)]),
                    TableRow(children: [const Text('BILL NO:'), _cell(_billNoCtrl)]),
                  ],
                ),
              ),

              const Divider(height: 0, thickness: 2, color: Colors.redAccent),
              Container(padding: const EdgeInsets.all(4), color: Colors.red.shade50, child: const Text('YOUR COMPANY DETAILS', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red))),
              const Divider(height: 0, thickness: 2, color: Colors.redAccent),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Table(
                  columnWidths: const {0: FlexColumnWidth(3), 1: FlexColumnWidth(7)},
                  children: [
                    TableRow(children: [const Text('YOUR GSTIN:'), _cell(_compGstinCtrl)]),
                    TableRow(children: [const Text('BANK NAME:'), _cell(_compBankCtrl)]),
                    TableRow(children: [const Text('A/C NO:'), _cell(_compAccCtrl)]),
                    TableRow(children: [const Text('IFSC CODE:'), _cell(_compIfscCtrl)]),
                  ],
                ),
              ),

              const Divider(height: 0, thickness: 2, color: Colors.redAccent),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Amount (W/O GST):'), SizedBox(width: 100, child: _cell(_amountCtrl, isNum: true, align: TextAlign.right))]),
                    const SizedBox(height: 10),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('GST Percentage (%):'), SizedBox(width: 100, child: _cell(_gstPercentCtrl, isNum: true, align: TextAlign.right))]),
                    const SizedBox(height: 10),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Calculated GST (₹):'), Text(_calculatedGstRupees.toStringAsFixed(0))]),
                    const Divider(thickness: 1, color: Colors.black),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('TOTAL EXPENSE:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red)), Text('₹${_totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red))]),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'download_btn', 
            backgroundColor: Colors.blueGrey, 
            foregroundColor: Colors.white,
            onPressed: () async {
              final updatedData = await _saveAllChanges();
              final pdfBytes = await PdfGenerator.generatePurchaseVoucher(
                updatedData['invoice'], 
                updatedData['company'], 
                updatedData['purchaser']
              );
              await Printing.sharePdf(
                bytes: pdfBytes, 
                filename: 'Purchase_Bill_${widget.invoice.billNo}.pdf'
              );
            },
            icon: const Icon(Icons.download_rounded),
            label: const Text('Download PDF'),
          ),
          
          const SizedBox(width: 16), 
          
          FloatingActionButton.extended(
            heroTag: 'save_btn',
            backgroundColor: Colors.redAccent, 
            foregroundColor: Colors.white,
            onPressed: _saveAllChanges,
            icon: const Icon(Icons.save),
            label: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }
}