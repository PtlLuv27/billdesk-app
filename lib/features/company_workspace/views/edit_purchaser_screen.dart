import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/purchaser_model.dart';
import '../providers/purchaser_provider.dart';
import 'package:flutter/services.dart'; 

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
        userId: widget.purchaser.userId, // <-- 1. ADDED USER ID HERE TO PRESERVE OWNERSHIP
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
      appBar: AppBar(title: const Text('Edit Purchaser')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildTextField(
              controller: _nameCtrl, 
              label: 'Purchaser Name', 
              validator: (v) => v!.isEmpty ? 'Required' : null
            ),
            const SizedBox(height: 10),
            _buildTextField(
              controller: _gstinCtrl, 
              label: 'GSTIN', 
              textCapitalization: TextCapitalization.characters
            ),
            const SizedBox(height: 10),
            _buildTextField(controller: _add1Ctrl, label: 'Address 1'),
            const SizedBox(height: 10),
            _buildTextField(controller: _add2Ctrl, label: 'Address 2'),
            const SizedBox(height: 10),
            _buildTextField(
              controller: _partCtrl, 
              label: 'Default Item', 
              textCapitalization: TextCapitalization.characters
            ),
            const SizedBox(height: 10),
            _buildTextField(controller: _hsnCtrl, label: 'HSN No.'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _buildTextField(controller: _sgstCtrl, label: 'SGST %', isNumber: true)),
                const SizedBox(width: 10),
                Expanded(child: _buildTextField(controller: _cgstCtrl, label: 'CGST %', isNumber: true)),
                const SizedBox(width: 10),
                Expanded(child: _buildTextField(controller: _igstCtrl, label: 'IGST %', isNumber: true, isLast: true)),
              ],
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _savePurchaser, 
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: const Text('Save Changes')
            ),
          ],
        ),
      ),
    );
  }
}