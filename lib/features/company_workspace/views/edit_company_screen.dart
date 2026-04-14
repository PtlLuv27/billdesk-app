import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/company_model.dart';
import '../providers/company_provider.dart';

class EditCompanyScreen extends ConsumerStatefulWidget {
  final Company company;
  const EditCompanyScreen({super.key, required this.company});

  @override
  ConsumerState<EditCompanyScreen> createState() => _EditCompanyScreenState();
}

class _EditCompanyScreenState extends ConsumerState<EditCompanyScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl, _add1Ctrl, _add2Ctrl, _mobCtrl, _bankCtrl, _accCtrl, _ifscCtrl, _pinCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.company.name);
    _add1Ctrl = TextEditingController(text: widget.company.address1);
    _add2Ctrl = TextEditingController(text: widget.company.address2);
    _mobCtrl = TextEditingController(text: widget.company.mobileNumber);
    _bankCtrl = TextEditingController(text: widget.company.bankName);
    _accCtrl = TextEditingController(text: widget.company.accountNumber);
    _ifscCtrl = TextEditingController(text: widget.company.ifscCode);
    _pinCtrl = TextEditingController(text: widget.company.pin); // <-- Initialize PIN Controller
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _add1Ctrl.dispose();
    _add2Ctrl.dispose();
    _mobCtrl.dispose();
    _bankCtrl.dispose();
    _accCtrl.dispose();
    _ifscCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  void _saveUpdates() async {
    if (_formKey.currentState!.validate()) {
      final updatedCompany = Company(
        id: widget.company.id,
        name: _nameCtrl.text.trim(),
        address1: _add1Ctrl.text.trim(),
        address2: _add2Ctrl.text.trim(),
        mobileNumber: _mobCtrl.text.trim(),
        bankName: _bankCtrl.text.trim(),
        accountNumber: _accCtrl.text.trim(),
        ifscCode: _ifscCtrl.text.trim(),
        pin: _pinCtrl.text.trim(), // <-- Save the PIN
        lastUpdated: DateTime.now().millisecondsSinceEpoch,
        isDeleted: widget.company.isDeleted,
      );

      await ref.read(companyProvider.notifier).updateCompany(updatedCompany);
      ref.read(activeCompanyProvider.notifier).setCompany(updatedCompany);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile Updated!')));
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Company Profile')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Master Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextFormField(
              controller: _nameCtrl, 
              decoration: const InputDecoration(labelText: 'Company Name', border: OutlineInputBorder()), 
              validator: (v) => v!.isEmpty ? 'Required' : null
            ),
            const SizedBox(height: 10),
            
            // --- NEW: SECURITY PIN FIELD ---
            TextFormField(
              controller: _pinCtrl,
              obscureText: true, // Hides the numbers for security
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
            
            TextFormField(controller: _mobCtrl, decoration: const InputDecoration(labelText: 'Mobile Number', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextFormField(controller: _add1Ctrl, decoration: const InputDecoration(labelText: 'Address Line 1', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextFormField(controller: _add2Ctrl, decoration: const InputDecoration(labelText: 'Address Line 2', border: OutlineInputBorder())),
            
            const SizedBox(height: 24),
            const Text('Banking Info', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            
            TextFormField(controller: _bankCtrl, decoration: const InputDecoration(labelText: 'Bank Name', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextFormField(controller: _accCtrl, decoration: const InputDecoration(labelText: 'Account Number', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextFormField(controller: _ifscCtrl, decoration: const InputDecoration(labelText: 'IFSC Code', border: OutlineInputBorder())),
            
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _saveUpdates,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}