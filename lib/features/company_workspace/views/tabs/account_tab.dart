import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart'; 
import '../../providers/purchaser_provider.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/payment_provider.dart';
import '../../providers/company_provider.dart'; 
import '../account_detail_screen.dart';

class AccountTab extends ConsumerStatefulWidget {
  const AccountTab({super.key});

  @override
  ConsumerState<AccountTab> createState() => _AccountTabState();
}

class _AccountTabState extends ConsumerState<AccountTab> {
  // --- SEARCH CONTROLLER & STATE ---
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // --- COMMA FORMATTER ---
  String formatIndianCurrency(double val) {
    final formatter = NumberFormat.decimalPattern('en_IN');
    return '₹${formatter.format(val.round())}/-'; 
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

    // Filter Invoices & Payments by current workspace
    final invoices = allInvoices.where((i) => i.companyId == activeCompany.id).toList();
    final payments = allPayments.where((p) => p.companyId == activeCompany.id).toList();

    // --- APPLY SEARCH FILTER ---
    final filteredPurchasers = allPurchasers.where((p) {
      return p.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    // --- SMART SORTING CALCULATION ---
    // Calculate Receivables (They Owe Us) and Payables (We Owe Them) SEPARATELY
    Map<String, double> receivables = {};
    Map<String, double> payables = {};
    
    for (var p in filteredPurchasers) { 
      receivables[p.id] = 0.0; 
      payables[p.id] = 0.0;
    }
    
    for (var inv in invoices) {
      if (inv.purchaserId != null && receivables.containsKey(inv.purchaserId)) {
        if (inv.type == 'sales') {
          receivables[inv.purchaserId!] = receivables[inv.purchaserId!]! + inv.totalAmount;
        } else if (inv.type == 'purchase') {
          payables[inv.purchaserId!] = payables[inv.purchaserId!]! + inv.totalAmount;
        }
      }
    }
    
    // 🔥 FIX: Removed unnecessary '!' from pay.purchaserId
    for (var pay in payments) {
      if (receivables.containsKey(pay.purchaserId)) {
        if (pay.type == 'received') {
          receivables[pay.purchaserId] = receivables[pay.purchaserId]! - pay.amount;
        } else if (pay.type == 'paid') {
          payables[pay.purchaserId] = payables[pay.purchaserId]! - pay.amount;
        }
      }
    }

    // Sort: Accounts with ANY pending balances at the top, Settled at the bottom
    filteredPurchasers.sort((a, b) {
      double recA = receivables[a.id] ?? 0.0;
      double payA = payables[a.id] ?? 0.0;
      double recB = receivables[b.id] ?? 0.0;
      double payB = payables[b.id] ?? 0.0;

      bool aIsSettled = recA <= 0.01 && payA <= 0.01;
      bool bIsSettled = recB <= 0.01 && payB <= 0.01;

      if (aIsSettled && !bIsSettled) return 1;  // Push A down
      if (!aIsSettled && bIsSettled) return -1; // Push B down
      
      // If both pending, sort by the largest total volume of debt
      double totalBalA = recA + payA;
      double totalBalB = recB + payB;
      return totalBalB.compareTo(totalBalA); 
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        title: const Text('Account Management', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)), 
        backgroundColor: Colors.white, 
        foregroundColor: Colors.black87, 
        elevation: 0,
        centerTitle: false,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- MODERN SEARCH BAR ---
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

          // --- ACCOUNTS LIST ---
          Expanded(
            child: filteredPurchasers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.group_off_rounded, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty ? 'No accounts found.' : 'No accounts matching "$_searchQuery"',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 100),
                    itemCount: filteredPurchasers.length,
                    itemBuilder: (context, index) {
                      final person = filteredPurchasers[index];
                      
                      final theyOweUs = receivables[person.id] ?? 0.0;
                      final weOweThem = payables[person.id] ?? 0.0;
                      final isSettled = theyOweUs <= 0.01 && weOweThem <= 0.01;
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => AccountDetailScreen(purchaser: person)));
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  // --- NAME & BALANCES ---
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
                                        const SizedBox(height: 8),
                                        
                                        if (theyOweUs > 0.01) 
                                          Text(
                                            'They Owe Us: ${formatIndianCurrency(theyOweUs)}', 
                                            style: TextStyle(color: Colors.green.shade600, fontWeight: FontWeight.bold, fontSize: 13)
                                          ),
                                          
                                        if (weOweThem > 0.01) 
                                          Padding(
                                            padding: EdgeInsets.only(top: theyOweUs > 0.01 ? 4.0 : 0.0),
                                            child: Text(
                                              'We Owe Them: ${formatIndianCurrency(weOweThem)}', 
                                              style: TextStyle(color: Colors.red.shade500, fontWeight: FontWeight.bold, fontSize: 13)
                                            ),
                                          ),
                                          
                                        if (isSettled)
                                          Text(
                                            'Settled / No Balance', 
                                            style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600, fontSize: 13)
                                          ),
                                      ],
                                    ),
                                  ),
                                  
                                  // --- LIGHT BLUE ARROW BUTTON ---
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.blueAccent, size: 14),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}