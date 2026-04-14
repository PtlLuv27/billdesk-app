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

  // Placeholder screens for your 5 modules
  final List<Widget> _pages = [
    const CompanyHomeTab(),
    const PurchaserTab(),
    const SalesTab(),
    const PurchaseTab(),
    const LedgerTab(),
    const AccountTab(),
  ];

  @override
  Widget build(BuildContext context) {
    // Read the active company from Riverpod to display its name in the AppBar
    final activeCompany = ref.watch(activeCompanyProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(activeCompany?.name ?? 'Workspace'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Clear the active company when leaving the workspace
            ref.read(activeCompanyProvider.notifier).setCompany(null);
            Navigator.pop(context);
          },
        ),
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed, // <-- VERY IMPORTANT for 6 tabs
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
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
          ), // <-- Added
        ],
      ),
    );
  }
}
