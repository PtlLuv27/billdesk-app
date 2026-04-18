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
      return const Center(child: Text('Loading Workspace...'));
    }

    // Filter Invoices & Payments by current workspace
    final invoices = allInvoices.where((i) => i.companyId == activeCompany.id).toList();
    final payments = allPayments.where((p) => p.companyId == activeCompany.id).toList();

    // --- APPLY SEARCH FILTER ---
    final filteredPurchasers = allPurchasers.where((p) {
      return p.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Account Management', style: TextStyle(fontWeight: FontWeight.bold)), 
        backgroundColor: Colors.white, 
        foregroundColor: Colors.black, 
        elevation: 0
      ),
      body: Column(
        children: [
          // --- SEARCH BAR ---
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search Account / Party Name...',
                prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
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
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          
          // --- ACCOUNTS LIST ---
          Expanded(
            child: filteredPurchasers.isEmpty
                ? Center(
                    child: Text(
                      _searchQuery.isEmpty ? 'No accounts found.' : 'No accounts matching "$_searchQuery"',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 80),
                    itemCount: filteredPurchasers.length,
                    itemBuilder: (context, index) {
                      final person = filteredPurchasers[index];

                      // Math: They Owe Us (Sales)
                      final sales = invoices.where((i) => i.purchaserId == person.id && i.type == 'sales').fold(0.0, (s, i) => s + i.totalAmount);
                      final received = payments.where((p) => p.purchaserId == person.id && p.type == 'received').fold(0.0, (s, p) => s + p.amount);
                      final theyOweUs = sales - received;

                      // Math: We Owe Them (Purchases)
                      final purchases = invoices.where((i) => i.purchaserId == person.id && i.type == 'purchase').fold(0.0, (s, i) => s + i.totalAmount);
                      final paid = payments.where((p) => p.purchaserId == person.id && p.type == 'paid').fold(0.0, (s, p) => s + p.amount);
                      final weOweThem = purchases - paid;

                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          title: Text(person.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (theyOweUs > 0) Text('They Owe Us: ${formatIndianCurrency(theyOweUs)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14)),
                                if (weOweThem > 0) Text('We Owe Them: ${formatIndianCurrency(weOweThem)}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14)),
                                if (theyOweUs <= 0 && weOweThem <= 0) const Text('Settled / No Balance', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600, fontSize: 13)),
                              ],
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                            child: const Icon(Icons.arrow_forward_ios, color: Colors.blueAccent, size: 16),
                          ),
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => AccountDetailScreen(purchaser: person)));
                          },
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