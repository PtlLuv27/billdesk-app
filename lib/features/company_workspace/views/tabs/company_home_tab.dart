import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart'; 
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart'; 
import 'dart:math' as math;
import 'package:supabase_flutter/supabase_flutter.dart'; 

import '../../../../models/purchaser_model.dart'; 
import '../../../../models/invoice_model.dart'; 
// import '../../../../models/payment_model.dart'; 
import '../../providers/company_provider.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/payment_provider.dart';
import '../../providers/purchaser_provider.dart';
import '../edit_company_screen.dart';
import '../../../dashboard/global_dashboard_screen.dart'; 
import '../../../../core/database/sync_engine.dart';

// 🔥 ROUTING IMPORTS
import '../editable_invoice_screen.dart';
import '../editable_purchase_screen.dart';
import '../account_detail_screen.dart';

class CompanyHomeTab extends ConsumerStatefulWidget {
  final Function(int)? onNavigateTab; 

  const CompanyHomeTab({super.key, this.onNavigateTab});

  @override
  ConsumerState<CompanyHomeTab> createState() => _CompanyHomeTabState();
}

class _CompanyHomeTabState extends ConsumerState<CompanyHomeTab> with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true;

  String _analyticsFilter = 'Both';

  String formatAmount(double val) {
    final formatter = NumberFormat.decimalPattern('en_IN');
    return '${formatter.format(val.round())}/-';
  }

  Future<void> _syncData() async {
    await SyncEngine.syncAll();
    ref.invalidate(invoiceProvider);
    ref.invalidate(paymentProvider);
    ref.invalidate(purchaserProvider);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); 

    final company = ref.watch(activeCompanyProvider);
    final allInvoices = ref.watch(invoiceProvider);
    final allPayments = ref.watch(paymentProvider);
    final allPurchasers = ref.watch(purchaserProvider);
    
    final currentUser = Supabase.instance.client.auth.currentUser;
    final userName = currentUser?.userMetadata?['name'] 
        ?? currentUser?.email?.split('@').first 
        ?? "Admin"; 

    if (company == null) return const Center(child: Text('Loading...'));

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    
    final int startYear = now.month >= 4 ? now.year : now.year - 1;
    final int endYear = startYear + 1;
    
    final businessStart = DateTime(startYear, 4, 1);
    final businessEnd = DateTime(endYear, 3, 31, 23, 59, 59);
    
    final businessYearLabel = "Business Year : $startYear-${endYear.toString().substring(2)}";

    // --- 1. KPI CALCULATION ---
    double todaySales = 0.0;
    double todayPurchases = 0.0;
    double yearSales = 0.0;
    double yearPurchases = 0.0;

    for (var inv in allInvoices) {
      if (_analyticsFilter == 'Sales' && inv.type != 'sales') continue;
      if (_analyticsFilter == 'Purchase' && inv.type != 'purchase') continue;

      final invDate = DateTime.fromMillisecondsSinceEpoch(inv.billDate);
      if (invDate.isBefore(businessStart) || invDate.isAfter(businessEnd)) continue;

      double amt = inv.totalAmount;

      if (!invDate.isBefore(startOfDay)) {
        if (inv.type == 'sales') todaySales += amt;
        if (inv.type == 'purchase') todayPurchases += amt;
      }
      
      if (inv.type == 'sales') yearSales += amt;
      if (inv.type == 'purchase') yearPurchases += amt;
    }

    double todayNet = _analyticsFilter == 'Purchase' ? todayPurchases : (_analyticsFilter == 'Sales' ? todaySales : todaySales - todayPurchases);
    double yearNet = _analyticsFilter == 'Purchase' ? yearPurchases : (_analyticsFilter == 'Sales' ? yearSales : yearSales - yearPurchases);

    // --- 2. BAR CHART CALCULATION ---
    List<String> monthLabels = ['Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', 'Jan', 'Feb', 'Mar'];
    List<double> monthlySales = List.filled(12, 0.0);
    List<double> monthlyPurchases = List.filled(12, 0.0);
    double maxChartValue = 1000; 

    for (var inv in allInvoices) {
      final date = DateTime.fromMillisecondsSinceEpoch(inv.billDate);
      if (!date.isBefore(businessStart) && !date.isAfter(businessEnd)) {
        final index = date.month >= 4 ? date.month - 4 : date.month + 8;
        if (inv.type == 'sales') monthlySales[index] += inv.totalAmount;
        if (inv.type == 'purchase') monthlyPurchases[index] += inv.totalAmount;
        maxChartValue = math.max(maxChartValue, monthlySales[index]);
        maxChartValue = math.max(maxChartValue, monthlyPurchases[index]);
      }
    }

    List<Color> debtorColors = [Colors.tealAccent.shade400, Colors.lightGreenAccent.shade400, Colors.cyanAccent.shade400, Colors.indigoAccent, Colors.purpleAccent];
    List<Color> perfColors = [Colors.blueAccent, Colors.pinkAccent, Colors.amber, Colors.greenAccent, Colors.deepPurpleAccent];

    // --- 3. PIE CHART: TOP DEBTORS (Outstanding Receivables - ALL TIME) ---
    Map<String, double> debtorBalances = {};
    for (var inv in allInvoices.where((i) => i.type == 'sales' && i.companyId == company.id && i.purchaserId != null)) {
      // 🔥 Oustanding balance doesn't care about financial year, it's an all-time total
      debtorBalances[inv.purchaserId!] = (debtorBalances[inv.purchaserId!] ?? 0.0) + inv.totalAmount;
    }
    for (var pay in allPayments.where((p) => p.type == 'received' && p.companyId == company.id)) {
      if (debtorBalances.containsKey(pay.purchaserId)) {
        debtorBalances[pay.purchaserId] = debtorBalances[pay.purchaserId]! - pay.amount;
      }
    }
    var top5Debtors = debtorBalances.entries.where((e) => e.value > 0.01).toList()..sort((a, b) => b.value.compareTo(a.value));
    top5Debtors = top5Debtors.take(5).toList();

    // --- 4. PIE CHART: TOP PERFORMANCE ---
    Map<String, double> performanceBalances = {};
    for (var inv in allInvoices.where((i) => i.type == 'sales' && i.purchaserId != null)) {
      final invDate = DateTime.fromMillisecondsSinceEpoch(inv.billDate);
      if (!invDate.isBefore(businessStart) && !invDate.isAfter(businessEnd)) {
        performanceBalances[inv.purchaserId!] = (performanceBalances[inv.purchaserId!] ?? 0) + inv.totalAmount;
      }
    }
    var topPerformance = performanceBalances.entries.where((e) => e.value > 0).toList()..sort((a, b) => b.value.compareTo(a.value));
    topPerformance = topPerformance.take(5).toList();

    // --- 5. LATEST ACTIONS CALCULATION ---
    List<Map<String, dynamic>> recentActions = [];
    for (var inv in allInvoices) {
      final invDate = DateTime.fromMillisecondsSinceEpoch(inv.billDate);
      if (!invDate.isBefore(businessStart) && !invDate.isAfter(businessEnd)) {
        recentActions.add({
          'type': inv.type == 'sales' ? 'Sale' : 'Purchase',
          'amount': inv.totalAmount,
          'date': inv.billDate,
          'createdAt': inv.lastUpdated, 
          'purchaserId': inv.purchaserId,
          'icon': inv.type == 'sales' ? Icons.arrow_upward : Icons.arrow_downward,
          'color': inv.type == 'sales' ? Colors.blue : Colors.red,
          'invoice': inv,
        });
      }
    }
    for (var pay in allPayments) {
      final payDate = DateTime.fromMillisecondsSinceEpoch(pay.date);
      if (!payDate.isBefore(businessStart) && !payDate.isAfter(businessEnd)) {
        final dynamic dynamicPay = pay;
        int payCreated = pay.date;
        try { payCreated = dynamicPay.lastUpdated ?? pay.date; } catch (_) {}

        recentActions.add({
          'type': pay.type == 'received' ? 'Payment Received' : 'Payment Made',
          'amount': pay.amount,
          'date': pay.date,
          'createdAt': payCreated, 
          'purchaserId': pay.purchaserId,
          'icon': Icons.payments_rounded,
          'color': pay.type == 'received' ? Colors.green : Colors.orange,
          'payment': pay,
        });
      }
    }
    
    // Sort by system creation log time
    recentActions.sort((a, b) => b['createdAt'].compareTo(a['createdAt']));
    final topRecentActions = recentActions.take(10).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      body: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse, PointerDeviceKind.trackpad},
        ),
        child: RefreshIndicator(
          onRefresh: _syncData, 
          color: Colors.blueAccent,
          backgroundColor: Colors.white,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(), 
            padding: const EdgeInsets.all(16),
            children: [
              // --- COMPANY PROFILE CARD (Centered & Enlarged) ---
              Card(
                elevation: 2,
                shadowColor: Colors.black12,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                        child: const Icon(Icons.business, size: 42, color: Colors.blueAccent),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        company.name.toUpperCase(), 
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 0.5, color: Color(0xFF203A43)),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text('Operated by: $userName', style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      Text(
                        '${company.address1}, ${company.address2}', 
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13), 
                        textAlign: TextAlign.center,
                        maxLines: 2, 
                        overflow: TextOverflow.ellipsis
                      ),
                      const SizedBox(height: 4),
                      Text('Ph: ${company.mobileNumber}', style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.bold, fontSize: 14)),
                      const Divider(height: 32),
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
                              icon: const Icon(Icons.lock_outline, color: Colors.red, size: 16),
                              label: const Text('Lock', style: TextStyle(color: Colors.red)),
                              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditCompanyScreen(company: company))),
                              icon: const Icon(Icons.settings, size: 16),
                              label: const Text('Settings'),
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF203A43), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),

              // --- QUICK ACCESS BUTTONS (Responsive & Shrunken) ---
              const Text('Quick Access', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF203A43))),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  bool isWide = constraints.maxWidth > 500; 
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildResponsiveShortcutBtn(Icons.people, 'Parties', Colors.teal, () => widget.onNavigateTab?.call(1), isWide), 
                      const SizedBox(width: 6),
                      _buildResponsiveShortcutBtn(Icons.point_of_sale, 'Sales', Colors.indigoAccent, () => widget.onNavigateTab?.call(2), isWide), 
                      const SizedBox(width: 6),
                      _buildResponsiveShortcutBtn(Icons.shopping_cart, 'Purchase', Colors.redAccent, () => widget.onNavigateTab?.call(3), isWide),
                      const SizedBox(width: 6),
                      _buildResponsiveShortcutBtn(Icons.book, 'Ledger', Colors.blueGrey.shade700, () => widget.onNavigateTab?.call(4), isWide),
                      const SizedBox(width: 6),
                      _buildResponsiveShortcutBtn(Icons.account_balance_wallet, 'Account', Colors.teal.shade700, () => widget.onNavigateTab?.call(5), isWide),const SizedBox(width: 6),
                    ],
                  );
                }
              ),

              const SizedBox(height: 32),
              
              // --- KPI HEADER & SNAPSHOT ---
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue.shade100)
                  ),
                  child: Text(
                    businessYearLabel, 
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade800)
                  ),
                ),
              ),
              const SizedBox(height: 12),

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
                      "This Year's ${_analyticsFilter == 'Both' ? 'Net' : _analyticsFilter}", 
                      yearNet, 
                      yearSales,
                      yearPurchases,
                      'Apr - Mar', 
                      [Colors.teal.shade400, Colors.green.shade600]
                    )
                  ),
                ],
              ),
              
              const SizedBox(height: 32),

              // --- BAR CHART: CASH FLOW TREND ---
              const Text("Current Year's Cash Flow", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF203A43))),
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
                                  getTitlesWidget: (value, meta) => Padding(
                                    padding: const EdgeInsets.only(top: 10), 
                                    child: Text(monthLabels[value.toInt()], style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600))
                                  ),
                                ),
                              ),
                              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), 
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            gridData: const FlGridData(show: false),
                            borderData: FlBorderData(show: false),
                            barGroups: List.generate(12, (i) {
                              return BarChartGroupData(
                                x: i,
                                barRods: [
                                  BarChartRodData(toY: monthlySales[i], gradient: LinearGradient(colors: [Colors.blueAccent.shade100, Colors.blueAccent.shade700], begin: Alignment.bottomCenter, end: Alignment.topCenter), width: 8, borderRadius: BorderRadius.circular(4)),
                                  BarChartRodData(toY: monthlyPurchases[i], gradient: LinearGradient(colors: [Colors.pinkAccent.shade100, Colors.pinkAccent.shade700], begin: Alignment.bottomCenter, end: Alignment.topCenter), width: 8, borderRadius: BorderRadius.circular(4)),
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

              // --- PIE CHART: TOP PERFORMANCE ---
              if (topPerformance.isNotEmpty) ...[
                const Text('Top Performance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF203A43))),
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
                              sections: List.generate(topPerformance.length, (i) {
                                return PieChartSectionData(
                                  color: perfColors[i],
                                  value: topPerformance[i].value,
                                  title: '', 
                                  radius: 45,
                                  badgeWidget: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
                                    child: Text('${i+1}', style: TextStyle(fontWeight: FontWeight.bold, color: perfColors[i], fontSize: 10)),
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
                            children: List.generate(topPerformance.length, (i) {
                              final purchaserName = allPurchasers.firstWhere((p) => p.id == topPerformance[i].key, orElse: () => Purchaser(id: '', userId: '', name: 'Unknown', address1: '', address2: '', particulars: '', gstin: '', hsnNo: '', sgstRate: 0, cgstRate: 0, igstRate: 0, lastUpdated: 0)).name;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: Row(
                                  children: [
                                    Container(width: 12, height: 12, decoration: BoxDecoration(color: perfColors[i], shape: BoxShape.circle)),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(purchaserName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade800), overflow: TextOverflow.ellipsis)),
                                    Text('₹${formatAmount(topPerformance[i].value)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
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
                                final safeColor = debtorColors[i % debtorColors.length];
                                return PieChartSectionData(
                                  color: safeColor,
                                  value: top5Debtors[i].value,
                                  title: '', 
                                  radius: 45,
                                  badgeWidget: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
                                    child: Text('${i+1}', style: TextStyle(fontWeight: FontWeight.bold, color: safeColor, fontSize: 10)),
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
                              final safeColor = debtorColors[i % debtorColors.length];
                              final purchaserName = allPurchasers.firstWhere((p) => p.id == top5Debtors[i].key, orElse: () => Purchaser(id: '', userId: '', name: 'Unknown', address1: '', address2: '', particulars: '', gstin: '', hsnNo: '', sgstRate: 0, cgstRate: 0, igstRate: 0, lastUpdated: 0)).name;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: Row(
                                  children: [
                                    Container(width: 12, height: 12, decoration: BoxDecoration(color: safeColor, shape: BoxShape.circle)),
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

              // --- LATEST ACTIONS ---
              const Text('Latest Activity Log', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF203A43))),
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
                          onTap: () {
                            if (action['invoice'] != null) {
                              final inv = action['invoice'] as Invoice;
                              if (inv.type == 'sales') {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => EditableInvoiceScreen(invoice: inv, company: company, purchaser: purchaser)));
                              } else {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => EditablePurchaseScreen(invoice: inv, company: company, purchaser: purchaser)));
                              }
                            } else if (action['payment'] != null) {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => AccountDetailScreen(purchaser: purchaser)));
                            }
                          },
                        );
                      }).toList(),
                    ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  // --- RESPONSIVE SHORTCUT BUTTONS ---
  Widget _buildResponsiveShortcutBtn(IconData icon, String label, Color color, VoidCallback onTap, bool isWide) {
    return Expanded(
      child: HoverableShortcutCard(
        color: color,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: isWide ? 10 : 8, horizontal: 2), 
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: isWide ? 20 : 16), 
              SizedBox(height: isWide ? 6 : 4),
              Text(label, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: isWide ? 11 : 9), maxLines: 1, overflow: TextOverflow.ellipsis), 
            ],
          ),
        ),
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