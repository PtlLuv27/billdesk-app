import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart'; 
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart'; 
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
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _navigateTab(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic, 
    );
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  String _getTabTitle(String baseName) {
    switch (_currentIndex) {
      case 0: return baseName;
      case 1: return "$baseName's Parties";
      case 2: return "$baseName's Sales";
      case 3: return "$baseName's Purchases";
      case 4: return "$baseName's Ledger";
      case 5: return "$baseName's Accounts";
      default: return baseName;
    }
  }

  // --- 🔥 UPDATED GRADIENTS ---
  LinearGradient _getTabGradient() {
    switch (_currentIndex) {
      case 0: // Home -> Light Blue/Cyan
        return const LinearGradient(colors: [Color(0xFF2979FF), Color(0xFF00E5FF)]);
      case 1: // Parties -> Purple
        return const LinearGradient(colors: [Color(0xFF651FFF), Color(0xFFE040FB)]);
      case 2: // Sales -> Indigo (Moved from Ledger)
        return const LinearGradient(colors: [Color(0xFF304FFE), Color(0xFF536DFE)]);
      case 3: // Purchase -> Red
        return const LinearGradient(colors: [Color(0xFFD50000), Color(0xFFFF5252)]);
      case 4: // Ledger -> Premium Slate / BlueGrey
       return const LinearGradient(colors: [Color(0xFFFF3D00), Color(0xFFFF9100)], begin: Alignment.topLeft, end: Alignment.bottomRight,);
      case 5: // Accounts -> Teal
        return const LinearGradient(colors: [Color(0xFF00BFA5), Color(0xFF1DE9B6)]);
      default:
        return const LinearGradient(colors: [Colors.blueAccent, Colors.lightBlue]);
    }
  }

  Color _getActiveNavColor() {
    switch (_currentIndex) {
      case 0: return Colors.blueAccent;
      case 1: return Colors.purpleAccent;
      case 2: return Colors.indigoAccent;
      case 3: return Colors.redAccent;
      case 4: return const Color(0xFFFF6D00);    
      case 5: return Colors.teal;
      default: return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCompany = ref.watch(activeCompanyProvider);
    final companyName = activeCompany?.name ?? 'Workspace';

    final List<Widget> pages = [
      CompanyHomeTab(onNavigateTab: _navigateTab), 
      const PurchaserTab(),
      const SalesTab(),
      const PurchaseTab(),
      const LedgerTab(),
      const AccountTab(),
    ];

    // 🔥 Contrast Logic: Check if current tab is Home (light background)
    final bool isLightBackground = _currentIndex == 0;
    final Color dateTextColor = isLightBackground ? const Color(0xFF003366) : Colors.white;
    final Color datePillBgColor = isLightBackground ? Colors.white.withOpacity(0.4) : Colors.white.withOpacity(0.2);
    final Color datePillBorderColor = isLightBackground ? Colors.white.withOpacity(0.6) : Colors.white.withOpacity(0.3);

    return Scaffold(
      appBar: AppBar(
        title: Text(_getTabTitle(companyName), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        centerTitle: false,
        elevation: 4,
        shadowColor: _getActiveNavColor().withOpacity(0.4), 
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            ref.read(activeCompanyProvider.notifier).setCompany(null);
            Navigator.pop(context);
          },
        ),
        flexibleSpace: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          decoration: BoxDecoration(
            gradient: _getTabGradient(),
          ),
        ),
        actions: [
          // 🔥 UPDATED DATE PILL WITH DYNAMIC CONTRAST
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            margin: const EdgeInsets.only(right: 16, top: 12, bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: datePillBgColor, 
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: datePillBorderColor),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: dateTextColor),
                const SizedBox(width: 6),
                Text(
                  DateFormat('dd MMM yyyy').format(DateTime.now()),
                  style: TextStyle(color: dateTextColor, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
      body: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
          },
        ),
        child: PageView(
          controller: _pageController,
          onPageChanged: _onPageChanged,
          physics: const BouncingScrollPhysics(), 
          children: pages,
        ),
      ),
      bottomNavigationBar: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          type: BottomNavigationBarType.fixed, 
          selectedItemColor: _getActiveNavColor(), 
          unselectedItemColor: Colors.grey.shade400,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10),
          elevation: 10,
          onTap: _navigateTab, 
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Parties'),
            BottomNavigationBarItem(icon: Icon(Icons.point_of_sale), label: 'Sales'),
            BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'Purchase'),
            BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Ledger'),
            BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'Account'),
          ],
        ),
      ),
    );
  }
}