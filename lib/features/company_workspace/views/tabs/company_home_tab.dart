import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart'; 
import 'dart:math' as math;

import '../../../../models/purchaser_model.dart'; 
import '../../providers/company_provider.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/payment_provider.dart';
import '../../providers/purchaser_provider.dart';
import '../edit_company_screen.dart';
import '../../../dashboard/global_dashboard_screen.dart'; 

class CompanyHomeTab extends ConsumerStatefulWidget {
  const CompanyHomeTab({super.key});

  @override
  ConsumerState<CompanyHomeTab> createState() => _CompanyHomeTabState();
}

class _CompanyHomeTabState extends ConsumerState<CompanyHomeTab> {
  String _analyticsFilter = 'Both'; // Both, Sales, Purchase

  // --- COMMA FORMATTER (Indian format with trailing /-) ---
  String formatAmount(double val) {
    // Uses en_IN for Indian comma placements, rounded to 0 decimal places
    final formatter = NumberFormat.decimalPattern('en_IN');
    return '${formatter.format(val.round())}/-';
  }

  @override
  Widget build(BuildContext context) {
    final company = ref.watch(activeCompanyProvider);
    final allInvoices = ref.watch(invoiceProvider);
    final allPayments = ref.watch(paymentProvider);
    final allPurchasers = ref.watch(purchaserProvider);

    if (company == null) return const Center(child: Text('Loading...'));

    final now = DateTime.now();

    // --- 1. KPI CALCULATION ---
    final startOfDay = DateTime(now.year, now.month, now.day);
    final startOfMonth = DateTime(now.year, now.month, 1);
    double todayAmount = 0.0;
    double monthAmount = 0.0;

    for (var inv in allInvoices) {
      if (_analyticsFilter == 'Sales' && inv.type != 'sales') continue;
      if (_analyticsFilter == 'Purchase' && inv.type != 'purchase') continue;

      final invDate = DateTime.fromMillisecondsSinceEpoch(inv.billDate);
      double impact = inv.totalAmount;
      if (_analyticsFilter == 'Both' && inv.type == 'purchase') impact = -impact;

      if (!invDate.isBefore(startOfDay)) todayAmount += impact;
      if (!invDate.isBefore(startOfMonth)) monthAmount += impact;
    }

    // --- 2. BAR CHART CALCULATION (Last 6 Months) ---
    List<String> monthLabels = List.generate(6, (i) => DateFormat('MMM').format(DateTime(now.year, now.month - 5 + i)));
    List<double> monthlySales = List.filled(6, 0.0);
    List<double> monthlyPurchases = List.filled(6, 0.0);
    double maxChartValue = 1000; // Default baseline

    for (var inv in allInvoices) {
      final date = DateTime.fromMillisecondsSinceEpoch(inv.billDate);
      final monthDiff = (now.year - date.year) * 12 + now.month - date.month;
      
      if (monthDiff >= 0 && monthDiff < 6) {
        final index = 5 - monthDiff; // 5 is current month, 0 is 6 months ago
        if (inv.type == 'sales') monthlySales[index] += inv.totalAmount;
        if (inv.type == 'purchase') monthlyPurchases[index] += inv.totalAmount;
        
        maxChartValue = math.max(maxChartValue, monthlySales[index]);
        maxChartValue = math.max(maxChartValue, monthlyPurchases[index]);
      }
    }

    // --- 3. PIE CHART CALCULATION (Top 5 Debtors) ---
    Map<String, double> balances = {};
    for (var inv in allInvoices.where((i) => i.type == 'sales' && i.purchaserId != null)) {
      balances[inv.purchaserId!] = (balances[inv.purchaserId!] ?? 0) + inv.totalAmount;
    }
    for (var pay in allPayments.where((p) => p.type == 'received')) {
      balances[pay.purchaserId] = (balances[pay.purchaserId] ?? 0) - pay.amount;
    }

    // Filter to only those who owe us money, sort descending, grab top 5
    var debtors = balances.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    var top5Debtors = debtors.take(5).toList();

    List<Color> pieColors = [Colors.blue, Colors.redAccent, Colors.amber, Colors.green, Colors.purple];

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- COMPANY PROFILE CARD ---
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  CircleAvatar(radius: 40, backgroundColor: Colors.blue.shade100, child: const Icon(Icons.business, size: 40, color: Colors.blue)),
                  const SizedBox(height: 16),
                  Text(company.name.toUpperCase(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  const SizedBox(height: 8),
                  Text('${company.address1}, ${company.address2}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                  Text('MO: ${company.mobileNumber}', style: const TextStyle(color: Colors.grey)),
                  const Divider(height: 20),
                  
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Lock Workspace?'),
                                content: const Text('You will need your PIN to enter again.'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                    onPressed: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const GlobalDashboardScreen()), (route) => false),
                                    child: const Text('Lock & Exit'),
                                  ),
                                ],
                              ),
                            );
                          },
                          icon: const Icon(Icons.lock_outline, color: Colors.red, size: 18),
                          label: const Text('Lock', style: TextStyle(color: Colors.red)),
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditCompanyScreen(company: company))),
                          icon: const Icon(Icons.security, size: 18),
                          label: const Text('Settings'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey.shade800, foregroundColor: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // --- KPI HEADER ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Business Snapshot', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              DropdownButton<String>(
                value: _analyticsFilter,
                items: ['Both', 'Sales', 'Purchase'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _analyticsFilter = val);
                  }
                },
              )
            ],
          ),
          const SizedBox(height: 10),

          // --- KPI CARDS ---
          Row(
            children: [
              Expanded(
                child: _buildMetricCard("Today's ${_analyticsFilter == 'Both' ? 'Net' : _analyticsFilter}", todayAmount, DateFormat('dd MMM').format(now), Colors.orange),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard("This Month's ${_analyticsFilter == 'Both' ? 'Net' : _analyticsFilter}", monthAmount, '1st - ${DateFormat('dd MMM').format(now)}', Colors.green),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // --- BAR CHART: CASH FLOW TREND ---
          const Text('6-Month Cash Flow Trend', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Container(
            height: 250,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))]),
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxChartValue * 1.2, 
                barTouchData: BarTouchData(enabled: true), 
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) => Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(monthLabels[value.toInt()], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), 
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(6, (i) {
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(toY: monthlySales[i], color: Colors.blue, width: 10, borderRadius: BorderRadius.circular(4)),
                      BarChartRodData(toY: monthlyPurchases[i], color: Colors.redAccent, width: 10, borderRadius: BorderRadius.circular(4)),
                    ],
                  );
                }),
              ),
            ),
          ),
          
          // Chart Legend
          Padding(
            padding: const EdgeInsets.only(top: 8.0, bottom: 24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(width: 12, height: 12, color: Colors.blue), const SizedBox(width: 4), const Text('Sales', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 16),
                Container(width: 12, height: 12, color: Colors.redAccent), const SizedBox(width: 4), const Text('Purchases', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),

          // --- PIE CHART: TOP DEBTORS ---
          if (top5Debtors.isNotEmpty) ...[
            const Text('Top Outstanding Receivables', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))]),
              child: Row(
                children: [
                  SizedBox(
                    height: 150,
                    width: 150,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 30,
                        sections: List.generate(top5Debtors.length, (i) {
                          return PieChartSectionData(
                            color: pieColors[i],
                            value: top5Debtors[i].value,
                            title: '', 
                            radius: 40,
                          );
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: List.generate(top5Debtors.length, (i) {
                        final purchaserName = allPurchasers.firstWhere(
                          (p) => p.id == top5Debtors[i].key, 
                          orElse: () => Purchaser(id: '', userId: '', name: 'Unknown', address1: '', address2: '', particulars: '', gstin: '', hsnNo: '', sgstRate: 0, cgstRate: 0, igstRate: 0, lastUpdated: 0)
                        ).name;
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              Container(width: 10, height: 10, color: pieColors[i]),
                              const SizedBox(width: 8),
                              Expanded(child: Text(purchaserName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                              
                              // FORMATTED PIE CHART AMOUNTS
                              Text('₹${formatAmount(top5Debtors[i].value)}', style: const TextStyle(fontSize: 11)),
                            ],
                          ),
                        );
                      }),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 30),
          ]
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, double amount, String dateLabel, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(bottom: BorderSide(color: color.shade400, width: 4)),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          
          // FORMATTED SNAPSHOT AMOUNTS
          Text(
            '₹${formatAmount(amount)}', 
            style: TextStyle(
              fontSize: 24, 
              fontWeight: FontWeight.bold, 
              color: amount >= 0 ? Colors.black87 : Colors.red
            )
          ),
          
          const SizedBox(height: 8),
          Text(dateLabel, style: TextStyle(color: color.shade300, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}