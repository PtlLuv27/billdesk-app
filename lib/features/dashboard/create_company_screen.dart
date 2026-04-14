import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../models/company_model.dart';
import '../company_workspace/providers/company_provider.dart';
import 'package:flutter/services.dart';

class CreateCompanyScreen extends ConsumerStatefulWidget {
  const CreateCompanyScreen({super.key});

  @override
  ConsumerState<CreateCompanyScreen> createState() => _CreateCompanyScreenState();
}

class _CreateCompanyScreenState extends ConsumerState<CreateCompanyScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Text Controllers to capture input
  final _nameController = TextEditingController();
  final _pinController = TextEditingController(); 
  final _gstinController = TextEditingController(); 
  final _address1Controller = TextEditingController();
  final _address2Controller = TextEditingController();
  final _mobileController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accountController = TextEditingController();
  final _ifscController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _pinController.dispose(); 
    _gstinController.dispose(); 
    _address1Controller.dispose();
    _address2Controller.dispose();
    _mobileController.dispose();
    _bankNameController.dispose();
    _accountController.dispose();
    _ifscController.dispose();
    super.dispose();
  }

  void _saveCompany() async {
    if (_formKey.currentState!.validate()) {
      final uuid = const Uuid().v4();
      final currentTimestamp = DateTime.now().millisecondsSinceEpoch;

      final newCompany = Company(
        id: uuid,
        name: _nameController.text.trim(),
        pin: _pinController.text.trim(),
        gstin: _gstinController.text.trim(),
        address1: _address1Controller.text.trim(),
        address2: _address2Controller.text.trim(),
        mobileNumber: _mobileController.text.trim(),
        bankName: _bankNameController.text.trim(),
        accountNumber: _accountController.text.trim(),
        ifscCode: _ifscController.text.trim(),
        lastUpdated: currentTimestamp,
      );

      await ref.read(companyProvider.notifier).addCompany(newCompany);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${newCompany.name} created successfully!')),
        );
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
            _saveCompany(); // Auto-save if Enter is pressed on the last field
          } else {
            FocusScope.of(context).nextFocus();
          }
        },
        decoration: InputDecoration(
          labelText: label, 
          border: const OutlineInputBorder(),
          counterText: "", // Hides the character counter below maxLength fields
        ),
        validator: validator,
      ),
    );
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
            
            _buildTextField(
              controller: _nameController,
              label: 'Company Name',
              validator: (value) => value == null || value.isEmpty ? 'Please enter a company name' : null,
            ),
            const SizedBox(height: 10),
            
            _buildTextField(
              controller: _pinController,
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
              controller: _gstinController,
              label: 'Company GSTIN',
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 10),

            _buildTextField(
              controller: _mobileController,
              label: 'Mobile Number',
              isNumber: true,
            ),
            const SizedBox(height: 10),
            
            _buildTextField(
              controller: _address1Controller,
              label: 'Address Line 1',
            ),
            const SizedBox(height: 10),
            
            _buildTextField(
              controller: _address2Controller,
              label: 'Address Line 2 (City/State/Zip)',
            ),
            
            const SizedBox(height: 24),
            const Text('Bank Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            
            _buildTextField(
              controller: _bankNameController,
              label: 'Bank Name',
            ),
            const SizedBox(height: 10),
            
            _buildTextField(
              controller: _accountController,
              label: 'Account Number',
              isNumber: true,
            ),
            const SizedBox(height: 10),
            
            _buildTextField(
              controller: _ifscController,
              label: 'IFSC Code',
              isLast: true, // This is the last field, pressing enter will trigger save!
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