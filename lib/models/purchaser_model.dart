class Purchaser {
  final String id;
  // REMOVED: final String companyId; 
  final String name;
  final String address1;
  final String address2;
  final String particulars;
  final String gstin;
  final String hsnNo;
  final double sgstRate;
  final double cgstRate;
  final double igstRate;
  final int lastUpdated;
  final bool isDeleted;

  Purchaser({
    required this.id,
    required this.name,
    required this.address1,
    required this.address2,
    required this.particulars,
    required this.gstin,
    required this.hsnNo,
    required this.sgstRate,
    required this.cgstRate,
    required this.igstRate,
    required this.lastUpdated,
    this.isDeleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address1': address1,
      'address2': address2,
      'particulars': particulars,
      'gstin': gstin,
      'hsn_no': hsnNo,
      'sgst_rate': sgstRate,
      'cgst_rate': cgstRate,
      'igst_rate': igstRate,
      'last_updated': lastUpdated,
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  factory Purchaser.fromMap(Map<String, dynamic> map) {
    return Purchaser(
      id: map['id'],
      name: map['name'],
      address1: map['address1'],
      address2: map['address2'],
      particulars: map['particulars'],
      gstin: map['gstin'],
      hsnNo: map['hsn_no'],
      sgstRate: map['sgst_rate'],
      cgstRate: map['cgst_rate'],
      igstRate: map['igst_rate'],
      lastUpdated: map['last_updated'],
      isDeleted: map['is_deleted'] == 1,
    );
  }
}