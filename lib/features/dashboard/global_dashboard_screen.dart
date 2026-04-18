import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart'; 
import '../../models/company_model.dart';
import '../company_workspace/providers/company_provider.dart';
import 'create_company_screen.dart';
import '../company_workspace/views/company_workspace_screen.dart';
import '../company_workspace/views/edit_company_screen.dart'; 
import '../authentication/providers/auth_provider.dart';
import '../authentication/views/auth_wrapper.dart';

class GlobalDashboardScreen extends ConsumerStatefulWidget {
  const GlobalDashboardScreen({super.key});

  @override
  ConsumerState<GlobalDashboardScreen> createState() => _GlobalDashboardScreenState();
}

class _GlobalDashboardScreenState extends ConsumerState<GlobalDashboardScreen> {
  final LocalAuthentication auth = LocalAuthentication();

  Future<void> _promptPinAndLogin(BuildContext context, Company company, WidgetRef ref) async {
    final pinCtrl = TextEditingController();
    String? errorText;

    bool canAuthenticateWithBiometrics = false;
    try {
      canAuthenticateWithBiometrics = await auth.canCheckBiometrics || await auth.isDeviceSupported();
    } catch (e) {
      debugPrint("Biometrics not supported or error: $e");
    }

    if (canAuthenticateWithBiometrics && context.mounted) {
      try {
        // --- FIX: Removed the 'options:' parameter causing the error ---
        final bool didAuthenticate = await auth.authenticate(
          localizedReason: 'Please authenticate to unlock ${company.name}',
        );
        
        if (didAuthenticate) {
          ref.read(activeCompanyProvider.notifier).setCompany(company);
          Navigator.push(context, MaterialPageRoute(builder: (context) => const CompanyWorkspaceScreen()));
          return; 
        }
      } catch (e) {
        debugPrint("Biometric Error: $e");
      }
    }

    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.6), 
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          
          void attemptUnlock() {
            final correctPin = company.pin.isEmpty ? '0000' : company.pin;
            if (pinCtrl.text == correctPin) {
              Navigator.pop(context);
              ref.read(activeCompanyProvider.notifier).setCompany(company);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CompanyWorkspaceScreen()),
              );
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
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
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
                          // --- FIX: Removed the 'options:' parameter here too ---
                          final bool didAuthenticate = await auth.authenticate(
                            localizedReason: 'Unlock ${company.name}',
                          );
                          if (didAuthenticate && context.mounted) {
                            Navigator.pop(context);
                            ref.read(activeCompanyProvider.notifier).setCompany(company);
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const CompanyWorkspaceScreen()));
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
                          onPressed: () => Navigator.pop(context), 
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
  }

  @override
  Widget build(BuildContext context) {
    final companies = ref.watch(companyProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade100, 
      appBar: AppBar(
        title: const Text('Workspaces', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const AuthWrapper()),
                  (route) => false,
                );
              }
            },
          )
        ],
      ),
      body: companies.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              itemCount: companies.length,
              itemBuilder: (context, index) {
                final company = companies[index];
                
                return TweenAnimationBuilder<double>(
                  duration: Duration(milliseconds: 400 + (index * 150)), 
                  tween: Tween(begin: 0.0, end: 1.0),
                  curve: Curves.easeOutQuart,
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset(0, 50 * (1 - value)), 
                      child: Opacity(
                        opacity: value.clamp(0.0, 1.0), 
                        child: child,
                      ),
                    );
                  },
                  child: _buildCompanyCard(context, company, ref),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        elevation: 4,
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateCompanyScreen()),
          );
        },
        icon: const Icon(Icons.add_business_rounded),
        label: const Text('New Company', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildCompanyCard(BuildContext context, Company company, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _promptPinAndLogin(context, company, ref),
          
          onLongPress: () {
            showModalBottomSheet(
              context: context,
              builder: (ctx) => SafeArea(
                child: Wrap(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.edit, color: Colors.blue),
                      title: const Text('Edit Workspace Settings'),
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => EditCompanyScreen(company: company)));
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.delete, color: Colors.red),
                      title: const Text('Delete Workspace', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      onTap: () {
                        Navigator.pop(ctx);
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
                  ],
                ),
              ),
            );
          },
          
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  height: 56,
                  width: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.blueAccent, Colors.lightBlue],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Icon(Icons.business_center_rounded, color: Colors.white, size: 28),
                  ),
                ),
                const SizedBox(width: 16),
                
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        company.name,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        company.gstin.isNotEmpty ? 'GST: ${company.gstin}' : 'Bank: ${company.bankName}',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lock_rounded, size: 14, color: Colors.green.shade700),
                      const SizedBox(width: 4),
                      Text('Secure', style: TextStyle(color: Colors.green.shade700, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 800),
        tween: Tween(begin: 0.0, end: 1.0),
        curve: Curves.easeOutBack, 
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: Opacity(
              opacity: value.clamp(0.0, 1.0), 
              child: child,
            ),
          );
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business_rounded, size: 100, color: Colors.grey.shade300),
            const SizedBox(height: 24),
            const Text(
              'No Workspaces Yet',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the button below to register\nyour first company locally.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade500, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}