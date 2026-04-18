class Purchaser {
  final String id;
  final String userId; 
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
  final int isDeleted;

  Purchaser({
    required this.id,
    required this.userId,
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
    this.isDeleted = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'address1': address1,
      'address2': address2,
      'particulars': particulars,
      'gstin': gstin,
      'hsnNo': hsnNo,           
      'sgstRate': sgstRate,     
      'cgstRate': cgstRate,     
      'igstRate': igstRate,     
      'lastUpdated': lastUpdated, 
      'isDeleted': isDeleted,     
    };
  }

  factory Purchaser.fromMap(Map<String, dynamic> map) {
    return Purchaser(
      id: map['id'],
      userId: map['userId'] ?? '',
      name: map['name'],
      address1: map['address1'] ?? '',
      address2: map['address2'] ?? '',
      particulars: map['particulars'] ?? '',
      gstin: map['gstin'] ?? '',
      hsnNo: map['hsnNo'] ?? '',           
      sgstRate: map['sgstRate']?.toDouble() ?? 0.0, 
      cgstRate: map['cgstRate']?.toDouble() ?? 0.0, 
      igstRate: map['igstRate']?.toDouble() ?? 0.0, 
      lastUpdated: map['lastUpdated'],     
      isDeleted: map['isDeleted'] ?? 0,    
    );
  }

  // --- THE FIX: THIS PREVENTS DROPDOWN CRASHES ---
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Purchaser && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}