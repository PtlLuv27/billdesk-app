import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart'; 
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart'; 
import 'package:shorebird_code_push/shorebird_code_push.dart'; 
import 'package:shared_preferences/shared_preferences.dart'; 
import '../../models/company_model.dart';
import '../company_workspace/providers/company_provider.dart';
import 'create_company_screen.dart';
import '../company_workspace/views/company_workspace_screen.dart';
import '../company_workspace/views/edit_company_screen.dart'; 
import '../authentication/providers/auth_provider.dart';
import '../authentication/views/auth_wrapper.dart';
import '../authentication/views/login_screen.dart'; 
import '../../core/database/sync_engine.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/secure_storage_service.dart';

class GlobalDashboardScreen extends ConsumerStatefulWidget {
  const GlobalDashboardScreen({super.key});

  @override
  ConsumerState<GlobalDashboardScreen> createState() => _GlobalDashboardScreenState();
}

class _GlobalDashboardScreenState extends ConsumerState<GlobalDashboardScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  bool _isSyncing = false;
  bool _isOnline = true; 
  
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();
  final updater = ShorebirdUpdater(); 

  List<Company> _orderedCompanies = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshIndicatorKey.currentState?.show();
      _checkForOtaUpdates(); 
    });
  }

  Future<void> _checkForOtaUpdates() async {
    try {
      final status = await updater.checkForUpdate();
      if (status == UpdateStatus.outdated && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('New Update Available! Downloading in background...'), backgroundColor: Colors.blueAccent, duration: Duration(seconds: 3)),
        );
        await updater.update();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Update ready! Please restart the app to apply changes.'),
              backgroundColor: Colors.green.shade700,
              duration: const Duration(days: 1), 
              action: SnackBarAction(label: 'OK', textColor: Colors.white, onPressed: () {}),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Shorebird update check failed: $e');
    }
  }

  Future<void> _performInitialSync() async {
    if (_isSyncing) return; 

    setState(() => _isSyncing = true);

    bool isConnected = true;
    try {
      await Supabase.instance.client.auth.getUser().timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint("Connectivity check failed. User is offline: $e");
      isConnected = false;
    }

    await SyncEngine.syncAll();
    
    if (mounted) {
      final userId = ref.read(authProvider);
      if (userId != null) {
        ref.invalidate(companyProvider); 
      }
      setState(() {
        _isOnline = isConnected; 
        _isSyncing = false;
      });
      Future.delayed(const Duration(milliseconds: 100), _loadAndSortCompanies);
    }
  }

  Future<void> _loadAndSortCompanies() async {
    final unsortedCompanies = ref.read(companyProvider);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedOrderString = prefs.getString('company_order');
      
      if (savedOrderString != null && savedOrderString.isNotEmpty) {
        final List<dynamic> savedIds = jsonDecode(savedOrderString);
        
        List<Company> newOrderedList = [];
        for (String id in savedIds) {
          final comp = unsortedCompanies.where((c) => c.id == id).firstOrNull;
          if (comp != null) newOrderedList.add(comp);
        }
        
        for (var comp in unsortedCompanies) {
          if (!newOrderedList.any((c) => c.id == comp.id)) {
            newOrderedList.add(comp);
          }
        }
        
        setState(() => _orderedCompanies = newOrderedList);
      } else {
        setState(() => _orderedCompanies = List.from(unsortedCompanies));
      }
    } catch (e) {
      setState(() => _orderedCompanies = List.from(unsortedCompanies));
    }
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final Company item = _orderedCompanies.removeAt(oldIndex);
      _orderedCompanies.insert(newIndex, item);
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> orderedIds = _orderedCompanies.map((c) => c.id).toList();
      await prefs.setString('company_order', jsonEncode(orderedIds));
    } catch (e) {
      debugPrint('Failed to save company order: $e');
    }
  }

  Future<void> _logOutOfAccount(String emailToLogOut, bool isActiveAccount, BuildContext context) async {
    final storageService = ref.read(secureStorageProvider);
    await storageService.removeSession(emailToLogOut);

    if (isActiveAccount) {
      await Supabase.instance.client.auth.signOut();
      final remainingAccounts = await storageService.getSavedEmails();
      
      if (remainingAccounts.isNotEmpty) {
        try {
          final nextToken = await storageService.getTokenForEmail(remainingAccounts.first);
          if (nextToken != null) {
            await Supabase.instance.client.auth.setSession(nextToken);
            ref.invalidate(companyProvider);
            ref.invalidate(authProvider);
            return; 
          }
        } catch (e) {
          debugPrint('Auto-swap failed: $e');
        }
      }
      
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const AuthWrapper()), (route) => false);
      }
    }
  }

  Future<void> _promptPinAndLogin(BuildContext mainContext, Company company, WidgetRef ref) async {
    final pinCtrl = TextEditingController();
    String? errorText;

    bool canAuthenticateWithBiometrics = false;
    try {
      canAuthenticateWithBiometrics = await auth.canCheckBiometrics || await auth.isDeviceSupported();
    } catch (e) {
      debugPrint("Biometrics not supported or error: $e");
    }

    if (canAuthenticateWithBiometrics && mainContext.mounted) {
      try {
        final bool didAuthenticate = await auth.authenticate(localizedReason: 'Please authenticate to unlock ${company.name}');
        if (didAuthenticate) {
          ref.read(activeCompanyProvider.notifier).setCompany(company);
          Navigator.push(mainContext, MaterialPageRoute(builder: (_) => const CompanyWorkspaceScreen()));
          pinCtrl.dispose();
          return; 
        }
      } catch (e) {
        debugPrint("Biometric Error: $e");
      }
    }

    if (!mainContext.mounted) {
      pinCtrl.dispose();
      return;
    }

    final bool? unlockSuccessful = await showDialog<bool>(
      context: mainContext,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.6), 
      builder: (dialogContext) => StatefulBuilder(
        builder: (stateContext, setState) {
          
          Future<void> attemptUnlock() async {
            final correctPin = company.pin.isEmpty ? '0000' : company.pin;
            
            if (pinCtrl.text == correctPin) {
              FocusManager.instance.primaryFocus?.unfocus();
              await Future.delayed(const Duration(milliseconds: 150));
              if (dialogContext.mounted) Navigator.pop(dialogContext, true); 
            } else {
              setState(() => errorText = 'Incorrect PIN');
              pinCtrl.clear();
            }
          }

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            elevation: 10,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.lock_outline, size: 40, color: Colors.blueAccent),
                  ),
                  const SizedBox(height: 16),
                  const Text('Workspace Secured', style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(company.name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  
                  TextField(
                    controller: pinCtrl,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 8,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 28, letterSpacing: 12, fontWeight: FontWeight.bold),
                    textInputAction: TextInputAction.done, 
                    onSubmitted: (_) => attemptUnlock(), 
                    decoration: InputDecoration(
                      hintText: '••••',
                      hintStyle: TextStyle(color: Colors.grey.shade300),
                      errorText: errorText,
                      errorStyle: const TextStyle(fontWeight: FontWeight.bold),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      counterText: "", 
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.blueAccent, width: 2)),
                    ),
                  ),
                  
                  if (canAuthenticateWithBiometrics) ...[
                    const SizedBox(height: 16),
                    IconButton(
                      icon: const Icon(Icons.fingerprint, size: 40, color: Colors.blueAccent),
                      onPressed: () async {
                        try {
                          final bool didAuthenticate = await auth.authenticate(localizedReason: 'Unlock ${company.name}');
                          if (didAuthenticate) {
                            FocusManager.instance.primaryFocus?.unfocus();
                            await Future.delayed(const Duration(milliseconds: 150));
                            if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                          }
                        } catch (e) {
                          debugPrint("Retry Biometric Error: $e");
                        }
                      },
                    ),
                    const Text('Use Fingerprint', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],

                  const SizedBox(height: 24),
                  
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                          onPressed: () async {
                            FocusManager.instance.primaryFocus?.unfocus();
                            await Future.delayed(const Duration(milliseconds: 150));
                            if (dialogContext.mounted) Navigator.pop(dialogContext, false);
                          }, 
                          child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold))
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          onPressed: attemptUnlock,
                          child: const Text('Unlock', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (unlockSuccessful == true && mainContext.mounted) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (mainContext.mounted) {
        ref.read(activeCompanyProvider.notifier).setCompany(company);
        Navigator.push(mainContext, MaterialPageRoute(builder: (_) => const CompanyWorkspaceScreen()));
      }
    }

    pinCtrl.dispose();
  }

  void _showAccountSwitcher(BuildContext context, WidgetRef ref) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    final currentEmail = currentUser?.email ?? 'Unknown Account';
    
    final storageService = ref.read(secureStorageProvider);
    List<String> savedAccounts = await storageService.getSavedEmails();
    
    if (!savedAccounts.contains(currentEmail) && currentUser != null) {
      savedAccounts.insert(0, currentEmail);
    }

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext sheetCtx, StateSetter setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(color: Colors.grey.shade600, borderRadius: BorderRadius.circular(2)),
                    ),
                    
                    ...savedAccounts.map((email) {
                      final isActive = email == currentEmail;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                        leading: CircleAvatar(
                          backgroundColor: isActive ? Colors.blueAccent : Colors.grey.shade800,
                          radius: 24,
                          child: Text(
                            email.substring(0, 1).toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                          ),
                        ),
                        title: Text(
                          email,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        trailing: isActive 
                          ? const Icon(Icons.check_circle, color: Colors.blueAccent, size: 28)
                          : null,
                        onTap: () async {
                          if (!isActive) {
                            Navigator.pop(ctx); 
                            try {
                              final token = await storageService.getTokenForEmail(email);
                              if (token != null) {
                                await Supabase.instance.client.auth.setSession(token);
                                ref.invalidate(companyProvider);
                                ref.invalidate(authProvider);
                              }
                            } catch (e) {
                              debugPrint('Session Swap Failed: $e');
                            }
                          } else {
                            Navigator.pop(ctx);
                          }
                        },
                        onLongPress: () {
                          showDialog(
                            context: sheetCtx,
                            builder: (dialogCtx) => AlertDialog(
                              title: const Text('Log out of account?'),
                              content: Text('Are you sure you want to log out of $email?'),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                                  onPressed: () async {
                                    Navigator.pop(dialogCtx); // Close the dialog
                                    
                                    if (isActive) {
                                      Navigator.pop(sheetCtx); // Close the bottom sheet entirely
                                    }
                                    
                                    await _logOutOfAccount(email, isActive, context);
                                    
                                    if (!isActive) {
                                      setSheetState(() {
                                        savedAccounts.remove(email);
                                      });
                                    }
                                  },
                                  child: const Text('Log out'),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    }),

                    const Divider(color: Colors.white24, height: 24),

                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                      leading: Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white54, width: 1)),
                        child: const Icon(Icons.add, color: Colors.white, size: 28),
                      ),
                      title: const Text('Add workspace account', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                      onTap: () {
                        Navigator.pop(ctx); 
                        if (context.mounted) {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())); 
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final riverpodCompanies = ref.watch(companyProvider);
    if (_orderedCompanies.length != riverpodCompanies.length) {
       _loadAndSortCompanies();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC), 
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _showAccountSwitcher(context, ref),
        ),
        title: GestureDetector(
          onTap: () {
            _refreshIndicatorKey.currentState?.show();
          },
          child: const Text(
            'Workspaces', 
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: () async {
              final currentUserEmail = Supabase.instance.client.auth.currentUser?.email;
              if (currentUserEmail != null) {
                await _logOutOfAccount(currentUserEmail, true, context);
              }
            },
          )
        ],
      ),
      body: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse, PointerDeviceKind.trackpad},
        ),
        child: RefreshIndicator(
          key: _refreshIndicatorKey, 
          onRefresh: _performInitialSync,
          color: Colors.blueAccent,
          backgroundColor: Colors.white,
          child: _orderedCompanies.isEmpty && !_isSyncing
              ? _buildEmptyState()
              : ReorderableListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 24, bottom: 100),
                  itemCount: _orderedCompanies.length,
                  onReorder: _onReorder,
                  buildDefaultDragHandles: false, // 🔥 REMOVES THE UGLY LINES
                  proxyDecorator: (Widget child, int index, Animation<double> animation) {
                    return Material(
                      color: Colors.transparent,
                      elevation: 12,
                      shadowColor: Colors.blueAccent.withOpacity(0.5),
                      child: child,
                    );
                  },
                  itemBuilder: (context, index) {
                    final company = _orderedCompanies[index];
                    
                    // 🔥 Wrap with ReorderableDelayedDragStartListener to drag from anywhere
                    return ReorderableDelayedDragStartListener(
                      key: Key(company.id),
                      index: index,
                      child: HoverableCompanyCard(
                        company: company,
                        isOnline: _isOnline, 
                        onTap: () => _promptPinAndLogin(context, company, ref),
                        onEdit: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditCompanyScreen(company: company))),
                        onDelete: () {
                          showDialog(
                            context: context,
                            builder: (dialogCtx) => AlertDialog(
                              title: const Text('Delete Workspace?'),
                              content: const Text('Are you sure? This will hide the company from your dashboard.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                  onPressed: () {
                                    setState(() {
                                      _orderedCompanies.removeWhere((c) => c.id == company.id);
                                    });
                                    ref.read(companyProvider.notifier).deleteCompany(company);
                                    Navigator.pop(dialogCtx);
                                  },
                                  child: const Text('Delete'),
                                )
                              ],
                            )
                          );
                        },
                      ),
                    );
                  },
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null, 
        elevation: 8,
        backgroundColor: Colors.blueAccent, 
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateCompanyScreen())),
        icon: const Icon(Icons.business_center_rounded),
        label: const Text('New Company', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25), 
        Center(
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 800),
            tween: Tween(begin: 0.0, end: 1.0),
            curve: Curves.easeOutBack, 
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
              );
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)]),
                  child: Icon(Icons.cloud_sync_rounded, size: 80, color: Colors.blue.shade200),
                ),
                const SizedBox(height: 32),
                const Text('No Workspaces Yet', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF203A43))),
                const SizedBox(height: 12),
                Text(
                  'Tap the button below to register\nyour first company to the cloud.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600, height: 1.5, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// --- HOVER WIDGET ---
class HoverableCompanyCard extends StatefulWidget {
  final Company company;
  final bool isOnline; 
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const HoverableCompanyCard({
    super.key, 
    required this.company, 
    required this.isOnline, 
    required this.onTap, 
    required this.onEdit, 
    required this.onDelete
  });

  @override
  State<HoverableCompanyCard> createState() => _HoverableCompanyCardState();
}

class _HoverableCompanyCardState extends State<HoverableCompanyCard> {
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
        onDoubleTap: () {
          showModalBottomSheet(
            context: context,
            builder: (ctx) => SafeArea(
              child: Wrap(
                children: [
                  ListTile(
                    leading: const Icon(Icons.edit, color: Colors.blue),
                    title: const Text('Edit Workspace Settings'),
                    onTap: () { Navigator.pop(ctx); widget.onEdit(); },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.delete, color: Colors.red),
                    title: const Text('Delete Workspace', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    onTap: () { Navigator.pop(ctx); widget.onDelete(); },
                  ),
                ],
              ),
            ),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.only(bottom: 16),
          transform: Matrix4.identity()..scale(_isHovered ? 1.02 : 1.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20), 
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(_isHovered ? 0.08 : 0.04),
                blurRadius: _isHovered ? 16 : 8,
                offset: Offset(0, _isHovered ? 8 : 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                Positioned(
                  left: 0, top: 0, bottom: 0, width: 8,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF00E5FF), Color(0xFF2979FF)], 
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20).copyWith(left: 28), 
                  child: Row(
                    children: [
                      Container(
                        height: 56, 
                        width: 56,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF00E5FF), Color(0xFF2979FF)], 
                            begin: Alignment.topLeft, 
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(Icons.domain, color: Colors.white, size: 28) 
                        ),
                      ),
                      const SizedBox(width: 16),
                      
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.company.name, 
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1A1A1A)), 
                              maxLines: 1, 
                              overflow: TextOverflow.ellipsis
                            ),
                            const SizedBox(height: 6),
                            
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                widget.company.gstin.isNotEmpty ? 'GST: ${widget.company.gstin}' : 'Bank: ${widget.company.bankName}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: widget.isOnline ? Colors.green.shade50 : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.isOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded, 
                              color: widget.isOnline ? Colors.green.shade600 : Colors.red.shade600, 
                              size: 16
                            ),
                            const SizedBox(width: 6),
                            Text(
                              widget.isOnline ? 'Cloud Sync' : 'Offline', 
                              style: TextStyle(
                                color: widget.isOnline ? Colors.green.shade700 : Colors.red.shade700, 
                                fontWeight: FontWeight.bold, 
                                fontSize: 12
                              )
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}