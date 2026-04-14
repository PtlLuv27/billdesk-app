import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/purchaser_provider.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/payment_provider.dart';
import '../account_detail_screen.dart';

class AccountTab extends ConsumerWidget {
  const AccountTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchasers = ref.watch(purchaserProvider);
    final invoices = ref.watch(invoiceProvider);
    final payments = ref.watch(paymentProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Account Management'), backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0),
      body: purchasers.isEmpty
          ? const Center(child: Text('No accounts found.'))
          : ListView.builder(
              itemCount: purchasers.length,
              itemBuilder: (context, index) {
                final person = purchasers[index];

                // Math: They Owe Us (Sales)
                final sales = invoices.where((i) => i.purchaserId == person.id && i.type == 'sales').fold(0.0, (s, i) => s + i.totalAmount);
                final received = payments.where((p) => p.purchaserId == person.id && p.type == 'received').fold(0.0, (s, p) => s + p.amount);
                final theyOweUs = sales - received;

                // Math: We Owe Them (Purchases)
                final purchases = invoices.where((i) => i.purchaserId == person.id && i.type == 'purchase').fold(0.0, (s, i) => s + i.totalAmount);
                final paid = payments.where((p) => p.purchaserId == person.id && p.type == 'paid').fold(0.0, (s, p) => s + p.amount);
                final weOweThem = purchases - paid;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: ListTile(
                    title: Text(person.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (theyOweUs > 0) Text('They Owe Us: ₹${theyOweUs.toStringAsFixed(0)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        if (weOweThem > 0) Text('We Owe Them: ₹${weOweThem.toStringAsFixed(0)}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        if (theyOweUs <= 0 && weOweThem <= 0) const Text('Settled / No Balance', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => AccountDetailScreen(purchaser: person)));
                    },
                  ),
                );
              },
            ),
    );
  }
}