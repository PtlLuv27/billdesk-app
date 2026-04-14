import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/purchaser_model.dart';
import '../providers/purchaser_provider.dart';

class EditPurchaserScreen extends ConsumerStatefulWidget {
  final Purchaser purchaser;
  const EditPurchaserScreen({super.key, required this.purchaser});

  @override
  ConsumerState<EditPurchaserScreen> createState() => _EditPurchaserScreenState();
}

class _EditPurchaserScreenState extends ConsumerState<EditPurchaserScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl, _add1Ctrl, _add2Ctrl, _partCtrl, _gstinCtrl, _hsnCtrl, _sgstCtrl, _cgstCtrl, _igstCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.purchaser.name);
    _add1Ctrl = TextEditingController(text: widget.purchaser.address1);
    _add2Ctrl = TextEditingController(text: widget.purchaser.address2);
    _partCtrl = TextEditingController(text: widget.purchaser.particulars);
    _gstinCtrl = TextEditingController(text: widget.purchaser.gstin);
    _hsnCtrl = TextEditingController(text: widget.purchaser.hsnNo);
    _sgstCtrl = TextEditingController(text: widget.purchaser.sgstRate.toString());
    _cgstCtrl = TextEditingController(text: widget.purchaser.cgstRate.toString());
    _igstCtrl = TextEditingController(text: widget.purchaser.igstRate.toString());
  }

  void _savePurchaser() async {
    if (_formKey.currentState!.validate()) {
      final updatedPurchaser = Purchaser(
        id: widget.purchaser.id,
        name: _nameCtrl.text.trim(),
        address1: _add1Ctrl.text.trim(),
        address2: _add2Ctrl.text.trim(),
        particulars: _partCtrl.text.trim(),
        gstin: _gstinCtrl.text.trim(),
        hsnNo: _hsnCtrl.text.trim(),
        sgstRate: double.tryParse(_sgstCtrl.text) ?? 0.0,
        cgstRate: double.tryParse(_cgstCtrl.text) ?? 0.0,
        igstRate: double.tryParse(_igstCtrl.text) ?? 0.0,
        lastUpdated: DateTime.now().millisecondsSinceEpoch,
      );

      await ref.read(purchaserProvider.notifier).updatePurchaser(updatedPurchaser);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Purchaser Updated!')));
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Purchaser')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Purchaser Name', border: OutlineInputBorder()), validator: (v) => v!.isEmpty ? 'Required' : null),
            const SizedBox(height: 10),
            TextFormField(controller: _gstinCtrl, decoration: const InputDecoration(labelText: 'GSTIN', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextFormField(controller: _add1Ctrl, decoration: const InputDecoration(labelText: 'Address 1', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextFormField(controller: _add2Ctrl, decoration: const InputDecoration(labelText: 'Address 2', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextFormField(controller: _partCtrl, decoration: const InputDecoration(labelText: 'Default Item', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextFormField(controller: _hsnCtrl, decoration: const InputDecoration(labelText: 'HSN No.', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: TextFormField(controller: _sgstCtrl, decoration: const InputDecoration(labelText: 'SGST %', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                const SizedBox(width: 10),
                Expanded(child: TextFormField(controller: _cgstCtrl, decoration: const InputDecoration(labelText: 'CGST %', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                const SizedBox(width: 10),
                Expanded(child: TextFormField(controller: _igstCtrl, decoration: const InputDecoration(labelText: 'IGST %', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
              ],
            ),
            const SizedBox(height: 30),
            ElevatedButton(onPressed: _savePurchaser, child: const Text('Save Changes')),
          ],
        ),
      ),
    );
  }
}