import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../models/company_model.dart';
import '../company_workspace/providers/company_provider.dart';

class CreateCompanyScreen extends ConsumerStatefulWidget {
  const CreateCompanyScreen({super.key});

  @override
  ConsumerState<CreateCompanyScreen> createState() => _CreateCompanyScreenState();
}

class _CreateCompanyScreenState extends ConsumerState<CreateCompanyScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Text Controllers to capture input
  final _nameController = TextEditingController();
  final _pinController = TextEditingController(); // <-- ADDED PIN CONTROLLER
  final _address1Controller = TextEditingController();
  final _address2Controller = TextEditingController();
  final _mobileController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accountController = TextEditingController();
  final _ifscController = TextEditingController();

  @override
  void dispose() {
    // Always dispose controllers to prevent memory leaks
    _nameController.dispose();
    _pinController.dispose(); // <-- DISPOSE PIN
    _address1Controller.dispose();
    _address2Controller.dispose();
    _mobileController.dispose();
    _bankNameController.dispose();
    _accountController.dispose();
    _ifscController.dispose();
    super.dispose();
  }

  // 1. ADD 'async' HERE
  void _saveCompany() async {
    if (_formKey.currentState!.validate()) {
      final uuid = const Uuid().v4();
      final currentTimestamp = DateTime.now().millisecondsSinceEpoch;

      final newCompany = Company(
        id: uuid,
        name: _nameController.text.trim(),
        pin: _pinController.text.trim(),
        address1: _address1Controller.text.trim(),
        address2: _address2Controller.text.trim(),
        mobileNumber: _mobileController.text.trim(),
        bankName: _bankNameController.text.trim(),
        accountNumber: _accountController.text.trim(),
        ifscCode: _ifscController.text.trim(),
        lastUpdated: currentTimestamp,
      );

      // 2. ADD 'await' HERE so it waits for the database to finish
      await ref.read(companyProvider.notifier).addCompany(newCompany);

      // 3. CHECK 'mounted' before showing the snackbar and popping
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${newCompany.name} created successfully!')),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Company Setup'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            const Text('Company Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Company Name', border: OutlineInputBorder()),
              validator: (value) => value == null || value.isEmpty ? 'Please enter a company name' : null,
            ),
            const SizedBox(height: 10),
            
            // --- NEW: SECURITY PIN FIELD ---
            TextFormField(
              controller: _pinController,
              obscureText: true, // Hides the numbers
              keyboardType: TextInputType.number,
              maxLength: 8,
              decoration: const InputDecoration(labelText: 'Security PIN (4-8 Digits)', border: OutlineInputBorder()),
              validator: (v) {
                if (v == null || v.trim().length < 4 || v.trim().length > 8) {
                  return 'PIN must be between 4 and 8 digits';
                }
                return null;
              },
            ),
            const SizedBox(height: 10),

            TextFormField(
              controller: _mobileController,
              decoration: const InputDecoration(labelText: 'Mobile Number', border: OutlineInputBorder()),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _address1Controller,
              decoration: const InputDecoration(labelText: 'Address Line 1', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _address2Controller,
              decoration: const InputDecoration(labelText: 'Address Line 2 (City/State/Zip)', border: OutlineInputBorder()),
            ),
            
            const SizedBox(height: 24),
            const Text('Bank Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextFormField(
              controller: _bankNameController,
              decoration: const InputDecoration(labelText: 'Bank Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _accountController,
              decoration: const InputDecoration(labelText: 'Account Number', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _ifscController,
              decoration: const InputDecoration(labelText: 'IFSC Code', border: OutlineInputBorder()),
            ),
            
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _saveCompany,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save Company', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}