import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/company_model.dart';
import '../providers/company_provider.dart';
import 'package:flutter/services.dart';

class EditCompanyScreen extends ConsumerStatefulWidget {
  final Company company;
  const EditCompanyScreen({super.key, required this.company});

  @override
  ConsumerState<EditCompanyScreen> createState() => _EditCompanyScreenState();
}

class _EditCompanyScreenState extends ConsumerState<EditCompanyScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl, _add1Ctrl, _add2Ctrl, _mobCtrl, _bankCtrl, _accCtrl, _ifscCtrl, _pinCtrl, _gstinCtrl;

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
    _pinCtrl = TextEditingController(text: widget.company.pin); 
    _gstinCtrl = TextEditingController(text: widget.company.gstin);
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
    _gstinCtrl.dispose();
    super.dispose();
  }

  void _saveUpdates() async {
    if (_formKey.currentState!.validate()) {
      final updatedCompany = Company(
        id: widget.company.id,
        userId: widget.company.userId, // <-- 1. ADDED USER ID HERE TO PRESERVE OWNERSHIP
        name: _nameCtrl.text.trim(),
        address1: _add1Ctrl.text.trim(),
        address2: _add2Ctrl.text.trim(),
        mobileNumber: _mobCtrl.text.trim(),
        bankName: _bankCtrl.text.trim(),
        accountNumber: _accCtrl.text.trim(),
        ifscCode: _ifscCtrl.text.trim(),
        pin: _pinCtrl.text.trim(), 
        gstin: _gstinCtrl.text.trim(),
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

  // --- SMART KEYBOARD FIELD HELPER ---
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool isNumber = false,
    bool obscureText = false,
    int? maxLength,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
    bool isLast = false,
  }) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            FocusScope.of(context).nextFocus();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            FocusScope.of(context).previousFocus();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        maxLength: maxLength,
        textCapitalization: textCapitalization,
        textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
        onFieldSubmitted: (_) {
          if (isLast) {
            _saveUpdates();
          } else {
            FocusScope.of(context).nextFocus();
          }
        },
        decoration: InputDecoration(
          labelText: label, 
          border: const OutlineInputBorder(),
          counterText: "", 
        ),
        validator: validator,
      ),
    );
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
            
            _buildTextField(
              controller: _nameCtrl, 
              label: 'Company Name', 
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 10),
            
            _buildTextField(
              controller: _pinCtrl,
              label: 'Security PIN (4-8 Digits)',
              obscureText: true,
              isNumber: true,
              maxLength: 8,
              validator: (v) {
                if (v == null || v.trim().length < 4 || v.trim().length > 8) {
                  return 'PIN must be between 4 and 8 digits';
                }
                return null;
              },
            ),
            const SizedBox(height: 10),

            _buildTextField(
              controller: _gstinCtrl,
              label: 'Company GSTIN',
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 10),
            
            _buildTextField(controller: _mobCtrl, label: 'Mobile Number', isNumber: true),
            const SizedBox(height: 10),
            _buildTextField(controller: _add1Ctrl, label: 'Address Line 1'),
            const SizedBox(height: 10),
            _buildTextField(controller: _add2Ctrl, label: 'Address Line 2'),
            
            const SizedBox(height: 24),
            const Text('Banking Info', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            
            _buildTextField(controller: _bankCtrl, label: 'Bank Name'),
            const SizedBox(height: 10),
            _buildTextField(controller: _accCtrl, label: 'Account Number', isNumber: true),
            const SizedBox(height: 10),
            _buildTextField(controller: _ifscCtrl, label: 'IFSC Code', isLast: true),
            
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