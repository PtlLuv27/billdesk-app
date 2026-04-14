import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/company_model.dart'; // Added to access the Company model
import '../company_workspace/providers/company_provider.dart';
import 'create_company_screen.dart';
import '../company_workspace/views/company_workspace_screen.dart';

class GlobalDashboardScreen extends ConsumerStatefulWidget {
  const GlobalDashboardScreen({super.key});

  @override
  ConsumerState<GlobalDashboardScreen> createState() => _GlobalDashboardScreenState();
}

class _GlobalDashboardScreenState extends ConsumerState<GlobalDashboardScreen> {

  // --- THE SECURE LOGIN DIALOGUE ---
  Future<void> _promptPinAndLogin(BuildContext context, Company company, WidgetRef ref) async {
    final pinCtrl = TextEditingController();
    String? errorText;

    await showDialog(
      context: context,
      barrierDismissible: false, // Force them to enter pin or cancel
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Column(
              children: [
                const Icon(Icons.lock, size: 40, color: Colors.blue),
                const SizedBox(height: 10),
                Text('Unlock ${company.name}', textAlign: TextAlign.center),
              ],
            ),
            content: TextField(
              controller: pinCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 8,
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 8),
              decoration: InputDecoration(
                hintText: '****',
                errorText: errorText,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            actionsAlignment: MainAxisAlignment.spaceEvenly,
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context), 
                child: const Text('Cancel', style: TextStyle(color: Colors.grey))
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                onPressed: () {
                  // Fallback to '0000' just in case a company was created before the PIN update
                  final correctPin = company.pin.isEmpty ? '0000' : company.pin;

                  if (pinCtrl.text == correctPin) {
                    Navigator.pop(context); // Close dialog
                    
                    // 1. Set the active company in Riverpod
                    ref.read(activeCompanyProvider.notifier).setCompany(company);
                    
                    // 2. Navigate to the Workspace
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CompanyWorkspaceScreen()),
                    );
                  } else {
                    setState(() => errorText = 'Incorrect PIN. Try again.');
                    pinCtrl.clear();
                  }
                },
                child: const Text('Unlock'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // "Watch" the provider. The UI will auto-rebuild whenever the database changes.
    final companies = ref.watch(companyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('BillDesk Dashboard'),
        centerTitle: true,
      ),
      body: companies.isEmpty
          ? const Center(
              child: Text(
                'No companies found.\nTap + to create your first company.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: companies.length,
              itemBuilder: (context, index) {
                final company = companies[index];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.business),
                    ),
                    title: Text(company.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(company.bankName),
                    trailing: const Icon(Icons.lock, size: 16, color: Colors.blueGrey), // Changed to a lock icon
                    onTap: () => _promptPinAndLogin(context, company, ref), // Trigger secure login
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Push to the Create Company Screen
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateCompanyScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('New Company'),
      ),
    );
  }
}