import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../../models/invoice_model.dart';
import '../../models/company_model.dart';
import '../../models/purchaser_model.dart';
import 'number_to_words.dart';

class PdfGenerator {
  // ─── 1. PIXEL PERFECT SALES INVOICE ───
  static Future<Uint8List> generateInvoice(
      Invoice invoice, Company company, Purchaser purchaser) async {
    final pdf = pw.Document();

    // --- FONT LOADING WITH SAFE FALLBACKS ---
    pw.Font baseFont = pw.Font.times();
    pw.Font boldFont = pw.Font.timesBold();
    pw.Font aharoniFont = pw.Font.helveticaBold();
    pw.Font copperplateFont = pw.Font.helveticaBold();

    try { baseFont = pw.Font.ttf(await rootBundle.load('assets/fonts/BookmanOldStyle.ttf')); } catch (_) {}
    try { boldFont = pw.Font.ttf(await rootBundle.load('assets/fonts/BookmanOldStyleBold.ttf')); } catch (_) {}
    try { aharoniFont = pw.Font.ttf(await rootBundle.load('assets/fonts/Aharoni.ttf')); } catch (_) {}
    try { copperplateFont = pw.Font.ttf(await rootBundle.load('assets/fonts/CopperplateGothicBold.ttf')); } catch (_) {}


    final dateString = DateFormat('dd-MM-yyyy')
        .format(DateTime.fromMillisecondsSinceEpoch(invoice.billDate));

    // Reusable border sides
    const pw.BorderSide heavyBorder = pw.BorderSide(width: 2);
    const pw.BorderSide lightBorder = pw.BorderSide(width: 1);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        // Sets the default font for the entire page to Bookman
        theme: pw.ThemeData.withFont(
          base: baseFont,
          bold: boldFont,
        ),
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(border: pw.Border.all(width: 2)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [

                // ── 1. JAY GURU MAHARAJ (AHARONI) ──
                pw.Container(
                  decoration: const pw.BoxDecoration(border: pw.Border(bottom: heavyBorder)),
                  padding: const pw.EdgeInsets.symmetric(vertical: 2), // Reduced
                  child: pw.Text(
                    '\\\\ JAY GURU MAHARAJ \\\\',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(font: aharoniFont, fontWeight: pw.FontWeight.bold, fontSize: 10),
                  ),
                ),

                // ── 2. TAX / RETAIL INVOICE ──
                pw.Container(
                  decoration: const pw.BoxDecoration(border: pw.Border(bottom: heavyBorder)),
                  padding: const pw.EdgeInsets.symmetric(vertical: 1), // Reduced
                  child: pw.Text(
                    'TAX / RETAIL INVOICE',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                  ),
                ),

                // ── 3. ORIGINAL / DUPLICATE / REPLICATE ──
                pw.Container(
                  decoration: const pw.BoxDecoration(border: pw.Border(bottom: heavyBorder)),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Container(
                          padding: const pw.EdgeInsets.symmetric(vertical: 1), // Reduced
                          decoration: const pw.BoxDecoration(border: pw.Border(right: lightBorder)),
                          child: pw.Text('ORIGINAL', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Container(
                          padding: const pw.EdgeInsets.symmetric(vertical: 1), // Reduced
                          decoration: const pw.BoxDecoration(border: pw.Border(right: lightBorder)),
                          child: pw.Text('DUPLICATE', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Container(
                          padding: const pw.EdgeInsets.symmetric(vertical: 1), // Reduced
                          child: pw.Text('REIPLICATE', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── 4. COMPANY NAME (COPPERPLATE GOTHIC BOLD) ──
                pw.Container(
                  decoration: const pw.BoxDecoration(border: pw.Border(bottom: lightBorder)),
                  padding: const pw.EdgeInsets.symmetric(vertical: 0), // Extensively Reduced
                  child: pw.Text(
                    company.name.toUpperCase(),
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(font: copperplateFont, fontSize: 30, fontWeight: pw.FontWeight.bold),
                  ),
                ),

                // ── 5. ADDRESS 1 ──
                pw.Container(
                  decoration: const pw.BoxDecoration(border: pw.Border(bottom: lightBorder)),
                  padding: const pw.EdgeInsets.symmetric(vertical: 0), // Tight
                  child: pw.Text(
                    company.address1.toUpperCase(),
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                  ),
                ),

                // ── 6. ADDRESS 2 ──
                pw.Container(
                  decoration: const pw.BoxDecoration(border: pw.Border(bottom: lightBorder)),
                  padding: const pw.EdgeInsets.symmetric(vertical: 0), // Tight
                  child: pw.Text(
                    company.address2.toUpperCase(),
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                  ),
                ),

                // ── 7. GST NO ──
                pw.Container(
                  decoration: const pw.BoxDecoration(border: pw.Border(bottom: lightBorder)),
                  padding: const pw.EdgeInsets.symmetric(vertical: 1), // Reduced
                  child: pw.Text(
                    'GST NO: ${company.gstin}'.toUpperCase(),
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                  ),
                ),

                // ── 8. Mobile ──
                pw.Container(
                  decoration: const pw.BoxDecoration(border: pw.Border(bottom: heavyBorder)),
                  padding: const pw.EdgeInsets.symmetric(vertical: 1), // Reduced
                  child: pw.Text(
                    'MO. ${company.mobileNumber}'.toUpperCase(),
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                  ),
                ),

                // ── NEW: EMPTY ROW BEFORE PARTY DETAILS ──
                pw.Container(
                  height: 13,
                  decoration: const pw.BoxDecoration(border: pw.Border(bottom: heavyBorder)),
                ),

                // ── 9. PARTY DETAILS TABLE ──
                pw.Table(
                  border: const pw.TableBorder(
                    bottom: heavyBorder,
                    horizontalInside: lightBorder,
                    verticalInside: heavyBorder,
                  ),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2),
                    1: const pw.FlexColumnWidth(5),
                    2: const pw.FlexColumnWidth(2),
                    3: const pw.FlexColumnWidth(3),
                  },
                  children: [
                    pw.TableRow(children: [
                      _cell('PARTY NAME', underline: true, align: pw.TextAlign.center),
                      _cell(purchaser.name.toUpperCase(), align: pw.TextAlign.center),
                      _cell('BILL NO.', align: pw.TextAlign.center),
                      _cell(invoice.billNo.toUpperCase(), fontSize: 14, align: pw.TextAlign.center),
                    ]),
                    pw.TableRow(children: [
                      _cell('ADDRESS', underline: true, align: pw.TextAlign.center),
                      _cell(purchaser.address1.toUpperCase(), align: pw.TextAlign.center),
                      _cell('BILL DATE', align: pw.TextAlign.center),
                      _cell(dateString, align: pw.TextAlign.center),
                    ]),
                    pw.TableRow(children: [
                      _cell('GST NO.', align: pw.TextAlign.center),
                      _cell(purchaser.address2.toUpperCase(), align: pw.TextAlign.center),
                      _cell('TRUCK NO.', align: pw.TextAlign.center),
                      _cell(invoice.truckNo.toUpperCase(), fontSize: 13, align: pw.TextAlign.center),
                    ]),
                    pw.TableRow(children: [
                      _cell('GST IN.', underline: true, align: pw.TextAlign.center),
                      _cell(purchaser.gstin.toUpperCase(), fontSize: 12, align: pw.TextAlign.center),
                      _cell('', align: pw.TextAlign.center),
                      _cell('', align: pw.TextAlign.center),
                    ]),
                  ],
                ),

                // ── NEW: EMPTY ROW BEFORE MAIN ITEMS ──
                pw.Container(
                  height: 13,
                  decoration: const pw.BoxDecoration(border: pw.Border(bottom: heavyBorder)),
                ),

                // ── 10. MAIN ITEMS TABLE ──
                pw.Table(
                  border: const pw.TableBorder(verticalInside: heavyBorder),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(4.0), 
                    1: const pw.FlexColumnWidth(1.5), 
                    2: const pw.FlexColumnWidth(1.0), 
                    3: const pw.FlexColumnWidth(1.5), 
                    4: const pw.FlexColumnWidth(1.5), 
                    5: const pw.FlexColumnWidth(2.0), 
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(border: pw.Border(bottom: heavyBorder)),
                      children: [
                        // Headers get a little padding to stand out
                        _cell('PERTICULARS', underline: true, align: pw.TextAlign.center, verticalPadding: 4),
                        _cell('HSN NO.', underline: true, align: pw.TextAlign.center, verticalPadding: 4),
                        _cell('NOS.', underline: true, align: pw.TextAlign.center, verticalPadding: 4),
                        _cell(invoice.unit.toUpperCase(), underline: true, align: pw.TextAlign.center, verticalPadding: 4),
                        _cell('RATE', underline: true, align: pw.TextAlign.center, verticalPadding: 4),
                        _cell('AMOUNTS.', underline: true, align: pw.TextAlign.center, verticalPadding: 4),
                      ],
                    ),
                    
                    pw.TableRow(
                      children: [
                        // --- ITEM ROW: HEAVILY INCREASED PADDING HERE ---
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                          child: pw.Text(
                            purchaser.particulars.toUpperCase(),
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                          ),
                        ),
                        _cell(purchaser.hsnNo.toUpperCase(), align: pw.TextAlign.center, verticalPadding: 12),
                        _cell(invoice.nos.toString(), align: pw.TextAlign.center, verticalPadding: 12),
                        _cell(invoice.quantity.toStringAsFixed(2), align: pw.TextAlign.center, verticalPadding: 12),
                        _cell(invoice.rate.toStringAsFixed(2), align: pw.TextAlign.center, verticalPadding: 12),
                        _cell(invoice.amount.toStringAsFixed(0), align: pw.TextAlign.center, verticalPadding: 12),
                      ],
                    ),
                  ],
                ),

                // ── 11. DYNAMIC GAP ROW (Pushes Footer to Bottom) ──
                pw.Expanded(
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      pw.Expanded(flex: 40, child: pw.Container(decoration: const pw.BoxDecoration(border: pw.Border(right: heavyBorder)))),
                      pw.Expanded(flex: 15, child: pw.Container(decoration: const pw.BoxDecoration(border: pw.Border(right: heavyBorder)))),
                      pw.Expanded(flex: 10, child: pw.Container(decoration: const pw.BoxDecoration(border: pw.Border(right: heavyBorder)))),
                      pw.Expanded(flex: 15, child: pw.Container(decoration: const pw.BoxDecoration(border: pw.Border(right: heavyBorder)))),
                      pw.Expanded(flex: 15, child: pw.Container(decoration: const pw.BoxDecoration(border: pw.Border(right: heavyBorder)))),
                      pw.Expanded(flex: 20, child: pw.Container()),
                    ],
                  ),
                ),

                // ── 12. LABOUR CHARGE ──
                pw.Table(
                  border: const pw.TableBorder(verticalInside: heavyBorder),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(4.0),
                    1: const pw.FlexColumnWidth(1.5),
                    2: const pw.FlexColumnWidth(1.0),
                    3: const pw.FlexColumnWidth(1.5),
                    4: const pw.FlexColumnWidth(1.5),
                    5: const pw.FlexColumnWidth(2.0),
                  },
                  children: [
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                          child: pw.Text(
                            'LABOUR CHARGE',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                          ),
                        ),
                        _cell(''), _cell(''), _cell(''), _cell(''),
                        _cell(invoice.labourCharge.toStringAsFixed(0), align: pw.TextAlign.center),
                      ]
                    ),
                  ]
                ),

                // ── 13. SUB TOTAL ──
                pw.Table(
                  border: const pw.TableBorder(top: heavyBorder, verticalInside: heavyBorder),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(9.5),
                    1: const pw.FlexColumnWidth(2.0),
                  },
                  children: [
                    pw.TableRow(
                      children: [
                        _cell('SUB TOTAL', align: pw.TextAlign.center, fontSize: 12, verticalPadding: 2),
                        _cell(invoice.subTotal.toStringAsFixed(0), align: pw.TextAlign.center, fontSize: 14, verticalPadding: 2),
                      ]
                    ),
                  ]
                ),

                // ── 14. GST ROWS ──
                pw.Table(
                  border: const pw.TableBorder(top: heavyBorder, verticalInside: heavyBorder),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(6.5), 
                    1: const pw.FlexColumnWidth(1.5),
                    2: const pw.FlexColumnWidth(1.5),
                    3: const pw.FlexColumnWidth(2.0),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(border: pw.Border(bottom: lightBorder)),
                      children: [
                        _cell('', verticalPadding: 0), 
                        _cell('SGST', align: pw.TextAlign.center, verticalPadding: 0),
                        _cell('${purchaser.sgstRate.toStringAsFixed(2)}%', align: pw.TextAlign.center, verticalPadding: 0),
                        _cell((invoice.subTotal * (purchaser.sgstRate / 100)).round().toString(), align: pw.TextAlign.center, verticalPadding: 0),
                      ]
                    ),
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(border: pw.Border(bottom: lightBorder)),
                      children: [
                        _cell('', verticalPadding: 0), 
                        _cell('CGST', align: pw.TextAlign.center, verticalPadding: 0),
                        _cell('${purchaser.cgstRate.toStringAsFixed(2)}%', align: pw.TextAlign.center, verticalPadding: 0),
                        _cell((invoice.subTotal * (purchaser.cgstRate / 100)).round().toString(), align: pw.TextAlign.center, verticalPadding: 0),
                      ]
                    ),
                    pw.TableRow(
                      children: [
                        _cell('', verticalPadding: 0), 
                        _cell('IGST', align: pw.TextAlign.center, verticalPadding: 0),
                        _cell('${purchaser.igstRate.toStringAsFixed(2)}%', align: pw.TextAlign.center, verticalPadding: 0),
                        _cell((invoice.subTotal * (purchaser.igstRate / 100)).round().toString(), align: pw.TextAlign.center, verticalPadding: 0),
                      ]
                    ),
                  ],
                ),

                // ── 15. TOTAL AMOUNT ROW ──
                pw.Table(
                  border: const pw.TableBorder(
                    top: heavyBorder,
                    bottom: heavyBorder,
                    verticalInside: heavyBorder,
                  ),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(9.5),
                    1: const pw.FlexColumnWidth(2.0),
                  },
                  children: [
                    pw.TableRow(children: [
                      _cell('TOTAL AMOUNT', align: pw.TextAlign.center, fontSize: 12, verticalPadding: 2),
                      _cell(invoice.totalAmount.toStringAsFixed(0), align: pw.TextAlign.center, fontSize: 14, verticalPadding: 2),
                    ]),
                  ],
                ),

                // ── 16. VALUE IN WORD ──
                pw.Table(
                  border: const pw.TableBorder(bottom: heavyBorder, verticalInside: heavyBorder),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2.5),
                    1: const pw.FlexColumnWidth(9.0),
                  },
                  children: [
                    pw.TableRow(children: [
                      _cell('VALUE IN WORD', align: pw.TextAlign.center),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(2),
                        child: pw.Text(
                          'Rupees ${NumberToWords.convert(invoice.totalAmount.round())} Only',
                          textAlign: pw.TextAlign.left,
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                    ]),
                  ],
                ),

                // ── 17. FOOTER (DRIVER/LIC + BANK DETAILS + SIGNATURE) ──
                // Unchanged to protect original spacing
                pw.Container(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Expanded(
                            flex: 40,
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                              children: [
                                pw.Table(
                                  border: const pw.TableBorder(right: heavyBorder, bottom: heavyBorder, verticalInside: heavyBorder, horizontalInside: heavyBorder),
                                  columnWidths: {
                                    0: const pw.FlexColumnWidth(1.5),
                                    1: const pw.FlexColumnWidth(2.5),
                                  },
                                  children: [
                                    pw.TableRow(children: [
                                      _cell('DRIVER NAME', align: pw.TextAlign.center, verticalPadding: 2),
                                      _cell(invoice.driverName.toUpperCase(), align: pw.TextAlign.center, verticalPadding: 2),
                                    ]),
                                    pw.TableRow(children: [
                                      _cell('LIC NO.', align: pw.TextAlign.center, verticalPadding: 2),
                                      _cell(invoice.licNo.toUpperCase(), align: pw.TextAlign.center, verticalPadding: 2),
                                    ]),
                                  ],
                                ),
                                pw.SizedBox(height: 8),
                                pw.Container(
                                  padding: const pw.EdgeInsets.all(6),
                                  decoration: const pw.BoxDecoration(
                                    border: pw.Border(top: heavyBorder, right: heavyBorder, bottom: heavyBorder)
                                  ),
                                  child: pw.Column(
                                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                                    children: [
                                      pw.Text('BANK DETAIL :-', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline, fontSize: 10)),
                                      pw.SizedBox(height: 4),
                                      pw.Text(company.bankName.toUpperCase(), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                                      pw.Text('A/C NO. :- ${company.accountNumber}'.toUpperCase(), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                                      pw.Text('IFSC CODE :- ${company.ifscCode}'.toUpperCase(), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                                    ],
                                  ),
                                ),
                                pw.SizedBox(height: 12),
                              ]
                            ),
                          ),
                          pw.Expanded(
                            flex: 75,
                            child: pw.Container()
                          ),
                        ],
                      ),
                      pw.Container(
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(top: heavyBorder),
                        ),
                        height: 70, 
                        padding: const pw.EdgeInsets.only(right: 12, bottom: 4),
                        alignment: pw.Alignment.bottomRight,
                        child: pw.Text(
                          'FOR, ${company.name.toUpperCase()}',
                          style: pw.TextStyle(font: copperplateFont, fontWeight: pw.FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                
              ],
            ),
          );
        },
      ),
    );

    return await pdf.save();
  }

  // ─── 2. PURCHASE VOUCHER GENERATOR ───
  static Future<Uint8List> generatePurchaseVoucher(
      Invoice invoice, Company company, Purchaser purchaser) async {
    final pdf = pw.Document();

    pw.Font baseFont = pw.Font.times();
    pw.Font boldFont = pw.Font.timesBold();
    try { baseFont = pw.Font.ttf(await rootBundle.load('assets/fonts/BookmanOldStyle.ttf')); } catch (_) {}
    try { boldFont = pw.Font.ttf(await rootBundle.load('assets/fonts/BookmanOldStyleBold.ttf')); } catch (_) {}

    final dateString = DateFormat('dd-MM-yyyy')
        .format(DateTime.fromMillisecondsSinceEpoch(invoice.billDate));

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(
          base: baseFont,
          bold: boldFont,
        ),
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(border: pw.Border.all(width: 2)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Container(
                  color: PdfColors.grey200,
                  padding: const pw.EdgeInsets.all(12),
                  child: pw.Column(
                    children: [
                      pw.Text(company.name.toUpperCase(), style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                      pw.Text('INBOUND PURCHASE VOUCHER', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
                    ]
                  )
                ),
                pw.Divider(height: 0, thickness: 2),

                pw.Padding(
                  padding: const pw.EdgeInsets.all(16),
                  child: pw.Table(
                    columnWidths: {0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(7)},
                    children: [
                      pw.TableRow(children: [pw.Text('VENDOR NAME:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.Text(purchaser.name.toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold))]),
                      pw.TableRow(children: [pw.SizedBox(height: 8), pw.SizedBox(height: 8)]),
                      
                      pw.TableRow(children: [pw.Text('VENDOR GSTIN:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.Text(purchaser.gstin.isEmpty ? 'N/A' : purchaser.gstin.toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold))]),
                      pw.TableRow(children: [pw.Text('SUPPLIER BILL NO:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.Text(invoice.billNo, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))]),
                      pw.TableRow(children: [pw.Text('ENTRY DATE:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.Text(dateString, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))]),
                    ]
                  )
                ),
                pw.Divider(height: 0, thickness: 2),

                pw.Padding(
                  padding: const pw.EdgeInsets.all(16),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('AMOUNT (W/O GST):', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.Text(invoice.subTotal.toStringAsFixed(0), style: pw.TextStyle(fontWeight: pw.FontWeight.bold))]),
                      pw.SizedBox(height: 8),
                      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('GST APPLIED:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.Text(invoice.gstAmount.toStringAsFixed(0), style: pw.TextStyle(fontWeight: pw.FontWeight.bold))]),
                      pw.Divider(thickness: 1),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, 
                        children: [
                          pw.Text('TOTAL EXPENSE:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)), 
                          pw.Text('Rs. ${invoice.totalAmount.toStringAsFixed(0)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16))
                        ]
                      ),
                    ]
                  )
                )
              ]
            )
          );
        },
      ),
    );
    return await pdf.save();
  }

  // ─── 3. CELL HELPER (DEFAULT PADDING CHANGED FROM 2 TO 0) ───
  static pw.Widget _cell(
    String text, {
    bool underline = false,
    pw.TextAlign align = pw.TextAlign.center,
    double fontSize = 10,
    pw.BoxDecoration? decoration,
    double verticalPadding = 0, // <-- Default is now completely tight
  }) {
    return pw.Container(
      decoration: decoration,
      padding: pw.EdgeInsets.symmetric(vertical: verticalPadding, horizontal: 5),
      alignment: align == pw.TextAlign.right
          ? pw.Alignment.centerRight
          : (align == pw.TextAlign.left ? pw.Alignment.centerLeft : pw.Alignment.center),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold, 
          decoration: underline ? pw.TextDecoration.underline : pw.TextDecoration.none,
          fontSize: fontSize,
        ),
      ),
    );
  }
}