import 'package:flutter/cupertino.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';

import 'data/services/PackageData.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!; // Return existing instance if already initialized

    _database = await _initDB("parking.db"); // Use only one database file
    print(await _database!.getVersion()); // Should print 2

    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2, // Increased to support migrations if needed
      onConfigure: (Database db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        try {
          print('Creating tables...');

          await db.execute('''
          CREATE TABLE parking_entries(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            billNumber TEXT UNIQUE, 
            vehicleType TEXT, 
            vehicleNo TEXT, 
            entryTime TEXT,
            exitTime TEXT,
            entryGateId INTEGER,
            entryGateName TEXT,
            exitGateId INTEGER DEFAULT 0,
            exitGateName TEXT,
            hoursSpent INTEGER,
            price TEXT,
            totalPrice REAL,
            isPaid INTEGER DEFAULT 0,
            notes TEXT,
            lastModified TEXT,
            FOREIGN KEY(entryGateId) REFERENCES gates(id),
            FOREIGN KEY(exitGateId) REFERENCES gates(id)
          )
        ''');

          await db.execute('''
          CREATE TABLE spaces (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            totalSpaces INTEGER NOT NULL DEFAULT 100,
            occupiedSpaces INTEGER NOT NULL DEFAULT 0
          )
        ''');

          await db.execute('''
          CREATE TABLE gates (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            location TEXT,
            isActive INTEGER DEFAULT 1,
            type TEXT CHECK(type IN ('entry', 'exit', 'both')),
            notes TEXT
          )
        ''');

          await db.insert('gates', {
            'name': 'Main Gate',
            'location': 'Front entrance',
            'isActive': 1,
            'type': 'both',
            'notes': 'Main entrance and exit gate'
          });
          await db.insert('gates', {
            'name': 'North Gate',
            'location': 'North side',
            'isActive': 1,
            'type': 'entry',
            'notes': 'Entry only'
          });
          await db.insert('gates', {
            'name': 'South Gate',
            'location': 'South side',
            'isActive': 1,
            'type': 'exit',
            'notes': 'Exit only'
          });

          await db.insert('spaces', {'totalSpaces': 100, 'occupiedSpaces': 0});

          await db.execute('''
          CREATE TABLE vehicle_types(
            id INTEGER PRIMARY KEY AUTOINCREMENT, 
            type TEXT UNIQUE, 
            price TEXT
          )
        ''');

          await db.insert('vehicle_types', {'type': 'Car', 'price': '50'});
          await db.insert('vehicle_types', {'type': 'Bike', 'price': '20'});
          await db.insert('vehicle_types', {'type': 'Truck', 'price': '100'});
          await db.insert('vehicle_types', {'type': 'Bus', 'price': '80'});
          await db.insert('vehicle_types', {'type': 'Other', 'price': '30'});

          await db.execute('''
          CREATE TABLE user(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            companyName TEXT,
            address TEXT,
            logoPath TEXT,
            footerText TEXT
          )
        ''');

          await db.execute('''
          CREATE TABLE user_data (
            id INTEGER PRIMARY KEY,
            userId TEXT UNIQUE,
            name TEXT,
            email TEXT,
            title TEXT,
            price REAL,
            duration TEXT,
            durationInDays INTEGER,
            maxEntriesPerDay INTEGER,
            isActive INTEGER,
            packageValidTill TEXT
          )
        ''');

          print("✅ Database created successfully.");
        } catch (e) {
          print("❌ Error creating database: $e");
        }
      },

      /// Optional upgrade logic to support future DB changes
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        if (oldVersion < 2) {
          // Add migrations here
          await db.execute('ALTER TABLE user ADD COLUMN footerText TEXT');
          print('✅ Database upgraded to v2');
        }
      },
    );
  }

  Future<List<String>> getAllTables() async {
    final db = await database;
    final result = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';"
    );

    return result.map((row) => row['name'] as String).toList();
  }

  // Save or update package data in the database
  Future<void> saveUserData(List<PackageData> packageList) async {
    final db = await database;

    final result = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='user_data';"
    );

    if (result.isEmpty) {
      print("user_data table not found.");
      return;
    }

    await db.delete('user_data');

    for (var pkg in packageList) {
      await db.insert(
        'user_data',
        pkg.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }


  // Retrieve package data from the database
  Future<List<PackageData>> retrieveUserData() async {
    final db = await database;

    // Query all rows from the user_data table
    final List<Map<String, dynamic>> maps = await db.query('user_data');

    // Convert the query results into a List<PackageData>
    return List.generate(maps.length, (i) {
      return PackageData.fromMap(maps[i]);
    });
  }

  // Gate-related methods
  Future<List<Map<String, dynamic>>> getAllGates() async {
    final db = await database;
    return await db.query('gates', orderBy: 'name');
  }

  Future<List<Map<String, dynamic>>> getGatesByType(String type) async {
    final db = await database;
    return await db.query(
        'gates',
        where: 'type = ? OR type = "both"',
        whereArgs: [type],
        orderBy: 'name'
    );
  }

  Future<int> insertGate(Map<String, dynamic> gate) async {
    final db = await database;
    return await db.insert('gates', gate);
  }

  Future<int> updateGate(int id, Map<String, dynamic> gate) async {
    final db = await database;
    return await db.update(
      'gates',
      gate,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteGate(int id) async {
    final db = await database;

    // Check if this is the last gate
    final gateCount = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM gates'
    )) ?? 0;

    if (gateCount <= 1) {
      // Don't allow deleting the last gate
      return 0; // Return 0 to indicate no deletion happened
    }

    // Delete the gate regardless of references
    return await db.delete(
      'gates',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Add this method to DatabaseHelper class
  Future<int> toggleGateActiveStatus(int id, bool isActive) async {
    final db = await database;
    return await db.update(
      'gates',
      {'isActive': isActive ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, dynamic>?> getGateById(int id) async {
    final db = await database;
    final results = await db.query(
      'gates',
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> insertEntry(Map<String, dynamic> entry) async {
    final db = await database;

    // Log the entry data before inserting
    print('Inserting entry into parking_entries: $entry');

    return await db.insert('parking_entries', entry);
  }


  // Update exit information with gate info
  Future<int> updateExitInfo(String billNumber, {DateTime? exitTime, int? exitGateId}) async {
    final db = await database;
    final now = exitTime ?? DateTime.now();

    // Get the entry first
    final entry = await getEntryByBill(billNumber);
    if (entry == null) return 0;

    // Calculate hours spent and total price
    final entryTime = DateTime.parse(entry['entryTime'] as String);
    final hoursSpent = now.difference(entryTime).inHours > 0
        ? now.difference(entryTime).inHours
        : 1;
    final price = double.parse(entry['price'] as String);
    final totalPrice = price * hoursSpent;

    // Get gate name if exitGateId is provided
    String? exitGateName;
    if (exitGateId != null) {
      final gate = await getGateById(exitGateId); // You must have this method
      exitGateName = gate?['name'];
    }

    // Prepare update data
    final updateData = {
      'exitTime': now.toString(),
      'exitGateId': exitGateId,
      'exitGateName': exitGateName,
      'hoursSpent': hoursSpent,
      'totalPrice': totalPrice,
      'isPaid': 1,
      'lastModified': now.toIso8601String(),
    };

    // Remove nulls in case some optional fields are not set
    updateData.removeWhere((key, value) => value == null);

    // Perform update
    return await db.update(
      'parking_entries',
      updateData,
      where: 'billNumber = ?',
      whereArgs: [billNumber],
    );
  }

  // Get gate usage statistics
  Future<List<Map<String, dynamic>>> getGateUsageStats(DateTime startDate, DateTime endDate) async {
    final db = await database;
    final startDateStr = DateFormat('yyyy-MM-dd').format(startDate);
    final endDateStr = DateFormat('yyyy-MM-dd').format(endDate.add(const Duration(days: 1)));

    return await db.rawQuery('''
      SELECT 
        g.name as gateName,
        g.type as gateType,
        COUNT(CASE WHEN pe.entryGateId = g.id THEN 1 ELSE NULL END) as entryCount,
        COUNT(CASE WHEN pe.exitGateId = g.id THEN 1 ELSE NULL END) as exitCount,
        COUNT(CASE WHEN pe.entryGateId = g.id OR pe.exitGateId = g.id THEN 1 ELSE NULL END) as totalCount
      FROM gates g
      LEFT JOIN parking_entries pe ON g.id = pe.entryGateId OR g.id = pe.exitGateId
      WHERE (pe.entryTime IS NULL OR pe.entryTime BETWEEN '$startDateStr' AND '$endDateStr')
      GROUP BY g.id
      ORDER BY totalCount DESC
    ''');
  }

  // Get space utilization by entry gate
  Future<List<Map<String, dynamic>>> getSpaceUtilizationByGate() async {
    final db = await database;

    return await db.rawQuery('''
      SELECT 
        g.name as gateName,
        COUNT(*) as totalEntries,
        AVG(CASE WHEN pe.exitTime IS NOT NULL 
            THEN (julianday(pe.exitTime) - julianday(pe.entryTime)) * 24 
            ELSE (julianday('now') - julianday(pe.entryTime)) * 24 
            END) as avgHoursParked
      FROM parking_entries pe
      JOIN gates g ON pe.entryGateId = g.id
      GROUP BY pe.entryGateId
      ORDER BY totalEntries DESC
    ''');
  }

  // Insert or Update (Ensures only one record exists)
  Future<void> saveUser(String name, String companyName, String address,
      {String? logoPath, String? footerText}) async {
    try {
      Database db = await instance.database;

      var user = await getUser();

      if (user == null) {
        await db.insert('user', {
          'name': name,
          'companyName': companyName,
          'address': address,
          'logoPath': logoPath,
          'footerText': footerText,
        });
        debugPrint('✅ New user created in database');
      } else {
        await db.update(
          'user',
          {
            'name': name,
            'companyName': companyName,
            'address': address,
            'footerText': footerText,
            if (logoPath != null) 'logoPath': logoPath,
          },
          where: 'id = ?',
          whereArgs: [user['id']],
        );
        debugPrint('✅ User updated in database');
      }
    } catch (e, stack) {
      debugPrint('❌ Database save error: $e');
      debugPrint(stack.toString());
      throw e;
    }
  }


  // Fetch the only user record
  Future<Map<String, dynamic>?> getUser() async {
    try {
      Database db = await instance.database;
      List<Map<String, dynamic>> users = await db.query('user', limit: 1);
      debugPrint('🔍 Retrieved user data: ${users.isNotEmpty ? 'found' : 'not found'}');
      if (users.isNotEmpty) {
        debugPrint('🔍 User data fields: ${users.first.keys.join(', ')}');
      }
      return users.isNotEmpty ? users.first : null;
    } catch (e) {
      debugPrint('❌ Error retrieving user: $e');
      return null;
    }
  }

  // Delete User (Reset to empty)
  Future<int> deleteUser() async {
    try {
      final db = await database;

      // Get current user first
      var user = await getUser();

      if (user == null) {
        // No user to delete
        debugPrint('⚠️ No user found to delete');
        return 0;
      }

      // Delete using the actual user ID
      int id = user['id'];
      debugPrint('🗑️ Deleting user with ID: $id');

      int result = await db.delete('user', where: 'id = ?', whereArgs: [id]);
      debugPrint('✅ Delete result: $result rows affected');

      return result;
    } catch (e, stack) {
      debugPrint('❌ Error deleting user: $e');
      debugPrint(stack.toString());
      throw e; // Re-throw for UI error handling
    }
  }

  // Get database version
  Future<int> getVersion() async {
    final db = await database;
    return db.getVersion();
  }

  // Get available parking spaces
  Future<Map<String, int>> getParkingSpaceInfo() async {
    final db = await database;
    final result = await db.query('spaces', limit: 1);

    if (result.isEmpty) {
      // Insert default record if not present
      await db.insert('spaces', {
        'id': 1,  // Ensure ID is fixed and only one record exists
        'totalSpaces': 100,
        'occupiedSpaces': 0,
      });

      return {
        'totalSpaces': 100,
        'occupiedSpaces': 0,
        'availableSpaces': 100,
      };
    } else {
      final data = result.first;
      return {
        'totalSpaces': data['totalSpaces'] as int,
        'occupiedSpaces': data['occupiedSpaces'] as int,
        'availableSpaces': (data['totalSpaces'] as int) - (data['occupiedSpaces'] as int),
      };
    }
  }


  // Increment occupied spaces
  Future<void> incrementOccupiedSpaces() async {
    final db = await database;
    await db.execute('''
      UPDATE spaces 
      SET occupiedSpaces = occupiedSpaces + 1 
      WHERE occupiedSpaces < totalSpaces
    ''');
  }

  // Decrement occupied spaces after payment
  Future<void> decrementOccupiedSpaces() async {
    final db = await database;
    await db.execute('''
      UPDATE spaces 
      SET occupiedSpaces = occupiedSpaces - 1 
      WHERE occupiedSpaces > 0
    ''');
  }

  Future<void> updateTotalSpaces(int totalSpaces) async {
    final db = await database;
    await db.execute('''
    UPDATE spaces 
    SET totalSpaces = ?
    WHERE id = 1  -- Ensure you are updating the correct row
  ''', [totalSpaces]);
  }

  // Reset parking spaces (for maintenance or new setup)
  Future<void> resetParkingSpaces(int totalSpaces) async {
    final db = await database;
    await db.update(
      'spaces',
      {'totalSpaces': totalSpaces, 'occupiedSpaces': 0},
    );
  }

  Future<List<Map<String, dynamic>>> getAllEntries() async {
    final db = await database;
    return await db.query('parking_entries', orderBy: 'entryTime DESC');
  }

  Future<List<Map<String, dynamic>>> getActiveEntries() async {
    final db = await database;
    return await db.query(
      'parking_entries',
      where: 'exitTime IS NULL',
      orderBy: 'entryTime DESC',
    );
  }

  Future<Map<String, dynamic>?> getEntryByBill(String billNumber) async {
    final db = await database;
    final results = await db.query(
      'parking_entries',
      where: 'billNumber = ?',
      whereArgs: [billNumber],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<Map<String, dynamic>?> getEntryByVehicle(String vehicleNo) async {
    final db = await database;
    final results = await db.query(
      'parking_entries',
      where: 'vehicleNo = ? AND exitTime IS NULL',
      whereArgs: [vehicleNo],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> updateEntryNotes(String billNumber, String notes) async {
    final db = await database;
    return await db.update(
      'parking_entries',
      {'notes': notes},
      where: 'billNumber = ?',
      whereArgs: [billNumber],
    );
  }

  Future<int> deleteEntry(String billNumber) async {
    final db = await database;
    return await db.delete(
      'parking_entries',
      where: 'billNumber = ?',
      whereArgs: [billNumber],
    );
  }

  // Methods for vehicle types
  Future<List<Map<String, dynamic>>> getVehicleTypes() async {
    final db = await database;
    return await db.query('vehicle_types', orderBy: 'type');
  }

  Future<int> insertVehicleType(Map<String, dynamic> vehicleType) async {
    final db = await database;
    return await db.insert('vehicle_types', vehicleType);
  }

  Future<int> updateVehicleType(int id, Map<String, dynamic> vehicleType) async {
    final db = await database;
    return await db.update(
      'vehicle_types',
      vehicleType,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteVehicleType(int id) async {
    final db = await database;
    return await db.delete(
      'vehicle_types',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<String?> getPriceForVehicleType(String vehicleType) async {
    final db = await database;
    final results = await db.query(
      'vehicle_types',
      columns: ['price'],
      where: 'type = ?',
      whereArgs: [vehicleType],
    );
    return results.isNotEmpty ? results.first['price'] as String : null;
  }

  // Reporting and Statistics
  Future<Map<String, dynamic>> getDailyStats(DateTime date) async {
    final db = await database;
    final dateStr = DateFormat('yyyy-MM-dd').format(date);

    // Get entries for this day
    final results = await db.rawQuery('''
      SELECT 
        COUNT(*) as totalEntries,
        SUM(CASE WHEN exitTime IS NOT NULL THEN 1 ELSE 0 END) as completedEntries,
        SUM(CASE WHEN isPaid = 1 THEN totalPrice ELSE 0 END) as totalRevenue
      FROM parking_entries
      WHERE entryTime LIKE '$dateStr%'
    ''');

    // Vehicle type breakdown
    final typeResults = await db.rawQuery('''
      SELECT vehicleType, COUNT(*) as count
      FROM parking_entries
      WHERE entryTime LIKE '$dateStr%'
      GROUP BY vehicleType
    ''');

    // Gate usage
    final gateResults = await db.rawQuery('''
      SELECT 
        g.name as gateName,
        COUNT(CASE WHEN pe.entryGateId = g.id THEN 1 ELSE NULL END) as entryCount,
        COUNT(CASE WHEN pe.exitGateId = g.id THEN 1 ELSE NULL END) as exitCount
      FROM gates g
      LEFT JOIN parking_entries pe ON g.id = pe.entryGateId OR g.id = pe.exitGateId
      WHERE pe.entryTime LIKE '$dateStr%'
      GROUP BY g.id
    ''');

    return {
      'summary': results.first,
      'typeBreakdown': typeResults,
      'gateUsage': gateResults,
    };
  }

  Future<List<Map<String, dynamic>>> getUnpaidEntries() async {
    final db = await database;
    return await db.query(
      'parking_entries',
      where: 'exitTime IS NOT NULL AND isPaid = 0',
      orderBy: 'exitTime DESC',
    );
  }

  // Generate a unique bill number
  Future<String> generateBillNumber() async {
    final db = await database;
    final now = DateTime.now();

    // Format the bill number as YYYYMM-DD
    final datePart = DateFormat('yyyyMM-dd').format(now);

    // Count how many entries already exist for today
    final countResult = await db.rawQuery(
        "SELECT COUNT(*) as count FROM parking_entries WHERE billNumber LIKE '$datePart-%'"
    );
    final count = Sqflite.firstIntValue(countResult) ?? 0;

    // Generate the next bill number with a 2-digit count (01, 02, etc.)
    final nextNumber = (count + 1).toString().padLeft(2, '0');

    return '$datePart-$nextNumber';
  }

  Future<List<Map<String, dynamic>>> getTransactionHistory() async {
    final db = await database;
    return await db.query(
      'parking_entries',
      columns: ['billNumber', 'vehicleType', 'vehicleNo', 'entryTime','exitTime','hoursSpent', 'price', 'isPaid', 'totalPrice', 'entryGateId', 'exitGateId'],
      orderBy: 'entryTime DESC',
    );
  }

  // Get extended transaction details with gate info
  Future<List<Map<String, dynamic>>> getExtendedTransactionHistory() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        pe.billNumber, pe.vehicleType, pe.vehicleNo, pe.entryTime, pe.exitTime,
        pe.hoursSpent, pe.price, pe.isPaid, pe.totalPrice, pe.notes,
        entry_gate.name as entryGateName,
        exit_gate.name as exitGateName
      FROM parking_entries pe
      LEFT JOIN gates entry_gate ON pe.entryGateId = entry_gate.id
      LEFT JOIN gates exit_gate ON pe.exitGateId = exit_gate.id
      ORDER BY pe.entryTime DESC
    ''');
  }

  Future<double> getTotalRevenue() async {
    final db = await database;
    final result = await db.rawQuery('SELECT SUM(totalPrice) as total FROM parking_entries');

    if (result.isNotEmpty && result.first['total'] != null) {
      return (result.first['total'] as num).toDouble();
    }
    return 0.0;
  }

  Future<List<Map<String, dynamic>>> getWeeklyRevenue() async {
    final db = await database;
    final results = await db.rawQuery('''
    SELECT 
      strftime('%Y-%W', entryTime) as weekKey,
      MIN(date(entryTime)) as startDate,
      MAX(date(entryTime)) as endDate,
      COALESCE(SUM(totalPrice), 0) as revenue
    FROM parking_entries
    WHERE isPaid = 1
    GROUP BY weekKey
    ORDER BY startDate DESC
    LIMIT 12
  ''');

    final List<Map<String, dynamic>> weeklyData = results.map((row) {
      final weekKeyParts = (row['weekKey'] as String).split('-');
      return {
        'weekNumber': int.parse(weekKeyParts[1]),
        'year': int.parse(weekKeyParts[0]),
        'startDate': DateTime.parse(row['startDate'] as String),
        'endDate': DateTime.parse(row['endDate'] as String),
        'revenue': (row['revenue'] as num).toDouble(),
      };
    }).toList();

    // For each week, get the daily data
    for (final week in weeklyData) {
      final startDate = week['startDate'];
      final endDate = week['endDate'];

      // Get daily revenue for this date range
      final dailyData = await _getDailyRevenueForDateRange(startDate, endDate);
      week['dailyData'] = dailyData;
    }

    return weeklyData;
  }

  Future<List<Map<String, dynamic>>> _getDailyRevenueForDateRange(DateTime startDate, DateTime endDate) async {
    final db = await database;
    final List<Map<String, dynamic>> dailyData = [];

    // Generate list of dates between start and end
    DateTime currentDate = DateTime(startDate.year, startDate.month, startDate.day);
    final lastDate = DateTime(endDate.year, endDate.month, endDate.day);

    while (!currentDate.isAfter(lastDate)) {
      final dateStr = DateFormat('yyyy-MM-dd').format(currentDate);

      // Query for this specific day's revenue
      final results = await db.rawQuery('''
      SELECT 
        '$dateStr' as date,
        COALESCE(SUM(totalPrice), 0) as revenue
      FROM parking_entries
      WHERE date(entryTime) = '$dateStr' AND isPaid = 1
    ''');

      // Add the result to our daily data
      if (results.isNotEmpty) {
        dailyData.add({
          'date': dateStr,
          'revenue': (results.first['revenue'] as num).toDouble(),
        });
      } else {
        // If no revenue for this day, add zero
        dailyData.add({
          'date': dateStr,
          'revenue': 0.0,
        });
      }

      // Move to next day
      currentDate = currentDate.add(const Duration(days: 1));
    }

    return dailyData;
  }

  Future<List<Map<String, dynamic>>> getMonthlyRevenue() async {
    final db = await database;
    final results = await db.rawQuery('''
    SELECT 
      strftime('%Y-%m', entryTime) as monthKey,
      COALESCE(SUM(totalPrice), 0) as revenue
    FROM parking_entries
    WHERE isPaid = 1
    GROUP BY monthKey
    ORDER BY monthKey DESC
  ''');

    return results.map((row) {
      final monthKey = row['monthKey'] as String;
      final parts = monthKey.split('-');
      return {
        'month': DateTime(int.parse(parts[0]), int.parse(parts[1])),
        'revenue': (row['revenue'] as num).toDouble(),
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getVehicleHistory(String vehicleNumber) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        pe.*, 
        entry_gate.name as entryGateName,
        exit_gate.name as exitGateName
      FROM parking_entries pe
      LEFT JOIN gates entry_gate ON pe.entryGateId = entry_gate.id
      LEFT JOIN gates exit_gate ON pe.exitGateId = exit_gate.id
      WHERE pe.vehicleNo = ?
      ORDER BY pe.entryTime DESC
    ''', [vehicleNumber]);
  }

  // Close the database
  Future close() async {
    final db = await instance.database;
    db.close();
    _database = null;
  }

  // Add these methods to your existing DatabaseHelper class

// Optional modifier timestamp column
  Future<void> addModifiedTimestampColumn() async {
    final db = await database;

    try {
      await db.execute('ALTER TABLE parking_entries ADD COLUMN lastModified TEXT;');
    } catch (e) {
      if (!e.toString().contains('duplicate column name')) {
        print('Error adding lastModified to parking_entries: $e');
      }
    }

    try {
      await db.execute('ALTER TABLE gates ADD COLUMN lastModified TEXT;');
    } catch (e) {
      if (!e.toString().contains('duplicate column name')) {
        print('Error adding lastModified to gates: $e');
      }
    }

    try {
      await db.execute('ALTER TABLE vehicle_types ADD COLUMN lastModified TEXT;');
    } catch (e) {
      if (!e.toString().contains('duplicate column name')) {
        print('Error adding lastModified to vehicle_types: $e');
      }
    }
  }

// Modified insert methods to include timestamp
  Future<int> insertEntryWithTimestamp(Map<String, dynamic> entry) async {
    final now = DateTime.now().toIso8601String();
    entry['lastModified'] = now;
    return await insertEntry(entry);
  }

// Add a method to get entries modified after a certain time
  Future<List<Map<String, dynamic>>> getEntriesModifiedAfter(DateTime timestamp) async {
    final db = await database;
    final timeStr = timestamp.toIso8601String();

    return await db.query(
      'parking_entries',
      where: 'lastModified > ?',
      whereArgs: [timeStr],
      orderBy: 'lastModified DESC',
    );
  }

  // Extension to properly update an entry by bill number
  Future<int> updateEntry(String billNumber, Map<String, dynamic> entry) async {
    // Ensure exit-related fields are present
    final updateData = {
      'billNumber': entry['billNumber'],
      'vehicleType': entry['vehicleType'],
      'vehicleNo': entry['vehicleNo'],
      'entryTime': entry['entryTime'],
      'exitTime': entry['exitTime'], // Include exitTime if it exists
      'entryGateId': entry['entryGateId'],
      'entryGateName': entry['entryGateName'],
      'exitGateId': entry['exitGateId'], // Include exitGateId
      'exitGateName': entry['exitGateName'], // Include exitGateName
      'hoursSpent': entry['hoursSpent'],
      'price': entry['price'],
      'totalPrice': entry['totalPrice'],
      'isPaid': entry['isPaid'],
      'notes': entry['notes'],
      'lastModified': DateTime.now().toIso8601String(), // Update lastModified
    };

    // Filter out any null fields, as SQLite will ignore them during an update
    updateData.removeWhere((key, value) => value == null);

    final db = await database;

    return await db.update(
      'parking_entries',
      updateData,
      where: 'billNumber = ?',
      whereArgs: [billNumber],
    );
  }


// Get sync status for a specific table
  Future<Map<String, dynamic>> getSyncStatus(String tableName) async {
    final db = await database;
    final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $tableName')
    ) ?? 0;

    return {
      'tableName': tableName,
      'recordCount': count,
      'lastSyncTime': null // This would be stored in SharedPreferences
    };
  }

  // Add this function to your DatabaseHelper class
  Future<void> clearAllDataOnLogout() async {
    final db = await database;

    try {
      await db.transaction((txn) async {
        // Clear table data
        await txn.delete('parking_entries');
        await txn.delete('user_data');
        await txn.delete('user');
        await txn.delete('gates');

        // Reset parking spaces (assuming ID 1 is default)
        await txn.update(
          'spaces',
          {'totalSpaces': 100, 'occupiedSpaces': 0},
          where: 'id = ?',
          whereArgs: [1],
        );
      });

      print('All data cleared and reset successfully.');

      // Reinitialize the database if needed
      await close(); // Close the current DB instance
      await _initDB('parking.db'); // Reinitialize (same file name)

    } catch (e) {
      print('Error during logout cleanup: $e');
      throw e;
    }
  }
}