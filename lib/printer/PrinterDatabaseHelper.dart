import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class PrinterDatabaseHelper {
  static final PrinterDatabaseHelper _instance = PrinterDatabaseHelper._internal();
  static Database? _database;

  factory PrinterDatabaseHelper() => _instance;

  PrinterDatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'printer_database.db');
    return await openDatabase(
      path,
      version: 2, // Incremented version
      onCreate: _createDb,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Add migration logic here
        }
      },
    );
  }

  Future<void> _createDb(Database db, int version) async {
    await db.execute('''
      CREATE TABLE printer_types(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        address TEXT,
        deviceType TEXT NOT NULL,
        isDefault INTEGER NOT NULL DEFAULT 0,
        isActive INTEGER NOT NULL DEFAULT 1,
        lastConnected TEXT,
        connectionParams TEXT
      )
    ''');
  }

  // Printer-related methods
  Future<List<Map<String, dynamic>>> getAllPrinterTypes() async {
    final db = await database;
    return await db.query('printer_types', orderBy: 'name');
  }

  Future<List<Map<String, dynamic>>> getActivePrinterTypes() async {
    final db = await database;
    return await db.query(
        'printer_types',
        where: 'isActive = 1',
        orderBy: 'name'
    );
  }

  Future<Map<String, dynamic>?> getDefaultPrinterType() async {
    final db = await database;

    // First try to get the default printer
    final defaultResults = await db.query(
      'printer_types',
      where: 'isDefault = 1',
    );

    // If a default exists, return it
    if (defaultResults.isNotEmpty) {
      return defaultResults.first;
    }

    // Otherwise, get any active printer
    final activeResults = await db.query(
        'printer_types',
        where: 'isActive = 1',
        limit: 1
    );

    return activeResults.isNotEmpty ? activeResults.first : null;
  }

  Future<Map<String, dynamic>?> getPrinterTypeById(int id) async {
    final db = await database;
    final results = await db.query(
      'printer_types',
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> insertPrinterType(Map<String, dynamic> printerType) async {
    final db = await database;

    // If this printer is set as default, clear other defaults first
    if (printerType['isDefault'] == 1) {
      await db.update('printer_types', {'isDefault': 0});
    }

    return await db.insert('printer_types', printerType);
  }

  Future<int> updatePrinterType(int id, Map<String, dynamic> printerType) async {
    final db = await database;

    // If this printer is set as default, clear other defaults first
    if (printerType['isDefault'] == 1) {
      await db.update('printer_types', {'isDefault': 0});
    }

    return await db.update(
      'printer_types',
      printerType,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> setDefaultPrinter(int id) async {
    final db = await database;

    // Clear all defaults first
    await db.update('printer_types', {'isDefault': 0});

    // Set the new default
    return await db.update(
      'printer_types',
      {'isDefault': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deletePrinterType(int id) async {
    final db = await database;

    // Check if this is the default printer
    final printer = await getPrinterTypeById(id);
    if (printer != null && printer['isDefault'] == 1) {
      // Don't allow deleting the default printer
      return 0;
    }

    return await db.delete(
      'printer_types',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Deactivate printer instead of deleting
  Future<int> deactivatePrinterType(int id) async {
    final db = await database;

    // Check if this is the default printer
    final printer = await getPrinterTypeById(id);
    if (printer != null && printer['isDefault'] == 1) {
      // Don't allow deactivating the default printer
      return 0;
    }

    return await db.update(
      'printer_types',
      {'isActive': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}