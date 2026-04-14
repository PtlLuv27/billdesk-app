class Company {
  final String id;
  final String name;
  final String address1;
  final String address2;
  final String mobileNumber;
  final String bankName;
  final String accountNumber;
  final String ifscCode;
  final String pin; // <-- 1. ADD THIS
  final int lastUpdated;
  final int isDeleted;

  Company({
    required this.id,
    required this.name,
    required this.address1,
    required this.address2,
    required this.mobileNumber,
    required this.bankName,
    required this.accountNumber,
    required this.ifscCode,
    required this.pin, // <-- 2. ADD THIS
    required this.lastUpdated,
    this.isDeleted = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id, 'name': name, 'address1': address1, 'address2': address2,
      'mobileNumber': mobileNumber, 'bankName': bankName, 'accountNumber': accountNumber,
      'ifscCode': ifscCode, 
      'pin': pin, // <-- 3. ADD THIS
      'lastUpdated': lastUpdated, 'isDeleted': isDeleted,
    };
  }

  factory Company.fromMap(Map<String, dynamic> map) {
    return Company(
      id: map['id'], name: map['name'], address1: map['address1'], address2: map['address2'],
      mobileNumber: map['mobileNumber'], bankName: map['bankName'], accountNumber: map['accountNumber'],
      ifscCode: map['ifscCode'], 
      pin: map['pin'] ?? '0000', // <-- 4. ADD THIS (Default fallback for old DBs)
      lastUpdated: map['lastUpdated'], isDeleted: map['isDeleted'],
    );
  }
}