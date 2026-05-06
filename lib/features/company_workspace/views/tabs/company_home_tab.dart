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

// --- NEW IMPORT: Adjust this path if your account_detail_screen is located elsewhere ---
import '../account_detail_screen.dart'; 

class CompanyHomeTab extends ConsumerStatefulWidget {
  final Function(int)? onNavigateTab; 

  const CompanyHomeTab({super.key, this.onNavigateTab});

  @override
  ConsumerState<CompanyHomeTab> createState() => _CompanyHomeTabState();
}

class _CompanyHomeTabState extends ConsumerState<CompanyHomeTab> {
  String _analyticsFilter = 'Both'; // Both, Sales, Purchase

  String formatAmount(double val) {
    final formatter = NumberFormat.decimalPattern('en_IN');
    return '${formatter.format(val.round())}/-';
  }

  @override
  Widget build(BuildContext context) {
    final company = ref.watch(activeCompanyProvider);
    final allInvoices = ref.watch(invoiceProvider);
    final allPayments = ref.watch(paymentProvider);
    final allPurchasers = ref.watch(purchaserProvider);
    
    // TODO: Replace this with your actual user provider to fetch the logged-in user's name
    String userName = "Admin"; 

    if (company == null) return const Center(child: Text('Loading...'));

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final startOfMonth = DateTime(now.year, now.month, 1);
    
    // --- 1. KPI CALCULATION ---
    double todaySales = 0.0;
    double todayPurchases = 0.0;
    double monthSales = 0.0;
    double monthPurchases = 0.0;

    for (var inv in allInvoices) {
      if (_analyticsFilter == 'Sales' && inv.type != 'sales') continue;
      if (_analyticsFilter == 'Purchase' && inv.type != 'purchase') continue;

      final invDate = DateTime.fromMillisecondsSinceEpoch(inv.billDate);
      double amt = inv.totalAmount;

      if (!invDate.isBefore(startOfDay)) {
        if (inv.type == 'sales') todaySales += amt;
        if (inv.type == 'purchase') todayPurchases += amt;
      }
      
      if (!invDate.isBefore(startOfMonth)) {
        if (inv.type == 'sales') monthSales += amt;
        if (inv.type == 'purchase') monthPurchases += amt;
      }
    }

    double todayNet = _analyticsFilter == 'Purchase' ? todayPurchases : (_analyticsFilter == 'Sales' ? todaySales : todaySales - todayPurchases);
    double monthNet = _analyticsFilter == 'Purchase' ? monthPurchases : (_analyticsFilter == 'Sales' ? monthSales : monthSales - monthPurchases);

    // --- 2. BAR CHART CALCULATION ---
    List<String> monthLabels = List.generate(6, (i) => DateFormat('MMM').format(DateTime(now.year, now.month - 5 + i)));
    List<double> monthlySales = List.filled(6, 0.0);
    List<double> monthlyPurchases = List.filled(6, 0.0);
    double maxChartValue = 1000; 

    for (var inv in allInvoices) {
      final date = DateTime.fromMillisecondsSinceEpoch(inv.billDate);
      final monthDiff = (now.year - date.year) * 12 + now.month - date.month;
      
      if (monthDiff >= 0 && monthDiff < 6) {
        final index = 5 - monthDiff; 
        if (inv.type == 'sales') monthlySales[index] += inv.totalAmount;
        if (inv.type == 'purchase') monthlyPurchases[index] += inv.totalAmount;
        
        maxChartValue = math.max(maxChartValue, monthlySales[index]);
        maxChartValue = math.max(maxChartValue, monthlyPurchases[index]);
      }
    }

    // --- 3. PIE CHART CALCULATION ---
    Map<String, double> pieBalances = {};
    for (var inv in allInvoices.where((i) => i.type == 'sales' && i.purchaserId != null)) {
      pieBalances[inv.purchaserId!] = (pieBalances[inv.purchaserId!] ?? 0) + inv.totalAmount;
    }
    for (var pay in allPayments.where((p) => p.type == 'received')) {
      pieBalances[pay.purchaserId] = (pieBalances[pay.purchaserId] ?? 0) - pay.amount;
    }
    var top5Debtors = pieBalances.entries.where((e) => e.value > 0).toList()..sort((a, b) => b.value.compareTo(a.value));
    top5Debtors = top5Debtors.take(5).toList();
    List<Color> pieColors = [Colors.blueAccent, Colors.pinkAccent, Colors.amber, Colors.greenAccent, Colors.deepPurpleAccent];

    // --- 4. ALL PARTIES CALCULATION (UPDATED) ---
    Map<String, double> balances = {};
    for (var p in allPurchasers) { balances[p.id] = 0.0; }
    for (var inv in allInvoices) {
      if (inv.purchaserId == null) continue;
      double amt = inv.totalAmount;
      balances[inv.purchaserId!] = (balances[inv.purchaserId!] ?? 0.0) + (inv.type == 'sales' ? amt : -amt);
    }
    for (var pay in allPayments) {
      double amt = pay.amount;
      balances[pay.purchaserId] = (balances[pay.purchaserId] ?? 0.0) + (pay.type == 'received' ? -amt : amt);
    }
    
    // Sort so pending balances show up first, followed by clear accounts
    final allPartiesList = allPurchasers.toList();
    allPartiesList.sort((a, b) {
      double balA = (balances[a.id] ?? 0.0).abs();
      double balB = (balances[b.id] ?? 0.0).abs();
      if (balA < 0.01 && balB >= 0.01) return 1;
      if (balB < 0.01 && balA >= 0.01) return -1;
      return balB.compareTo(balA);
    });

    // --- 5. RECENT ACTIONS CALCULATION ---
    List<Map<String, dynamic>> recentActions = [];
    for (var inv in allInvoices) {
      recentActions.add({
        'type': inv.type == 'sales' ? 'Sale' : 'Purchase',
        'amount': inv.totalAmount,
        'date': inv.billDate,
        'purchaserId': inv.purchaserId,
        'icon': inv.type == 'sales' ? Icons.arrow_upward : Icons.arrow_downward,
        'color': inv.type == 'sales' ? Colors.blue : Colors.red,
      });
    }
    for (var pay in allPayments) {
      recentActions.add({
        'type': pay.type == 'received' ? 'Payment Received' : 'Payment Made',
        'amount': pay.amount,
        'date': pay.date,
        'purchaserId': pay.purchaserId,
        'icon': Icons.payments_rounded,
        'color': pay.type == 'received' ? Colors.green : Colors.orange,
      });
    }
    recentActions.sort((a, b) => b['date'].compareTo(a['date']));
    final topRecentActions = recentActions.take(10).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- COMPANY PROFILE CARD ---
          Card(
            elevation: 4,
            shadowColor: Colors.black12,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  CircleAvatar(radius: 40, backgroundColor: Colors.blue.shade50, child: const Icon(Icons.business, size: 40, color: Colors.blueAccent)),
                  const SizedBox(height: 16),
                  Text(company.name.toUpperCase(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Color(0xFF203A43))),
                  const SizedBox(height: 4),
                  
                  // --- NEW: BY NAME ---
                  Text('by: $userName', style: TextStyle(color: Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.w600)),
                  
                  const SizedBox(height: 8),
                  Text('${company.address1}, ${company.address2}', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                  Text('MO: ${company.mobileNumber}', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 14)),
                  const Divider(height: 30),
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
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditCompanyScreen(company: company))),
                          icon: const Icon(Icons.security, size: 18),
                          label: const Text('Settings'),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF203A43), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // --- KPI HEADER & SNAPSHOT ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Business Snapshot', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF203A43))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                child: DropdownButton<String>(
                  value: _analyticsFilter,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.blueAccent),
                  items: ['Both', 'Sales', 'Purchase'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
                  onChanged: (val) { if (val != null) setState(() => _analyticsFilter = val); },
                ),
              )
            ],
          ),
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  "Today's ${_analyticsFilter == 'Both' ? 'Net' : _analyticsFilter}", 
                  todayNet, 
                  todaySales, 
                  todayPurchases,
                  DateFormat('dd MMM').format(now), 
                  [Colors.orange.shade400, Colors.deepOrange.shade400]
                )
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  "This Month's ${_analyticsFilter == 'Both' ? 'Net' : _analyticsFilter}", 
                  monthNet, 
                  monthSales,
                  monthPurchases,
                  '1st - ${DateFormat('dd MMM').format(now)}', 
                  [Colors.teal.shade400, Colors.green.shade600]
                )
              ),
            ],
          ),
          
          const SizedBox(height: 32),

          // --- BAR CHART: CASH FLOW TREND ---
          const Text('6-Month Cash Flow Trend', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF203A43))),
          const SizedBox(height: 12),
          HoverableDataCard(
            gradientColors: const [Colors.white, Colors.white],
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  SizedBox(
                    height: 220,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: maxChartValue * 1.2, 
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (group) => Colors.black87,
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              return BarTooltipItem(
                                '₹${formatAmount(rod.toY)}',
                                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                              );
                            },
                          ),
                        ), 
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) => Padding(padding: const EdgeInsets.only(top: 10), child: Text(monthLabels[value.toInt()], style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600))),
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
                              BarChartRodData(toY: monthlySales[i], gradient: LinearGradient(colors: [Colors.blueAccent.shade100, Colors.blueAccent.shade700], begin: Alignment.bottomCenter, end: Alignment.topCenter), width: 12, borderRadius: BorderRadius.circular(4)),
                              BarChartRodData(toY: monthlyPurchases[i], gradient: LinearGradient(colors: [Colors.pinkAccent.shade100, Colors.pinkAccent.shade700], begin: Alignment.bottomCenter, end: Alignment.topCenter), width: 12, borderRadius: BorderRadius.circular(4)),
                            ],
                          );
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.circular(3))), const SizedBox(width: 6), const Text('Sales', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(width: 24),
                      Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.pinkAccent, borderRadius: BorderRadius.circular(3))), const SizedBox(width: 6), const Text('Purchases', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // --- PIE CHART: TOP DEBTORS ---
          if (top5Debtors.isNotEmpty) ...[
            const Text('Top Outstanding Receivables', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF203A43))),
            const SizedBox(height: 12),
            HoverableDataCard(
              gradientColors: const [Colors.white, Colors.white],
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    SizedBox(
                      height: 140,
                      width: 140,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 4,
                          centerSpaceRadius: 25,
                          sections: List.generate(top5Debtors.length, (i) {
                            return PieChartSectionData(
                              color: pieColors[i],
                              value: top5Debtors[i].value,
                              title: '', 
                              radius: 45,
                              badgeWidget: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
                                child: Text('${i+1}', style: TextStyle(fontWeight: FontWeight.bold, color: pieColors[i], fontSize: 10)),
                              ),
                              badgePositionPercentageOffset: 1.1,
                            );
                          }),
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: List.generate(top5Debtors.length, (i) {
                          final purchaserName = allPurchasers.firstWhere((p) => p.id == top5Debtors[i].key, orElse: () => Purchaser(id: '', userId: '', name: 'Unknown', address1: '', address2: '', particulars: '', gstin: '', hsnNo: '', sgstRate: 0, cgstRate: 0, igstRate: 0, lastUpdated: 0)).name;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Row(
                              children: [
                                Container(width: 12, height: 12, decoration: BoxDecoration(color: pieColors[i], shape: BoxShape.circle)),
                                const SizedBox(width: 8),
                                Expanded(child: Text(purchaserName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade800), overflow: TextOverflow.ellipsis)),
                                Text('₹${formatAmount(top5Debtors[i].value)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
                              ],
                            ),
                          );
                        }),
                      ),
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],

          // --- ALL PARTIES (UPDATED FROM PENDING PAYMENTS) ---
          const Text('Parties', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF203A43))),
          const SizedBox(height: 12),
          HoverableDataCard(
            gradientColors: [Colors.purple.shade700, Colors.deepPurple.shade400],
            child: allPartiesList.isEmpty 
              ? const Padding(padding: EdgeInsets.all(24.0), child: Center(child: Text('No parties added yet.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))))
              : Column(
                  children: allPartiesList.map((purchaser) {
                    final bal = balances[purchaser.id] ?? 0.0;
                    final isClear = bal.abs() < 0.01;
                    final isOwedToUs = bal > 0;
                    
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        // Navigates directly to the AccountDetailScreen for this party
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => AccountDetailScreen(purchaser: purchaser)),
                          );
                        },
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: Colors.white24, 
                            child: Icon(
                              isClear ? Icons.check_circle : (isOwedToUs ? Icons.call_received : Icons.call_made), 
                              color: isClear ? Colors.greenAccent : Colors.white, 
                              size: 18
                            )
                          ),
                          title: Text(purchaser.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            isClear ? 'No pending balance' : (isOwedToUs ? 'They owe us' : 'We owe them'), 
                            style: const TextStyle(color: Colors.white70, fontSize: 12)
                          ),
                          trailing: Text(
                            isClear ? 'Clear' : '₹${formatAmount(bal.abs())}', 
                            style: TextStyle(
                              color: isClear ? Colors.greenAccent : Colors.white, 
                              fontWeight: FontWeight.w900, 
                              fontSize: 16
                            )
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
          ),
          
          const SizedBox(height: 32),

          // --- LATEST ACTIONS ---
          const Text('Latest Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF203A43))),
          const SizedBox(height: 12),
          HoverableDataCard(
            gradientColors: [Colors.blue.shade800, Colors.lightBlue.shade500],
            child: topRecentActions.isEmpty
              ? const Padding(padding: EdgeInsets.all(24.0), child: Center(child: Text('No recent activity.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))))
              : Column(
                  children: topRecentActions.map((action) {
                    final purchaser = allPurchasers.firstWhere((p) => p.id == action['purchaserId'], orElse: () => Purchaser(id: '', userId: '', name: 'Unknown', address1: '', address2: '', particulars: '', gstin: '', hsnNo: '', sgstRate: 0, cgstRate: 0, igstRate: 0, lastUpdated: 0));
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      leading: CircleAvatar(backgroundColor: Colors.white, child: Icon(action['icon'], color: action['color'], size: 18)),
                      title: Text(purchaser.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text('${action['type']} • ${DateFormat('dd MMM, hh:mm a').format(DateTime.fromMillisecondsSinceEpoch(action['date']))}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                      trailing: Text('₹${formatAmount(action['amount'])}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                    );
                  }).toList(),
                ),
          ),
          
          const SizedBox(height: 32),

          // --- SHORTCUT LINKS (UPDATED) ---
          const Text('Quick Access', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF203A43))),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 3.8, 
            children: [
              _buildShortcutBtn(Icons.people, 'Parties', Colors.teal, () => widget.onNavigateTab?.call(1)), // Added Parties Link
              _buildShortcutBtn(Icons.point_of_sale, 'Sales', Colors.blueAccent, () => widget.onNavigateTab?.call(2)), 
              _buildShortcutBtn(Icons.shopping_cart, 'Purchase', Colors.pinkAccent, () => widget.onNavigateTab?.call(3)),
              _buildShortcutBtn(Icons.book, 'Ledger', Colors.deepPurpleAccent, () => widget.onNavigateTab?.call(4)),
              _buildShortcutBtn(Icons.account_balance_wallet, 'Account', Colors.orangeAccent, () => widget.onNavigateTab?.call(5)),
            ],
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, double netAmount, double salesAmount, double purchaseAmount, String dateLabel, List<Color> gradient) {
    return HoverableDataCard(
      gradientColors: gradient,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('₹${formatAmount(netAmount)}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white)),
            ),
            const SizedBox(height: 8),
            
            // --- UPDATED: Sales & Purchase matching the exact size/color as the title ---
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sales: ₹${formatAmount(salesAmount)}', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text('Purchase: ₹${formatAmount(purchaseAmount)}', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),

            const SizedBox(height: 12),
            Text(dateLabel, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildShortcutBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return HoverableShortcutCard(
      color: color,
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 18), 
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)), 
        ],
      ),
    );
  }
}

// --- CUSTOM REUSABLE HOVER WIDGETS ---

class HoverableDataCard extends StatefulWidget {
  final Widget child;
  final List<Color> gradientColors;

  const HoverableDataCard({super.key, required this.child, required this.gradientColors});

  @override
  State<HoverableDataCard> createState() => _HoverableDataCardState();
}

class _HoverableDataCardState extends State<HoverableDataCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()..scale(_isHovered ? 1.01 : 1.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: widget.gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: widget.gradientColors.last.withOpacity(_isHovered ? 0.3 : 0.1),
              blurRadius: _isHovered ? 20 : 10,
              offset: Offset(0, _isHovered ? 8 : 4),
            ),
          ],
        ),
        child: ClipRRect(borderRadius: BorderRadius.circular(20), child: widget.child),
      ),
    );
  }
}

class HoverableShortcutCard extends StatefulWidget {
  final Widget child;
  final Color color;
  final VoidCallback onTap;

  const HoverableShortcutCard({super.key, required this.child, required this.color, required this.onTap});

  @override
  State<HoverableShortcutCard> createState() => _HoverableShortcutCardState();
}

class _HoverableShortcutCardState extends State<HoverableShortcutCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isHovered = true),
        onTapUp: (_) {
          setState(() => _isHovered = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          transform: Matrix4.identity()..scale(_isHovered ? 1.04 : 1.0),
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(12), 
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(_isHovered ? 0.4 : 0.15),
                blurRadius: _isHovered ? 12 : 6,
                offset: Offset(0, _isHovered ? 6 : 3),
              ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}