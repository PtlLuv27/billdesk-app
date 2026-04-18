import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../models/company_model.dart';
import '../../models/purchaser_model.dart';
import '../../models/invoice_model.dart';
import '../../models/payment_model.dart'; // Ensure Payment model is imported

class DatabaseHelper {
  // Singleton pattern
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('billdesk.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Users Table
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        name TEXT,
        email TEXT UNIQUE,
        passwordHash TEXT,
        createdAt INTEGER
      )
    ''');

    // 2. Company Table
    await db.execute('''
      CREATE TABLE companies(
        id TEXT PRIMARY KEY,
        userId TEXT,
        name TEXT,
        address1 TEXT,
        address2 TEXT,
        mobileNumber TEXT,
        gstin TEXT,
        bankName TEXT,
        accountNumber TEXT,
        ifscCode TEXT,
        pin TEXT,
        lastUpdated INTEGER,
        isDeleted INTEGER
      )
    ''');

    // 3. Purchaser Table
    await db.execute('''
      CREATE TABLE purchasers (
        id TEXT PRIMARY KEY,
        userId TEXT,
        name TEXT NOT NULL,
        address1 TEXT,
        address2 TEXT,
        particulars TEXT,
        gstin TEXT,
        hsnNo TEXT,
        sgstRate REAL,
        cgstRate REAL,
        igstRate REAL,
        lastUpdated INTEGER NOT NULL,
        isDeleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // 4. Invoice Table
    await db.execute('''
      CREATE TABLE invoices (
        id TEXT PRIMARY KEY,
        userId TEXT,
        companyId TEXT NOT NULL,
        type TEXT NOT NULL,
        purchaserId TEXT,
        billNo TEXT NOT NULL,
        billDate INTEGER NOT NULL,
        truckNo TEXT,
        driverName TEXT,
        licNo TEXT,
        nos INTEGER,
        unit TEXT,
        quantity REAL,
        rate REAL,
        amount REAL,
        labourCharge REAL,
        subTotal REAL,
        gstAmount REAL,
        totalAmount REAL,
        lastUpdated INTEGER NOT NULL,
        isDeleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // 5. Payments Table
    await db.execute('''
      CREATE TABLE payments(
        id TEXT PRIMARY KEY,
        userId TEXT,
        companyId TEXT,
        purchaserId TEXT,
        amount REAL,
        date INTEGER,
        type TEXT,
        notes TEXT
      )
    ''');
  }

  // --- CRUD OPERATIONS (COMPANY) ---

  Future<void> insertCompany(Company company) async {
    final db = await instance.database;
    await db.insert(
      'companies',
      company.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace, 
    );
  }

  Future<List<Company>> getCompaniesByUser(String userId) async {
    final db = await instance.database;
    final maps = await db.query(
      'companies',
      where: 'userId = ? AND isDeleted = ?',
      whereArgs: [userId, 0],
    );
    return maps.map((map) => Company.fromMap(map)).toList();
  }

  Future<void> updateCompany(Company company) async {
    final db = await instance.database;
    await db.update(
      'companies',
      company.toMap(),
      where: 'id = ?',
      whereArgs: [company.id],
    );
  }

  // --- CRUD OPERATIONS (PURCHASER) ---

  Future<void> insertPurchaser(Purchaser purchaser) async {
    final db = await instance.database;
    await db.insert(
      'purchasers',
      purchaser.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updatePurchaser(Purchaser purchaser) async {
    final db = await instance.database;
    await db.update(
      'purchasers',
      purchaser.toMap(),
      where: 'id = ?',
      whereArgs: [purchaser.id],
    );
  }

  Future<List<Purchaser>> getPurchasersByUser(String userId) async {
    final db = await instance.database;
    final maps = await db.query(
      'purchasers',
      where: 'userId = ? AND isDeleted = ?',
      whereArgs: [userId, 0], 
    );
    return maps.map((map) => Purchaser.fromMap(map)).toList();
  }

  // --- CRUD OPERATIONS (INVOICE) ---

  Future<void> insertInvoice(Invoice invoice) async {
    final db = await instance.database;
    await db.insert(
      'invoices',
      invoice.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Invoice>> getInvoicesByCompany(String companyId) async {
    final db = await instance.database;
    final maps = await db.query(
      'invoices',
      where: 'companyId = ? AND isDeleted = ?',
      whereArgs: [companyId, 0],
      orderBy: 'billDate DESC', 
    );
    return maps.map((map) => Invoice.fromMap(map)).toList();
  }

  Future<void> updateInvoice(Invoice invoice) async {
    final db = await instance.database;
    await db.update(
      'invoices',
      invoice.toMap(),
      where: 'id = ?',
      whereArgs: [invoice.id],
    );
  }

  Future<void> deleteInvoice(String id) async {
    final db = await instance.database;
    await db.delete('invoices', where: 'id = ?', whereArgs: [id]);
  }
  
  // --- CRUD OPERATIONS (PAYMENTS) ---

  Future<void> insertPayment(Payment payment) async {
    final db = await instance.database;
    await db.insert('payments', payment.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Payment>> getPaymentsByCompany(String companyId) async {
    final db = await instance.database;
    final maps = await db.query('payments', where: 'companyId = ?', whereArgs: [companyId]);
    return maps.map((map) => Payment.fromMap(map)).toList();
  }

  Future<int> deletePayment(String id) async {
    final db = await instance.database;
    return await db.delete('payments', where: 'id = ?', whereArgs: [id]);
  }

  // Close database
  Future close() async {
    final db = await instance.database;
    db.close();
  }
}