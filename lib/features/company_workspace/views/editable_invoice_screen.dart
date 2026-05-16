import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../../../../models/invoice_model.dart';
import '../../../../models/company_model.dart';
import '../../../../models/purchaser_model.dart';
import '../providers/company_provider.dart';
import '../providers/purchaser_provider.dart';
import '../providers/invoice_provider.dart';
import '../../../../core/utils/pdf_generator.dart';
import '../../../../core/utils/number_to_words.dart';

class EditableInvoiceScreen extends ConsumerStatefulWidget {
  final Invoice invoice;
  final Company company;
  final Purchaser purchaser;

  const EditableInvoiceScreen({
    super.key, 
    required this.invoice, 
    required this.company, 
    required this.purchaser
  });

  @override
  ConsumerState<EditableInvoiceScreen> createState() => _EditableInvoiceScreenState();
}

class _EditableInvoiceScreenState extends ConsumerState<EditableInvoiceScreen> {
  late TextEditingController _billNoCtrl;
  late TextEditingController _truckNoCtrl;
  late TextEditingController _driverNameCtrl;
  late TextEditingController _licNoCtrl;
  late TextEditingController _rateCtrl;
  late TextEditingController _qtyCtrl;
  late TextEditingController _nosCtrl; 
  late TextEditingController _labourCtrl;

  late TextEditingController _purNameCtrl;
  late TextEditingController _purAdd1Ctrl;
  late TextEditingController _purAdd2Ctrl;
  late TextEditingController _gstinCtrl;
  
  late TextEditingController _particularsCtrl;
  List<TextEditingController> _extraParticularCtrls = [];

  late TextEditingController _hsnCtrl;
  late TextEditingController _sgstCtrl;
  late TextEditingController _cgstCtrl;
  late TextEditingController _igstCtrl;

  late TextEditingController _compNameCtrl;
  late TextEditingController _compBankCtrl;
  late TextEditingController _compAccCtrl;
  late TextEditingController _compIfscCtrl;

  late double _amount;
  late double _subTotal;
  late double _gstAmount;
  late double _totalAmount;

  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    _billNoCtrl = TextEditingController(text: widget.invoice.billNo);
    _truckNoCtrl = TextEditingController(text: widget.invoice.truckNo);
    _driverNameCtrl = TextEditingController(text: widget.invoice.driverName);
    _licNoCtrl = TextEditingController(text: widget.invoice.licNo);
    _rateCtrl = TextEditingController(text: widget.invoice.rate.toString());
    _qtyCtrl = TextEditingController(text: widget.invoice.quantity.toString());
    _nosCtrl = TextEditingController(text: widget.invoice.nos.toString()); 
    _labourCtrl = TextEditingController(text: widget.invoice.labourCharge.toString());

    _purNameCtrl = TextEditingController(text: widget.purchaser.name);
    _purAdd1Ctrl = TextEditingController(text: widget.purchaser.address1);
    _purAdd2Ctrl = TextEditingController(text: widget.purchaser.address2);
    _gstinCtrl = TextEditingController(text: widget.purchaser.gstin);

    final parts = widget.purchaser.particulars.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (parts.isNotEmpty) {
      _particularsCtrl = TextEditingController(text: parts.first);
      _extraParticularCtrls = parts.skip(1).map((e) => TextEditingController(text: e)).toList();
    } else {
      _particularsCtrl = TextEditingController(text: '');
    }

    _hsnCtrl = TextEditingController(text: widget.purchaser.hsnNo);
    _sgstCtrl = TextEditingController(text: widget.purchaser.sgstRate.toString());
    _cgstCtrl = TextEditingController(text: widget.purchaser.cgstRate.toString());
    _igstCtrl = TextEditingController(text: widget.purchaser.igstRate.toString());

    _compNameCtrl = TextEditingController(text: widget.company.name);
    _compBankCtrl = TextEditingController(text: widget.company.bankName);
    _compAccCtrl = TextEditingController(text: widget.company.accountNumber);
    _compIfscCtrl = TextEditingController(text: widget.company.ifscCode);

    _amount = widget.invoice.amount;
    _subTotal = widget.invoice.subTotal;
    _gstAmount = widget.invoice.gstAmount;
    _totalAmount = widget.invoice.totalAmount;
  }

  @override
  void dispose() {
    _billNoCtrl.dispose();
    _truckNoCtrl.dispose();
    _driverNameCtrl.dispose();
    _licNoCtrl.dispose();
    _rateCtrl.dispose();
    _qtyCtrl.dispose();
    _nosCtrl.dispose(); 
    _labourCtrl.dispose();
    _purNameCtrl.dispose();
    _purAdd1Ctrl.dispose();
    _purAdd2Ctrl.dispose();
    _gstinCtrl.dispose();
    
    _particularsCtrl.dispose();
    for (var ctrl in _extraParticularCtrls) {
      ctrl.dispose();
    }

    _hsnCtrl.dispose();
    _sgstCtrl.dispose();
    _cgstCtrl.dispose();
    _igstCtrl.dispose();
    _compNameCtrl.dispose();
    _compBankCtrl.dispose();
    _compAccCtrl.dispose();
    _compIfscCtrl.dispose();
    super.dispose();
  }

  void _recalculate() {
    setState(() {
      _hasUnsavedChanges = true;

      double rate = double.tryParse(_rateCtrl.text) ?? 0.0;
      double qty = double.tryParse(_qtyCtrl.text) ?? 0.0;
      double labour = double.tryParse(_labourCtrl.text) ?? 0.0;
      
      double sgst = double.tryParse(_sgstCtrl.text) ?? 0.0;
      double cgst = double.tryParse(_cgstCtrl.text) ?? 0.0;
      double igst = double.tryParse(_igstCtrl.text) ?? 0.0;

      _amount = (rate * qty).roundToDouble();
      _subTotal = (_amount + labour).roundToDouble();
      _gstAmount = (_subTotal * ((sgst + cgst + igst) / 100)).roundToDouble();
      _totalAmount = (_subTotal + _gstAmount).roundToDouble();
    });
  }

  Map<String, dynamic> _getCurrentStateData() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    final combinedParticulars = [
      _particularsCtrl.text.trim(),
      ..._extraParticularCtrls.map((c) => c.text.trim())
    ].where((e) => e.isNotEmpty).join(', ');

    final tempInvoice = Invoice(
      id: widget.invoice.id, userId: widget.invoice.userId, companyId: widget.company.id, type: widget.invoice.type,
      purchaserId: widget.purchaser.id, billNo: _billNoCtrl.text.trim(), billDate: widget.invoice.billDate,
      truckNo: _truckNoCtrl.text.trim(), driverName: _driverNameCtrl.text.trim(), licNo: _licNoCtrl.text.trim(),
      nos: int.tryParse(_nosCtrl.text) ?? 1, unit: widget.invoice.unit, quantity: double.tryParse(_qtyCtrl.text) ?? 0.0,
      rate: double.tryParse(_rateCtrl.text) ?? 0.0, amount: _amount, labourCharge: double.tryParse(_labourCtrl.text) ?? 0.0,
      subTotal: _subTotal, gstAmount: _gstAmount, totalAmount: _totalAmount,
      lastUpdated: timestamp, isDeleted: widget.invoice.isDeleted,
    );

    final tempPurchaser = Purchaser(
      id: widget.purchaser.id, userId: widget.purchaser.userId, name: _purNameCtrl.text.trim(), address1: _purAdd1Ctrl.text.trim(),
      address2: _purAdd2Ctrl.text.trim(), particulars: combinedParticulars, gstin: _gstinCtrl.text.trim(),
      hsnNo: _hsnCtrl.text.trim(), sgstRate: double.tryParse(_sgstCtrl.text) ?? 0.0, cgstRate: double.tryParse(_cgstCtrl.text) ?? 0.0,
      igstRate: double.tryParse(_igstCtrl.text) ?? 0.0, lastUpdated: timestamp, isDeleted: widget.purchaser.isDeleted,
    );

    final tempCompany = Company(
      id: widget.company.id, userId: widget.company.userId, name: _compNameCtrl.text.trim(), address1: widget.company.address1,
      address2: widget.company.address2, mobileNumber: widget.company.mobileNumber, bankName: _compBankCtrl.text.trim(),
      accountNumber: _compAccCtrl.text.trim(), ifscCode: _compIfscCtrl.text.trim(), pin: widget.company.pin, gstin: widget.company.gstin,
      lastUpdated: timestamp, isDeleted: widget.company.isDeleted,
    );

    return { 'invoice': tempInvoice, 'company': tempCompany, 'purchaser': tempPurchaser };
  }

  Future<void> _confirmAndSave() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save Changes?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to permanently save these changes to the invoice and database?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Yes, Save')
          ),
        ]
      )
    );
    
    if (confirm == true) {
      final data = _getCurrentStateData();
      
      await ref.read(invoiceProvider.notifier).updateInvoice(data['invoice']);
      await ref.read(purchaserProvider.notifier).updatePurchaser(data['purchaser']);
      await ref.read(companyProvider.notifier).updateCompany(data['company']);
      
      setState(() => _hasUnsavedChanges = false); 
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All Updates Saved!'), backgroundColor: Colors.green));
    }
  }

  Future<bool> _showExitWarningDialog() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('You have unsaved changes. Are you sure you want to discard them and go back?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep Editing', style: TextStyle(color: Colors.blueAccent))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Discard')
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  Widget _tableCell(String text, {bool isHeader = false, TextAlign align = TextAlign.center, double vPad = 6}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: vPad, horizontal: 4),
      child: Text(text, textAlign: align, style: TextStyle(fontWeight: isHeader ? FontWeight.bold : FontWeight.normal, fontSize: 11)),
    );
  }

  Widget _editableCell(TextEditingController controller, {bool isNumber = false, TextAlign align = TextAlign.center, FontWeight weight = FontWeight.normal, double vPad = 6}) {
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
        controller: controller,
        textAlign: align,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        textInputAction: TextInputAction.next, 
        onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
        decoration: InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: vPad, horizontal: 4)),
        onChanged: (_) => _recalculate(),
        style: TextStyle(fontWeight: weight, fontSize: 12),
      ),
    );
  }

  Widget _dynamicParticularsCell() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _editableCell(_particularsCtrl, weight: FontWeight.bold, align: TextAlign.left, vPad: 2)),
              InkWell(
                onTap: () {
                  setState(() {
                    _extraParticularCtrls.add(TextEditingController());
                    _hasUnsavedChanges = true;
                  });
                },
                child: const Icon(Icons.add_circle, color: Colors.blueAccent, size: 16),
              )
            ],
          ),
          ...List.generate(_extraParticularCtrls.length, (index) {
            return Row(
              children: [
                Expanded(child: _editableCell(_extraParticularCtrls[index], weight: FontWeight.bold, align: TextAlign.left, vPad: 2)),
                InkWell(
                  onTap: () {
                    setState(() {
                      _extraParticularCtrls[index].dispose();
                      _extraParticularCtrls.removeAt(index);
                      _hasUnsavedChanges = true;
                    });
                  },
                  child: const Icon(Icons.remove_circle, color: Colors.redAccent, size: 16),
                )
              ],
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double sgstAmt = (_subTotal * (double.tryParse(_sgstCtrl.text) ?? 0) / 100).roundToDouble();
    double cgstAmt = (_subTotal * (double.tryParse(_cgstCtrl.text) ?? 0) / 100).roundToDouble();
    double igstAmt = (_subTotal * (double.tryParse(_igstCtrl.text) ?? 0) / 100).roundToDouble();

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldPop = await _showExitWarningDialog();
        if (shouldPop && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Edit Bill #${widget.invoice.billNo}'),
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.print),
              tooltip: 'Print Preview',
              onPressed: () async {
                final currentData = _getCurrentStateData(); 
                final pdfBytes = await PdfGenerator.generateInvoice(
                  currentData['invoice'], 
                  currentData['company'], 
                  currentData['purchaser']
                );
                await Printing.layoutPdf(onLayout: (format) async => pdfBytes, name: 'Invoice_${widget.invoice.billNo}.pdf');
              },
            )
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(
            decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 2)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- HEADER BLOCK ---
                Table(
                  border: const TableBorder(horizontalInside: BorderSide(color: Colors.black), verticalInside: BorderSide(color: Colors.black)),
                  columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(5), 2: FlexColumnWidth(2), 3: FlexColumnWidth(3)},
                  children: [
                    TableRow(children: [_tableCell('PARTY NAME', isHeader: true, align: TextAlign.left), _editableCell(_purNameCtrl, weight: FontWeight.bold), _tableCell('BILL NO.', isHeader: true), _editableCell(_billNoCtrl, weight: FontWeight.bold)]),
                    TableRow(children: [_tableCell('ADDRESS', isHeader: true, align: TextAlign.left), _editableCell(_purAdd1Ctrl), _tableCell('TRUCK NO.', isHeader: true), _editableCell(_truckNoCtrl)]),
                    TableRow(children: [const SizedBox(), _editableCell(_purAdd2Ctrl), const SizedBox(), const SizedBox()]),
                    TableRow(children: [_tableCell('GST IN.', isHeader: true, align: TextAlign.left), _editableCell(_gstinCtrl, weight: FontWeight.bold), const SizedBox(), const SizedBox()]),
                  ],
                ),
                
                // --- MAIN ITEMS & LABOUR TABLE ---
                Table(
                  border: const TableBorder(top: BorderSide(color: Colors.black, width: 2), verticalInside: BorderSide(color: Colors.black)),
                  columnWidths: const {
                    0: FlexColumnWidth(4.0), 1: FlexColumnWidth(1.5), 2: FlexColumnWidth(1.0),
                    3: FlexColumnWidth(1.5), 4: FlexColumnWidth(1.5), 5: FlexColumnWidth(2.0),
                  },
                  children: [
                    TableRow(
                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(width: 2))),
                      children: [_tableCell('PERTICULARS', isHeader: true), _tableCell('HSN NO.', isHeader: true), _tableCell('NOS.', isHeader: true), _tableCell(widget.invoice.unit.toUpperCase(), isHeader: true), _tableCell('RATE', isHeader: true), _tableCell('AMOUNTS.', isHeader: true)]
                    ),
                    TableRow(
                      children: [
                        _dynamicParticularsCell(),
                        _editableCell(_hsnCtrl, weight: FontWeight.bold),
                        _editableCell(_nosCtrl, isNumber: true, weight: FontWeight.bold),
                        _editableCell(_qtyCtrl, isNumber: true, weight: FontWeight.bold),
                        _editableCell(_rateCtrl, isNumber: true, weight: FontWeight.bold),
                        _tableCell(_amount.toStringAsFixed(0), isHeader: true),
                      ]
                    ),
                    TableRow(
                      children: [
                        _tableCell('LABOUR CHARGE', isHeader: true, align: TextAlign.left),
                        const SizedBox(), const SizedBox(), const SizedBox(), const SizedBox(),
                        _editableCell(_labourCtrl, isNumber: true, weight: FontWeight.bold),
                      ]
                    )
                  ],
                ),
                
                // --- SUB TOTAL TABLE ---
                Table(
                  border: const TableBorder(top: BorderSide(color: Colors.black, width: 2), verticalInside: BorderSide(color: Colors.black)),
                  columnWidths: const {0: FlexColumnWidth(9.5), 1: FlexColumnWidth(2.0)},
                  children: [
                    TableRow(
                      children: [_tableCell('SUB TOTAL', isHeader: true, align: TextAlign.right), _tableCell(_subTotal.toStringAsFixed(0), isHeader: true)]
                    )
                  ]
                ),

                // --- SLIM GST ROWS ---
                Table(
                  border: const TableBorder(top: BorderSide(color: Colors.black, width: 2), verticalInside: BorderSide(color: Colors.black)),
                  columnWidths: const {
                    0: FlexColumnWidth(6.5), 1: FlexColumnWidth(1.5), 
                    2: FlexColumnWidth(1.5), 3: FlexColumnWidth(2.0),
                  },
                  children: [
                    TableRow(
                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black12))),
                      children: [
                        _tableCell('', vPad: 2), _tableCell('SGST', isHeader: true, vPad: 2), 
                        _editableCell(_sgstCtrl, isNumber: true, weight: FontWeight.bold, vPad: 2), _tableCell(sgstAmt.toStringAsFixed(0), isHeader: true, vPad: 2)
                      ]
                    ),
                    TableRow(
                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black12))),
                      children: [
                        _tableCell('', vPad: 2), _tableCell('CGST', isHeader: true, vPad: 2), 
                        _editableCell(_cgstCtrl, isNumber: true, weight: FontWeight.bold, vPad: 2), _tableCell(cgstAmt.toStringAsFixed(0), isHeader: true, vPad: 2)
                      ]
                    ),
                    TableRow(
                      children: [
                        _tableCell('', vPad: 2), _tableCell('IGST', isHeader: true, vPad: 2), 
                        _editableCell(_igstCtrl, isNumber: true, weight: FontWeight.bold, vPad: 2), _tableCell(igstAmt.toStringAsFixed(0), isHeader: true, vPad: 2)
                      ]
                    ),
                  ]
                ),

                // --- TOTAL AMOUNT ROW ---
                Table(
                  border: const TableBorder(top: BorderSide(color: Colors.black, width: 2), bottom: BorderSide(color: Colors.black, width: 2), verticalInside: BorderSide(color: Colors.black)),
                  columnWidths: const {0: FlexColumnWidth(9.5), 1: FlexColumnWidth(2.0)},
                  children: [
                    TableRow(
                      children: [
                        const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('TOTAL AMOUNT', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue))),
                        Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(_totalAmount.toStringAsFixed(0), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue))),
                      ]
                    )
                  ]
                ),

                // --- VALUE IN WORD ---
                Table(
                  border: const TableBorder(bottom: BorderSide(color: Colors.black, width: 2), verticalInside: BorderSide(color: Colors.black)),
                  columnWidths: const {0: FlexColumnWidth(2.5), 1: FlexColumnWidth(9.0)},
                  children: [
                    TableRow(children: [_tableCell('VALUE IN WORD', isHeader: true), _tableCell('Rupees ${NumberToWords.convert(_totalAmount.round())} Only', align: TextAlign.left, isHeader: true)])
                  ]
                ),

                // --- FOOTER ---
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 40,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Table(
                            border: const TableBorder(right: BorderSide(width: 2), bottom: BorderSide(width: 2), horizontalInside: BorderSide(color: Colors.black), verticalInside: BorderSide(color: Colors.black)),
                            columnWidths: const {0: FlexColumnWidth(1.5), 1: FlexColumnWidth(2.5)},
                            children: [
                              TableRow(children: [_tableCell('DRIVER NAME', isHeader: true), _editableCell(_driverNameCtrl)]),
                              TableRow(children: [_tableCell('LIC NO.', isHeader: true), _editableCell(_licNoCtrl)]),
                            ]
                          ),
                          
                          const SizedBox(height: 12),
                          
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              border: Border(top: BorderSide(width: 2), right: BorderSide(width: 2), bottom: BorderSide(width: 2))
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text('BANK DETAIL :-', style: TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.underline, fontSize: 11)),
                                const SizedBox(height: 4),
                                _editableCell(_compBankCtrl, weight: FontWeight.bold),
                                Row(children: [const Text('A/C NO.:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)), Expanded(child: _editableCell(_compAccCtrl, weight: FontWeight.bold))]),
                                Row(children: [const Text('IFSC:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)), Expanded(child: _editableCell(_compIfscCtrl, weight: FontWeight.bold))]),
                              ],
                            ),
                          ),
                        ],
                      )
                    ),
                    const Expanded(flex: 75, child: SizedBox()),
                  ],
                ),
                
                // --- FULL WIDTH SIGNATURE ROW ---
                Container(
                  height: 80,
                  padding: const EdgeInsets.only(right: 16, bottom: 8),
                  alignment: Alignment.bottomRight,
                  decoration: const BoxDecoration(border: Border(top: BorderSide(width: 2))),
                  child: Text('FOR, ${widget.company.name.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                )

              ],
            ),
          ),
        ),
        
        // --- RESPONSIVE SINGLE ROW BUTTONS ---
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
            child: Row(
              children: [
                Expanded(
                  child: FloatingActionButton.extended(
                    heroTag: 'download_btn_sales', 
                    backgroundColor: Colors.blueGrey, 
                    foregroundColor: Colors.white,
                    onPressed: () async {
                      final currentData = _getCurrentStateData(); 
                      final pdfBytes = await PdfGenerator.generateInvoice(
                        currentData['invoice'], 
                        currentData['company'], 
                        currentData['purchaser']
                      );
                      await Printing.sharePdf(
                        bytes: pdfBytes, 
                        filename: 'Invoice_${widget.invoice.billNo}.pdf'
                      );
                    },
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const FittedBox(child: Text('Download', style: TextStyle(fontWeight: FontWeight.bold))),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FloatingActionButton.extended(
                    heroTag: 'view_btn_sales',
                    backgroundColor: Colors.indigoAccent, 
                    foregroundColor: Colors.white,
                    onPressed: () {
                      final currentData = _getCurrentStateData();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => InvoicePreviewScreen(
                            invoice: currentData['invoice'],
                            company: currentData['company'],
                            purchaser: currentData['purchaser'],
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.visibility, size: 18),
                    label: const FittedBox(child: Text('View Bill', style: TextStyle(fontWeight: FontWeight.bold))),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FloatingActionButton.extended(
                    heroTag: 'save_btn_sales',
                    backgroundColor: Colors.blueAccent, 
                    foregroundColor: Colors.white,
                    onPressed: _confirmAndSave,
                    icon: const Icon(Icons.save, size: 18),
                    label: const FittedBox(child: Text('Save', style: TextStyle(fontWeight: FontWeight.bold))),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- CUSTOM PREVIEW SCREEN WIDGET ---
class InvoicePreviewScreen extends StatelessWidget {
  final Invoice invoice;
  final Company company;
  final Purchaser purchaser;

  const InvoicePreviewScreen({
    super.key, 
    required this.invoice, 
    required this.company, 
    required this.purchaser
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC), 
      appBar: AppBar(
        title: Text('Bill #${invoice.billNo} Preview'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade800, Colors.blue.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share Bill',
            onPressed: () async {
              final pdfBytes = await PdfGenerator.generateInvoice(invoice, company, purchaser);
              await Printing.sharePdf(
                bytes: pdfBytes, 
                filename: 'Invoice_${invoice.billNo}.pdf'
              );
            },
          ),
        ],
      ),
      
      body: PdfPreview(
        build: (format) => PdfGenerator.generateInvoice(invoice, company, purchaser),
        useActions: false, 
        canChangeOrientation: false,
        canChangePageFormat: false,
        pdfFileName: 'Invoice_${invoice.billNo}.pdf',
        previewPageMargin: const EdgeInsets.all(16), 
      ),
      
      // --- PREMIUM GRADIENT BOTTOM BAR ---
      bottomNavigationBar: SafeArea(
        child: Container(
          height: 70, 
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade800, Colors.blue.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, -2))
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditableInvoiceScreen(
                            invoice: invoice,
                            company: company,
                            purchaser: purchaser,
                          ),
                        ),
                      );
                    },
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.edit_document, color: Colors.white, size: 26),
                        SizedBox(height: 4),
                        Text('Edit Bill', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.white30), 

                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final pdfBytes = await PdfGenerator.generateInvoice(invoice, company, purchaser);
                      await Printing.layoutPdf(
                        onLayout: (format) async => pdfBytes, 
                        name: 'Invoice_${invoice.billNo}.pdf',
                        usePrinterSettings: true, 
                        dynamicLayout: false,
                      );
                    },
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.print, color: Colors.white, size: 26),
                        SizedBox(height: 4),
                        Text('Print', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.white30), 

                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final pdfBytes = await PdfGenerator.generateInvoice(invoice, company, purchaser);
                      await Printing.sharePdf(
                        bytes: pdfBytes, 
                        filename: 'Invoice_${invoice.billNo}.pdf'
                      );
                    },
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.download_rounded, color: Colors.white, size: 26),
                        SizedBox(height: 4),
                        Text('Download', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}