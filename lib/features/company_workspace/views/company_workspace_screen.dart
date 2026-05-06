import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/company_provider.dart';
import 'tabs/company_home_tab.dart';
import 'tabs/purchaser_tab.dart';
import 'tabs/sales_tab.dart';
import 'tabs/purchase_tab.dart';
import 'tabs/ledger_tab.dart';
import 'tabs/account_tab.dart';

class CompanyWorkspaceScreen extends ConsumerStatefulWidget {
  const CompanyWorkspaceScreen({super.key});

  @override
  ConsumerState<CompanyWorkspaceScreen> createState() =>
      _CompanyWorkspaceScreenState();
}

class _CompanyWorkspaceScreenState
    extends ConsumerState<CompanyWorkspaceScreen> {
  int _currentIndex = 0;

  // --- NEW: Function to handle tab switching from anywhere ---
  void _navigateTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Read the active company from Riverpod
    final activeCompany = ref.watch(activeCompanyProvider);

    // --- MOVED: Define pages inside build() so we can pass _navigateTab ---
    final List<Widget> pages = [
      CompanyHomeTab(onNavigateTab: _navigateTab), // Passes the function down!
      const PurchaserTab(),
      const SalesTab(),
      const PurchaseTab(),
      const LedgerTab(),
      const AccountTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(activeCompany?.name ?? 'Workspace'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            ref.read(activeCompanyProvider.notifier).setCompany(null);
            Navigator.pop(context);
          },
        ),
      ),
      // --- UPDATED: IndexedStack keeps your other tabs loaded in memory ---
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed, // VERY IMPORTANT for 6 tabs
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: _navigateTab, // Use the shared function here too
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Parties'),
          BottomNavigationBarItem(
            icon: Icon(Icons.point_of_sale),
            label: 'Sales',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Purchase',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Ledger'),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}