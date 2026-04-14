import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../models/purchaser_model.dart';
import '../../providers/purchaser_provider.dart';
import '../edit_purchaser_screen.dart';

class PurchaserTab extends ConsumerStatefulWidget {
  const PurchaserTab({super.key});

  @override
  ConsumerState<PurchaserTab> createState() => _PurchaserTabState();
}

class _PurchaserTabState extends ConsumerState<PurchaserTab> {
  
  // --- ADD PURCHASER DIALOG ---
  void _showAddPurchaserDialog() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final gstinCtrl = TextEditingController();
    final add1Ctrl = TextEditingController();
    final add2Ctrl = TextEditingController();
    final partCtrl = TextEditingController();
    final hsnCtrl = TextEditingController();
    final sgstCtrl = TextEditingController(text: '0.0');
    final cgstCtrl = TextEditingController(text: '0.0');
    final igstCtrl = TextEditingController(text: '0.0');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16, right: 16, top: 16
        ),
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Add New Party / Purchaser', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                
                TextFormField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()), validator: (v) => v!.isEmpty ? 'Required' : null),
                const SizedBox(height: 10),
                TextFormField(controller: gstinCtrl, decoration: const InputDecoration(labelText: 'GSTIN', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextFormField(controller: add1Ctrl, decoration: const InputDecoration(labelText: 'Address Line 1', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextFormField(controller: add2Ctrl, decoration: const InputDecoration(labelText: 'Address Line 2', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: partCtrl, decoration: const InputDecoration(labelText: 'Default Item', border: OutlineInputBorder()))),
                    const SizedBox(width: 10),
                    Expanded(child: TextFormField(controller: hsnCtrl, decoration: const InputDecoration(labelText: 'HSN No.', border: OutlineInputBorder()))),
                  ],
                ),
                const SizedBox(height: 10),
                
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: sgstCtrl, decoration: const InputDecoration(labelText: 'SGST %', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                    const SizedBox(width: 10),
                    Expanded(child: TextFormField(controller: cgstCtrl, decoration: const InputDecoration(labelText: 'CGST %', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                    const SizedBox(width: 10),
                    Expanded(child: TextFormField(controller: igstCtrl, decoration: const InputDecoration(labelText: 'IGST %', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                  ],
                ),
                
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final newPurchaser = Purchaser(
                        id: const Uuid().v4(),
                        name: nameCtrl.text.trim(),
                        address1: add1Ctrl.text.trim(),
                        address2: add2Ctrl.text.trim(),
                        particulars: partCtrl.text.trim(),
                        gstin: gstinCtrl.text.trim(),
                        hsnNo: hsnCtrl.text.trim(),
                        sgstRate: double.tryParse(sgstCtrl.text) ?? 0.0,
                        cgstRate: double.tryParse(cgstCtrl.text) ?? 0.0,
                        igstRate: double.tryParse(igstCtrl.text) ?? 0.0,
                        lastUpdated: DateTime.now().millisecondsSinceEpoch,
                      );

                      await ref.read(purchaserProvider.notifier).addPurchaser(newPurchaser);
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Party Added Successfully!')));
                      }
                    }
                  },
                  child: const Text('Save Party'),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch the global list of purchasers
    final purchasers = ref.watch(purchaserProvider);

    return Scaffold(
      body: purchasers.isEmpty
          ? const Center(child: Text('No parties/purchasers found. Add one!'))
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 80), // Padding for FAB
              itemCount: purchasers.length,
              itemBuilder: (context, index) {
                final purchaser = purchasers[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade100,
                      child: Text(purchaser.name.substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(purchaser.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('GST: ${purchaser.gstin.isEmpty ? "N/A" : purchaser.gstin}\n${purchaser.address1}'),
                    isThreeLine: true,
                    trailing: IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditPurchaserScreen(purchaser: purchaser),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddPurchaserDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Party'),
      ),
    );
  }
}