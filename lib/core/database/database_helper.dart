import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../models/company_model.dart';
import '../../models/purchaser_model.dart';
import '../../models/invoice_model.dart';

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

  Future _createDB(Database db, int version) async {
    // 1. Company Table
    await db.execute('''
      CREATE TABLE companies(
        id TEXT PRIMARY KEY,
        name TEXT,
        address1 TEXT,
        address2 TEXT,
        mobileNumber TEXT,
        bankName TEXT,
        accountNumber TEXT,
        ifscCode TEXT,
        pin TEXT,  -- <-- ADD THIS LINE
        lastUpdated INTEGER,
        isDeleted INTEGER
      )
    ''');
    // 2. Purchaser Table (UPDATED FOR GLOBAL ACCESS)
    await db.execute('''
      CREATE TABLE purchasers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        address1 TEXT,
        address2 TEXT,
        particulars TEXT,
        gstin TEXT,
        hsn_no TEXT,
        sgst_rate REAL,
        cgst_rate REAL,
        igst_rate REAL,
        last_updated INTEGER NOT NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // 3. Invoice Table
    await db.execute('''
      CREATE TABLE invoices (
        id TEXT PRIMARY KEY,
        company_id TEXT NOT NULL,
        type TEXT NOT NULL,
        purchaser_id TEXT,
        bill_no TEXT NOT NULL,
        bill_date INTEGER NOT NULL,
        truck_no TEXT,
        driver_name TEXT,
        lic_no TEXT,
        nos INTEGER,
        unit TEXT,
        quantity REAL,
        rate REAL,
        amount REAL,
        labour_charge REAL,
        sub_total REAL,
        gst_amount REAL,
        total_amount REAL,
        last_updated INTEGER NOT NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (company_id) REFERENCES companies (id) ON DELETE CASCADE,
        FOREIGN KEY (purchaser_id) REFERENCES purchasers (id) ON DELETE SET NULL
      )
    ''');

    // 4. Payments Table (For future ledger module)
    await db.execute('''
      CREATE TABLE payments(
        id TEXT PRIMARY KEY,
        companyId TEXT,
        purchaserId TEXT,
        amount REAL,
        date INTEGER,
        type TEXT,
        notes TEXT
      )
    ''');
  }

  // --- CRUD OPERATIONS EXAMPLE (COMPANY) ---

  Future<void> insertCompany(Company company) async {
    final db = await instance.database;
    await db.insert(
      'companies',
      company.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace, // Critical for later cloud sync overwriting
    );
  }

  Future<List<Company>> getAllActiveCompanies() async {
    final db = await instance.database;
    // Only fetch companies that are NOT soft-deleted
    final maps = await db.query(
      'companies',
      where: 'isDeleted = ?',
      whereArgs: [0],
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

  // Fetch ALL purchasers for the master user, regardless of company
  Future<List<Purchaser>> getAllActivePurchasers() async {
    final db = await instance.database;
    final maps = await db.query(
      'purchasers',
      where: 'is_deleted = ?',
      whereArgs: [0], // 0 means false (not deleted)
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

  // Fetch invoices for the active company
  Future<List<Invoice>> getInvoicesByCompany(String companyId) async {
    final db = await instance.database;
    final maps = await db.query(
      'invoices',
      where: 'company_id = ? AND is_deleted = ?',
      whereArgs: [companyId, 0],
      orderBy: 'bill_date DESC', // Newest first
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

  Future<int> insertPayment(Map<String, dynamic> payment) async {
    final db = await instance.database;
    return await db.insert('payments', payment);
  }

  Future<List<Map<String, dynamic>>> getPayments(String companyId) async {
    final db = await instance.database;
    return await db.query('payments', where: 'companyId = ?', whereArgs: [companyId]);
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