import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../../../../models/invoice_model.dart';
import '../../../../models/company_model.dart';
import '../../../../models/purchaser_model.dart';
import '../providers/purchaser_provider.dart';
import '../providers/invoice_provider.dart';
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
  late TextEditingController _vendorNameCtrl;
  late TextEditingController _gstinCtrl;
  late TextEditingController _billNoCtrl;
  late TextEditingController _amountCtrl;
  late TextEditingController _gstPercentCtrl;

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
  }

  void _recalculate() {
    setState(() {
      double subTotal = double.tryParse(_amountCtrl.text) ?? 0.0;
      double percent = double.tryParse(_gstPercentCtrl.text) ?? 0.0;
      _calculatedGstRupees = (subTotal * (percent / 100)).roundToDouble();
      _totalAmount = (subTotal + _calculatedGstRupees).roundToDouble();
    });
  }

  Future<void> _saveAllChanges() async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    final updatedPurchaser = Purchaser(
      id: widget.purchaser.id,
      name: _vendorNameCtrl.text.trim(),
      gstin: _gstinCtrl.text.trim(),
      address1: widget.purchaser.address1, address2: widget.purchaser.address2,
      particulars: widget.purchaser.particulars, hsnNo: widget.purchaser.hsnNo,
      sgstRate: widget.purchaser.sgstRate, cgstRate: widget.purchaser.cgstRate, igstRate: widget.purchaser.igstRate,
      lastUpdated: timestamp, isDeleted: widget.purchaser.isDeleted,
    );

    final updatedInvoice = Invoice(
      id: widget.invoice.id, companyId: widget.company.id, type: 'purchase',
      purchaserId: widget.purchaser.id, billNo: _billNoCtrl.text.trim(),
      billDate: widget.invoice.billDate, truckNo: '', driverName: '', licNo: '', nos: 1, unit: 'NA', quantity: 1,
      rate: double.tryParse(_amountCtrl.text) ?? 0.0,
      amount: double.tryParse(_amountCtrl.text) ?? 0.0,
      labourCharge: 0.0,
      subTotal: double.tryParse(_amountCtrl.text) ?? 0.0,
      gstAmount: _calculatedGstRupees, totalAmount: _totalAmount,
      lastUpdated: timestamp, isDeleted: widget.invoice.isDeleted,
    );

    await ref.read(purchaserProvider.notifier).updatePurchaser(updatedPurchaser);
    await ref.read(invoiceProvider.notifier).updateInvoice(updatedInvoice);
    
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Purchase Bill Updated!')));
  }

  Widget _cell(TextEditingController ctrl, {bool isNum = false, TextAlign align = TextAlign.left, FontWeight fw = FontWeight.normal}) {
    return TextFormField(
      controller: ctrl,
      textAlign: align,
      keyboardType: isNum ? TextInputType.number : TextInputType.text,
      decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
      onChanged: (_) => _recalculate(),
      style: TextStyle(fontWeight: fw, fontSize: 14),
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
              await _saveAllChanges();
              final pdfBytes = await PdfGenerator.generatePurchaseVoucher(widget.invoice, widget.company, widget.purchaser);
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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.redAccent, foregroundColor: Colors.white,
        onPressed: _saveAllChanges,
        icon: const Icon(Icons.save),
        label: const Text('Save Changes'),
      ),
    );
  }
}