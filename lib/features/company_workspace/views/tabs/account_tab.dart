import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart'; 
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart'; 
import '../../../../models/purchaser_model.dart'; 
import '../../providers/purchaser_provider.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/payment_provider.dart';
import '../../providers/company_provider.dart'; 
import '../account_detail_screen.dart';
import '../../../../core/database/sync_engine.dart'; 

class AccountTab extends ConsumerStatefulWidget {
  const AccountTab({super.key});

  @override
  ConsumerState<AccountTab> createState() => _AccountTabState();
}

class _AccountTabState extends ConsumerState<AccountTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  bool _hideZeroBalance = true; 

  String formatIndianCurrency(double val) {
    final formatter = NumberFormat.decimalPattern('en_IN');
    return '₹${formatter.format(val.round())}/-'; 
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _syncData() async {
    await SyncEngine.syncAll();
    ref.invalidate(invoiceProvider);
    ref.invalidate(paymentProvider);
    ref.invalidate(purchaserProvider);
  }

  @override
  Widget build(BuildContext context) {
    final activeCompany = ref.watch(activeCompanyProvider);
    final allPurchasers = ref.watch(purchaserProvider);
    final allInvoices = ref.watch(invoiceProvider);
    final allPayments = ref.watch(paymentProvider);

    if (activeCompany == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
    }

    final invoices = allInvoices.where((i) => i.companyId == activeCompany.id).toList();
    final payments = allPayments.where((p) => p.companyId == activeCompany.id).toList();

    final searchFilteredPurchasers = allPurchasers.where((p) {
      return p.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    Map<String, double> receivables = {};
    Map<String, double> payables = {};
    Map<String, bool> hasActivity = {};
    Map<String, int> lastPaymentDates = {};
    
    for (var p in searchFilteredPurchasers) { 
      receivables[p.id] = 0.0; 
      payables[p.id] = 0.0;
      hasActivity[p.id] = false;
    }
    
    for (var inv in invoices) {
      if (inv.purchaserId != null && receivables.containsKey(inv.purchaserId)) {
        hasActivity[inv.purchaserId!] = true;
        // 🔥 Deltas are naturally handled here because inv.totalAmount holds the final edited math!
        if (inv.type == 'sales') {
          receivables[inv.purchaserId!] = receivables[inv.purchaserId!]! + inv.totalAmount;
        } else if (inv.type == 'purchase') {
          payables[inv.purchaserId!] = payables[inv.purchaserId!]! + inv.totalAmount;
        }
      }
    }
    
    for (var pay in payments) {
      if (receivables.containsKey(pay.purchaserId)) {
        hasActivity[pay.purchaserId] = true;
        
        if (!lastPaymentDates.containsKey(pay.purchaserId) || pay.date > lastPaymentDates[pay.purchaserId]!) {
          lastPaymentDates[pay.purchaserId] = pay.date;
        }

        if (pay.type == 'received') {
          receivables[pay.purchaserId] = receivables[pay.purchaserId]! - pay.amount;
        } else if (pay.type == 'paid') {
          payables[pay.purchaserId] = payables[pay.purchaserId]! - pay.amount;
        }
      }
    }

    List<Purchaser> finalDisplayPurchasers = [];
    for (var p in searchFilteredPurchasers) {
      final theyOweUs = receivables[p.id] ?? 0.0;
      final weOweThem = payables[p.id] ?? 0.0;
      final hasBal = theyOweUs > 0.01 || weOweThem > 0.01;
      final isActive = hasActivity[p.id] == true;

      if (_hideZeroBalance && !hasBal && !isActive) {
        continue;
      }
      finalDisplayPurchasers.add(p);
    }

    finalDisplayPurchasers.sort((a, b) {
      double recA = receivables[a.id] ?? 0.0;
      double payA = payables[a.id] ?? 0.0;
      double recB = receivables[b.id] ?? 0.0;
      double payB = payables[b.id] ?? 0.0;

      bool aHasBal = recA > 0.01 || payA > 0.01;
      bool bHasBal = recB > 0.01 || payB > 0.01;

      bool aActive = hasActivity[a.id] ?? false;
      bool bActive = hasActivity[b.id] ?? false;

      if (aHasBal && !bHasBal) return -1;
      if (!aHasBal && bHasBal) return 1;

      if (aHasBal && bHasBal) {
        double totalBalA = recA + payA;
        double totalBalB = recB + payB;
        return totalBalB.compareTo(totalBalA); 
      }

      if (aActive && !bActive) return -1;
      if (!aActive && bActive) return 1;

      if (aActive && bActive) {
        int dateA = lastPaymentDates[a.id] ?? 0;
        int dateB = lastPaymentDates[b.id] ?? 0;
        return dateB.compareTo(dateA); 
      }

      return a.name.compareTo(b.name);
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        title: const Text('Account Management', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)), 
        backgroundColor: Colors.white, 
        foregroundColor: Colors.black87, 
        elevation: 0,
        centerTitle: false,
        actions: [
          Row(
            children: [
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: _hideZeroBalance,
                  activeThumbColor: Colors.blueAccent,
                  activeTrackColor: Colors.blue.shade100,
                  inactiveThumbColor: Colors.grey.shade400,
                  inactiveTrackColor: Colors.grey.shade200,
                  onChanged: (val) {
                    setState(() {
                      _hideZeroBalance = val;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
            ],
          )
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'Search Account / Party Name...',
                  hintStyle: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.normal),
                  prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
          ),

          Expanded(
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse, PointerDeviceKind.trackpad},
              ),
              child: RefreshIndicator(
                onRefresh: _syncData,
                color: Colors.blueAccent,
                backgroundColor: Colors.white,
                child: finalDisplayPurchasers.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(), 
                        children: [
                          SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.group_off_rounded, size: 64, color: Colors.grey.shade300),
                                const SizedBox(height: 16),
                                Text(
                                  _searchQuery.isEmpty 
                                    ? (_hideZeroBalance ? 'No active accounts found.' : 'No accounts found.') 
                                    : 'No accounts matching "$_searchQuery"',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(), 
                        padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 100),
                        itemCount: finalDisplayPurchasers.length,
                        itemBuilder: (context, index) {
                          final person = finalDisplayPurchasers[index];
                          
                          final theyOweUs = receivables[person.id] ?? 0.0;
                          final weOweThem = payables[person.id] ?? 0.0;
                          final hasBal = theyOweUs > 0.01 || weOweThem > 0.01;
                          final isActive = hasActivity[person.id] == true;
                          
                          Color accentColor = Colors.grey.shade300;
                          if (hasBal) {
                            if (theyOweUs > weOweThem) {
                              accentColor = Colors.green.shade400;
                            } else {
                              accentColor = Colors.red.shade400;
                            }
                          } else if (isActive) {
                            accentColor = Colors.blue.shade400;
                          }
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border(left: BorderSide(color: accentColor, width: 4))
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => AccountDetailScreen(purchaser: person)));
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  person.name, 
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 6),
                                                
                                                if (theyOweUs > 0.01) 
                                                  Text(
                                                    'They Owe Us: ${formatIndianCurrency(theyOweUs)}', 
                                                    style: TextStyle(color: Colors.green.shade600, fontWeight: FontWeight.bold, fontSize: 13)
                                                  ),
                                                  
                                                if (weOweThem > 0.01) 
                                                  Padding(
                                                    padding: EdgeInsets.only(top: theyOweUs > 0.01 ? 2.0 : 0.0),
                                                    child: Text(
                                                      'We Owe Them: ${formatIndianCurrency(weOweThem)}', 
                                                      style: TextStyle(color: Colors.red.shade500, fontWeight: FontWeight.bold, fontSize: 13)
                                                    ),
                                                  ),
                                                  
                                                if (!hasBal)
                                                  if (isActive) ...[
                                                    Row(
                                                      children: [
                                                        Icon(Icons.check_circle, size: 14, color: Colors.blue.shade400),
                                                        const SizedBox(width: 4),
                                                        Text('Settled', style: TextStyle(color: Colors.blue.shade600, fontWeight: FontWeight.w800, fontSize: 13)),
                                                      ],
                                                    ),
                                                    if (lastPaymentDates.containsKey(person.id))
                                                      Padding(
                                                        padding: const EdgeInsets.only(top: 2.0),
                                                        child: Text(
                                                          'Last Payment: ${DateFormat('dd MMM yyyy').format(DateTime.fromMillisecondsSinceEpoch(lastPaymentDates[person.id]!))}', 
                                                          style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 11, fontWeight: FontWeight.w600)
                                                        ),
                                                      ),
                                                  ] else ...[
                                                    Text('No Balance', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600, fontSize: 13)),
                                                  ]
                                              ],
                                            ),
                                          ),
                                          
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                                            child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.blueAccent, size: 14),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}