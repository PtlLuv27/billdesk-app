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
import '../../core/database/sync_engine.dart';

class GlobalDashboardScreen extends ConsumerStatefulWidget {
  const GlobalDashboardScreen({super.key});

  @override
  ConsumerState<GlobalDashboardScreen> createState() => _GlobalDashboardScreenState();
}

class _GlobalDashboardScreenState extends ConsumerState<GlobalDashboardScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _performInitialSync();
  }

  Future<void> _performInitialSync() async {
    setState(() => _isSyncing = true);
    
    await SyncEngine.syncAll();
    
    if (mounted) {
      final userId = ref.read(authProvider);
      if (userId != null) {
        ref.invalidate(companyProvider); 
      }
      setState(() => _isSyncing = false);
    }
  }

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

  // --- GRADIENT GENERATOR FOR CARDS ---
  List<Color> _getCompanyGradient(int index) {
    final gradients = [
      [const Color(0xFF4facfe), const Color(0xFF00f2fe)], // Blue
      [const Color(0xFFff0844), const Color(0xFFffb199)], // Red/Orange
      [const Color(0xFF43e97b), const Color(0xFF38f9d7)], // Green
      [const Color(0xFFfa709a), const Color(0xFFfee140)], // Pink/Yellow
      [const Color(0xFF667eea), const Color(0xFF764ba2)], // Purple
    ];
    return gradients[index % gradients.length];
  }

  @override
  Widget build(BuildContext context) {
    final companies = ref.watch(companyProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC), // Softer, more modern background color
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Workspaces', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
            if (_isSyncing) ...[
              const SizedBox(width: 12),
              const SizedBox(
                height: 14, 
                width: 14, 
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
              ),
            ]
          ],
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent, // Making AppBar transparent for a modern look
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
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
      body: companies.isEmpty && !_isSyncing
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 24, bottom: 100),
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
                  // Wrap the card in our new Hover widget
                  child: HoverableCompanyCard(
                    company: company,
                    gradient: _getCompanyGradient(index),
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
      floatingActionButton: FloatingActionButton.extended(
        elevation: 8,
        backgroundColor: const Color(0xFF0F2027),
        foregroundColor: Colors.white,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateCompanyScreen()),
          );
        },
        icon: const Icon(Icons.add_business_rounded),
        label: const Text('New Company', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
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
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)],
              ),
              child: Icon(Icons.cloud_sync_rounded, size: 80, color: Colors.blue.shade200),
            ),
            const SizedBox(height: 32),
            const Text(
              'No Workspaces Yet',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF203A43)),
            ),
            const SizedBox(height: 12),
            Text(
              'Tap the button below to register\nyour first company to the cloud.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600, height: 1.5, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

// --- NEW: CUSTOM HOVER WIDGET ---
class HoverableCompanyCard extends StatefulWidget {
  final Company company;
  final List<Color> gradient;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const HoverableCompanyCard({
    super.key, 
    required this.company, 
    required this.gradient, 
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
        onLongPress: () {
          // Keep the existing bottom sheet for editing/deleting
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
                      widget.onEdit();
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.delete, color: Colors.red),
                    title: const Text('Delete Workspace', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    onTap: () {
                      Navigator.pop(ctx);
                      widget.onDelete();
                    },
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
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: widget.gradient.first.withOpacity(_isHovered ? 0.3 : 0.08),
                blurRadius: _isHovered ? 20 : 10,
                offset: Offset(0, _isHovered ? 8 : 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                // Decorative colorful bar on the left
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: widget.gradient,
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20).copyWith(left: 28),
                  child: Row(
                    children: [
                      Container(
                        height: 60,
                        width: 60,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: widget.gradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(Icons.apartment_rounded, color: Colors.white, size: 28),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.company.name,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1A1A1A)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _isHovered ? widget.gradient.first.withOpacity(0.1) : Colors.grey.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_forward_ios_rounded, 
                          size: 16, 
                          color: _isHovered ? widget.gradient.first : Colors.grey.shade400
                        ),
                      )
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