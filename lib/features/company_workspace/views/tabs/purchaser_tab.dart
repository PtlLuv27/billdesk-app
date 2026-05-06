import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../models/purchaser_model.dart';
import '../../providers/purchaser_provider.dart';
import '../edit_purchaser_screen.dart';
import '../../../authentication/providers/auth_provider.dart';
// --- NEW IMPORT ---
import '../party_details_screen.dart';

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
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20, right: 20, top: 24
        ),
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Add New Party', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF203A43))),
                const SizedBox(height: 20),
                
                TextFormField(controller: nameCtrl, decoration: InputDecoration(labelText: 'Party Name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), validator: (v) => v!.isEmpty ? 'Required' : null),
                const SizedBox(height: 12),
                TextFormField(controller: gstinCtrl, decoration: InputDecoration(labelText: 'GSTIN (Optional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                const SizedBox(height: 12),
                TextFormField(controller: add1Ctrl, decoration: InputDecoration(labelText: 'Address Line 1', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                const SizedBox(height: 12),
                TextFormField(controller: add2Ctrl, decoration: InputDecoration(labelText: 'Address Line 2', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                const SizedBox(height: 12),
                
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: partCtrl, decoration: InputDecoration(labelText: 'Default Item', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(controller: hsnCtrl, decoration: InputDecoration(labelText: 'HSN No.', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
                  ],
                ),
                const SizedBox(height: 12),
                
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: sgstCtrl, decoration: InputDecoration(labelText: 'SGST %', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), keyboardType: TextInputType.number)),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(controller: cgstCtrl, decoration: InputDecoration(labelText: 'CGST %', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), keyboardType: TextInputType.number)),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(controller: igstCtrl, decoration: InputDecoration(labelText: 'IGST %', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), keyboardType: TextInputType.number)),
                  ],
                ),
                
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final currentUserId = ref.read(authProvider);
                      if (currentUserId == null) return;

                      final newPurchaser = Purchaser(
                        id: const Uuid().v4(),
                        userId: currentUserId,
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
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Party Added Successfully!'), backgroundColor: Colors.green));
                      }
                    }
                  },
                  child: const Text('Save Party', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- GRADIENT GENERATOR ---
  List<Color> _getGradient(int index) {
    final gradients = [
      [Colors.blue.shade700, Colors.blue.shade400],
      [Colors.purple.shade700, Colors.purple.shade400],
      [Colors.teal.shade700, Colors.teal.shade400],
      [Colors.orange.shade700, Colors.orange.shade400],
      [Colors.pink.shade700, Colors.pink.shade400],
    ];
    return gradients[index % gradients.length];
  }

  @override
  Widget build(BuildContext context) {
    final purchasers = ref.watch(purchaserProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      body: purchasers.isEmpty
          ? const Center(child: Text('No parties/purchasers found. Add one!', style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold)))
          : ListView.builder(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
              itemCount: purchasers.length,
              itemBuilder: (context, index) {
                final purchaser = purchasers[index];
                final gradient = _getGradient(index);

                return HoverablePartyCard(
                  purchaser: purchaser,
                  gradient: gradient,
                  onTap: () {
                    // --- NEW: NAVIGATE TO DETAILS SCREEN ---
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PartyDetailsScreen(party: purchaser, gradient: gradient),
                      ),
                    );
                  },
                  onEdit: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => EditPurchaserScreen(purchaser: purchaser)));
                  },
                  onDelete: () {
                    showDialog(
                      context: context,
                      builder: (dialogCtx) => AlertDialog(
                        title: const Text('Delete Party?'),
                        content: const Text('Are you sure you want to remove this party?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                            onPressed: () {
                              ref.read(purchaserProvider.notifier).deletePurchaser(purchaser);
                              Navigator.pop(dialogCtx);
                            },
                            child: const Text('Delete'),
                          )
                        ],
                      )
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddPurchaserDialog,
        backgroundColor: const Color(0xFF203A43),
        foregroundColor: Colors.white,
        elevation: 6,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add Party', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// --- NEW: HOVERABLE PARTY CARD ---
class HoverablePartyCard extends StatefulWidget {
  final Purchaser purchaser;
  final List<Color> gradient;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const HoverablePartyCard({super.key, required this.purchaser, required this.gradient, required this.onTap, required this.onEdit, required this.onDelete});

  @override
  State<HoverablePartyCard> createState() => _HoverablePartyCardState();
}

class _HoverablePartyCardState extends State<HoverablePartyCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isHovered = true),
        onTapUp: (_) {
          setState(() => _isHovered = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isHovered = false),
        onLongPress: () {
          showModalBottomSheet(
            context: context,
            builder: (ctx) => SafeArea(
              child: Wrap(
                children: [
                  ListTile(
                    leading: const Icon(Icons.edit, color: Colors.blue),
                    title: const Text('Edit Party'),
                    onTap: () {
                      Navigator.pop(ctx);
                      widget.onEdit();
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.delete, color: Colors.red),
                    title: const Text('Delete Party', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    onTap: () {
                      Navigator.pop(ctx);
                      widget.onDelete();
                    },
                  ),
                ],
              ),
            ),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.only(bottom: 12),
          transform: Matrix4.identity()..scale(_isHovered ? 1.02 : 1.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: widget.gradient.first.withOpacity(_isHovered ? 0.3 : 0.05),
                blurRadius: _isHovered ? 12 : 6,
                offset: Offset(0, _isHovered ? 6 : 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: widget.gradient, begin: Alignment.topCenter, end: Alignment.bottomCenter),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        height: 48, width: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: widget.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                          shape: BoxShape.circle,
                        ),
                        child: Center(child: Text(widget.purchaser.name.substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.purchaser.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Text(widget.purchaser.gstin.isEmpty ? 'GST: N/A' : 'GST: ${widget.purchaser.gstin}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey.shade300),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}