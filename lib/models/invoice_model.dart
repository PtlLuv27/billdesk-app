class Invoice {
  final String id;
  final String userId;
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
  final int isDeleted; // Changed to int to match SQLite and other models

  Invoice({
    required this.id,
    required this.userId,
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
    this.isDeleted = 0,
  });

  // Convert an Invoice into a Map to store in SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'companyId': companyId,         // Updated to camelCase
      'type': type,
      'purchaserId': purchaserId,     // Updated to camelCase
      'billNo': billNo,               // Updated to camelCase
      'billDate': billDate,           // Updated to camelCase
      'truckNo': truckNo,             // Updated to camelCase
      'driverName': driverName,       // Updated to camelCase
      'licNo': licNo,                 // Updated to camelCase
      'nos': nos,
      'unit': unit,
      'quantity': quantity,
      'rate': rate,
      'amount': amount,
      'labourCharge': labourCharge,   // Updated to camelCase
      'subTotal': subTotal,           // Updated to camelCase
      'gstAmount': gstAmount,         // Updated to camelCase
      'totalAmount': totalAmount,     // Updated to camelCase
      'lastUpdated': lastUpdated,     // Updated to camelCase
      'isDeleted': isDeleted,         // Updated to camelCase
    };
  }

  // Extract an Invoice object from a SQLite Map
  factory Invoice.fromMap(Map<String, dynamic> map) {
    return Invoice(
      id: map['id'],
      companyId: map['companyId'],         // Updated
      userId: map['userId'] ?? '',
      type: map['type'],
      purchaserId: map['purchaserId'],     // Updated
      billNo: map['billNo'],               // Updated
      billDate: map['billDate'],           // Updated
      truckNo: map['truckNo'] ?? '',       // Updated
      driverName: map['driverName'] ?? '', // Updated
      licNo: map['licNo'] ?? '',           // Updated
      nos: map['nos'] ?? 1,
      unit: map['unit'] ?? '',
      quantity: map['quantity']?.toDouble() ?? 0.0,
      rate: map['rate']?.toDouble() ?? 0.0,
      amount: map['amount']?.toDouble() ?? 0.0,
      labourCharge: map['labourCharge']?.toDouble() ?? 0.0, // Updated
      subTotal: map['subTotal']?.toDouble() ?? 0.0,         // Updated
      gstAmount: map['gstAmount']?.toDouble() ?? 0.0,       // Updated
      totalAmount: map['totalAmount']?.toDouble() ?? 0.0,   // Updated
      lastUpdated: map['lastUpdated'],                      // Updated
      isDeleted: map['isDeleted'] ?? 0,                     // Updated
    );
  }
}