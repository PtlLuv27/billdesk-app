import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../models/purchaser_model.dart';
import '../providers/purchaser_provider.dart';

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
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Purchaser Name', border: OutlineInputBorder()),
              validator: (value) => value == null || value.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _address1Controller,
              decoration: const InputDecoration(labelText: 'Address Line 1', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _address2Controller,
              decoration: const InputDecoration(labelText: 'City/State', border: OutlineInputBorder()),
            ),
            
            const SizedBox(height: 24),
            const Text('Billing & Tax Defaults', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextFormField(
              controller: _gstinController,
              decoration: const InputDecoration(labelText: 'GSTIN', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _particularsController,
              decoration: const InputDecoration(labelText: 'Default Item (e.g., NILGIRI WOODEN SIZE)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _hsnController,
              decoration: const InputDecoration(labelText: 'HSN No.', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: TextFormField(controller: _sgstController, decoration: const InputDecoration(labelText: 'SGST %', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                const SizedBox(width: 10),
                Expanded(child: TextFormField(controller: _cgstController, decoration: const InputDecoration(labelText: 'CGST %', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                const SizedBox(width: 10),
                Expanded(child: TextFormField(controller: _igstController, decoration: const InputDecoration(labelText: 'IGST %', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
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