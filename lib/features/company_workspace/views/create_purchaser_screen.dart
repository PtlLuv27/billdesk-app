import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../models/purchaser_model.dart';
import '../providers/purchaser_provider.dart';
import 'package:flutter/services.dart'; // <-- Added for keyboard listening

class CreatePurchaserScreen extends ConsumerStatefulWidget {
  const CreatePurchaserScreen({super.key});

  @override
  ConsumerState<CreatePurchaserScreen> createState() => _CreatePurchaserScreenState();
}

class _CreatePurchaserScreenState extends ConsumerState<CreatePurchaserScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _nameController = TextEditingController();
  final _address1Controller = TextEditingController();
  final _address2Controller = TextEditingController();
  final _particularsController = TextEditingController();
  final _gstinController = TextEditingController();
  final _hsnController = TextEditingController();
  final _sgstController = TextEditingController(text: '0.0');
  final _cgstController = TextEditingController(text: '0.0');
  final _igstController = TextEditingController(text: '0.0');

  @override
  void dispose() {
    _nameController.dispose();
    _address1Controller.dispose();
    _address2Controller.dispose();
    _particularsController.dispose();
    _gstinController.dispose();
    _hsnController.dispose();
    _sgstController.dispose();
    _cgstController.dispose();
    _igstController.dispose();
    super.dispose();
  }

  void _savePurchaser() {
    if (_formKey.currentState!.validate()) {
      final newPurchaser = Purchaser(
        id: const Uuid().v4(),
        name: _nameController.text.trim(),
        address1: _address1Controller.text.trim(),
        address2: _address2Controller.text.trim(),
        particulars: _particularsController.text.trim(),
        gstin: _gstinController.text.trim(),
        hsnNo: _hsnController.text.trim(),
        sgstRate: double.tryParse(_sgstController.text) ?? 0.0,
        cgstRate: double.tryParse(_cgstController.text) ?? 0.0,
        igstRate: double.tryParse(_igstController.text) ?? 0.0,
        lastUpdated: DateTime.now().millisecondsSinceEpoch,
      );

      ref.read(purchaserProvider.notifier).addPurchaser(newPurchaser);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${newPurchaser.name} added to Global CRM!')),
      );
      Navigator.pop(context);
    }
  }

  // --- SMART KEYBOARD FIELD HELPER ---
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool isNumber = false,
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
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        textCapitalization: textCapitalization,
        textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
        onFieldSubmitted: (_) {
          if (isLast) {
            _savePurchaser();
          } else {
            FocusScope.of(context).nextFocus();
          }
        },
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        validator: validator,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Purchaser (Global)')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            const Text('Client/Vendor Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            
            _buildTextField(
              controller: _nameController,
              label: 'Purchaser Name',
              validator: (value) => value == null || value.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 10),
            
            _buildTextField(
              controller: _address1Controller,
              label: 'Address Line 1',
            ),
            const SizedBox(height: 10),
            
            _buildTextField(
              controller: _address2Controller,
              label: 'City/State',
            ),
            
            const SizedBox(height: 24),
            const Text('Billing & Tax Defaults', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            
            _buildTextField(
              controller: _gstinController,
              label: 'GSTIN',
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 10),
            
            _buildTextField(
              controller: _particularsController,
              label: 'Default Item (e.g., NILGIRI WOODEN SIZE)',
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 10),
            
            _buildTextField(
              controller: _hsnController,
              label: 'HSN No.',
            ),
            const SizedBox(height: 10),
            
            Row(
              children: [
                Expanded(child: _buildTextField(controller: _sgstController, label: 'SGST %', isNumber: true)),
                const SizedBox(width: 10),
                Expanded(child: _buildTextField(controller: _cgstController, label: 'CGST %', isNumber: true)),
                const SizedBox(width: 10),
                Expanded(child: _buildTextField(controller: _igstController, label: 'IGST %', isNumber: true, isLast: true)), // Last Field!
              ],
            ),
            
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _savePurchaser,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save to Global CRM', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}