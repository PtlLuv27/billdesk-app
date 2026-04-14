class Payment {
  final String id;
  final String companyId;
  final String purchaserId;
  final double amount;
  final int date;
  final String type; // 'received' (Customer paid us) or 'paid' (We paid Vendor)
  final String notes;

  Payment({
    required this.id,
    required this.companyId,
    required this.purchaserId,
    required this.amount,
    required this.date,
    required this.type,
    this.notes = '',
  });

  Map<String, dynamic> toMap() => {
    'id': id, 'companyId': companyId, 'purchaserId': purchaserId,
    'amount': amount, 'date': date, 'type': type, 'notes': notes,
  };

  factory Payment.fromMap(Map<String, dynamic> map) => Payment(
    id: map['id'], companyId: map['companyId'], purchaserId: map['purchaserId'],
    amount: map['amount'], date: map['date'], type: map['type'], notes: map['notes'] ?? '',
  );
}