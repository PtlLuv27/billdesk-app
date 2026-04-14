class Invoice {
  final String id;
  final String companyId;
  final String type; // "sales" or "purchase"
  final String? purchaserId; // Nullable if it's a quick purchase entry
  final String billNo;
  final int billDate; // Unix timestamp for easy filtering
  final String truckNo;
  final String driverName;
  final String licNo;
  final int nos;
  final String unit; // "CBM" or "KG"
  final double quantity;
  final double rate;
  final double amount;
  final double labourCharge;
  final double subTotal;
  final double gstAmount;
  final double totalAmount;
  final int lastUpdated;
  final bool isDeleted;

  Invoice({
    required this.id,
    required this.companyId,
    required this.type,
    this.purchaserId,
    required this.billNo,
    required this.billDate,
    required this.truckNo,
    required this.driverName,
    required this.licNo,
    required this.nos,
    required this.unit,
    required this.quantity,
    required this.rate,
    required this.amount,
    required this.labourCharge,
    required this.subTotal,
    required this.gstAmount,
    required this.totalAmount,
    required this.lastUpdated,
    this.isDeleted = false,
  });

  // Convert an Invoice into a Map to store in SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'company_id': companyId,
      'type': type,
      'purchaser_id': purchaserId,
      'bill_no': billNo,
      'bill_date': billDate,
      'truck_no': truckNo,
      'driver_name': driverName,
      'lic_no': licNo,
      'nos': nos,
      'unit': unit,
      'quantity': quantity,
      'rate': rate,
      'amount': amount,
      'labour_charge': labourCharge,
      'sub_total': subTotal,
      'gst_amount': gstAmount,
      'total_amount': totalAmount,
      'last_updated': lastUpdated,
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  // Extract an Invoice object from a SQLite Map
  factory Invoice.fromMap(Map<String, dynamic> map) {
    return Invoice(
      id: map['id'],
      companyId: map['company_id'],
      type: map['type'],
      purchaserId: map['purchaser_id'],
      billNo: map['bill_no'],
      billDate: map['bill_date'],
      truckNo: map['truck_no'] ?? '',
      driverName: map['driver_name'] ?? '',
      licNo: map['lic_no'] ?? '',
      nos: map['nos'] ?? 0,
      unit: map['unit'] ?? '',
      quantity: map['quantity']?.toDouble() ?? 0.0,
      rate: map['rate']?.toDouble() ?? 0.0,
      amount: map['amount']?.toDouble() ?? 0.0,
      labourCharge: map['labour_charge']?.toDouble() ?? 0.0,
      subTotal: map['sub_total']?.toDouble() ?? 0.0,
      gstAmount: map['gst_amount']?.toDouble() ?? 0.0,
      totalAmount: map['total_amount']?.toDouble() ?? 0.0,
      lastUpdated: map['last_updated'],
      isDeleted: map['is_deleted'] == 1,
    );
  }
}