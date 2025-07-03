import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../DatabaseHelper.dart';

class DatabaseSyncService {
  final String baseUrl; // Your API endpoint
  final DatabaseHelper dbHelper;

  DatabaseSyncService({required this.baseUrl, required this.dbHelper});

  // Get the auth token from SharedPreferences
  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // Create headers with auth token
  // Private method
  Future<Map<String, String>> _getHeaders() async {
    final token = await _getAuthToken();
    final headers = {
      'Content-Type': 'application/json',
    };

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  // Public wrapper
  Future<Map<String, String>> getHeaders() {
    return _getHeaders();
  }

  // Track last sync time
  Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSyncTimeStr = prefs.getString('last_sync_time');
    return lastSyncTimeStr != null ? DateTime.parse(lastSyncTimeStr) : null;
  }

  Future<void> saveLastSyncTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_sync_time', time.toIso8601String());
  }

  // Check for connectivity
  Future<bool> hasInternetConnection() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  // ==============================================
  // MAIN SYNC METHODS - SEPARATED PULL AND PUSH
  // ==============================================

  /// Main method to pull all data from server to local database
  Future<bool> pullAllFromServer() async {
    print('Starting pull operation from server...');

    if (!await hasInternetConnection()) {
      print('No internet connection. Pull operation skipped.');
      return false;
    }

    bool success = true;
    final lastSync = await getLastSyncTime();

    try {
      // Pull parking entries
      try {
        await pullParkingEntries(lastSync);
        print('✅ Parking entries pulled successfully');
      } catch (e) {
        print('❌ Failed to pull parking entries: $e');
        success = false;
      }

      // Pull vehicle types
      try {
        await pullVehicleTypes();
        print('✅ Vehicle types pulled successfully');
      } catch (e) {
        print('❌ Failed to pull vehicle types: $e');
        success = false;
      }

      // Pull gates
      try {
        await pullGates();
        print('✅ Gates pulled successfully');
      } catch (e) {
        print('❌ Failed to pull gates: $e');
        success = false;
      }

      // Pull spaces
      try {
        await pullSpaces();
        print('✅ Spaces pulled successfully');
      } catch (e) {
        print('❌ Failed to pull spaces: $e');
        success = false;
      }

      // Pull user info
      try {
        await pullUserInfo();
        print('✅ User info pulled successfully');
      } catch (e) {
        print('❌ Failed to pull user info: $e');
        success = false;
      }

      if (success) {
        print('🎉 Pull operation completed successfully');
      } else {
        print('⚠️ Pull operation completed with some errors');
      }

      return success;
    } catch (e) {
      print('💥 Unexpected error during pull operation: $e');
      return false;
    }
  }

  /// Main method to push all data from local database to server
  Future<bool> pushAllToServer() async {
    print('Starting push operation to server...');

    if (!await hasInternetConnection()) {
      print('No internet connection. Push operation skipped.');
      return false;
    }

    bool success = true;

    try {
      // Push parking entries
      try {
        await pushParkingEntries();
        print('✅ Parking entries pushed successfully');
      } catch (e) {
        print('❌ Failed to push parking entries: $e');
        success = false;
      }

      // Push vehicle types
      try {
        await pushVehicleTypes();
        print('✅ Vehicle types pushed successfully');
      } catch (e) {
        print('❌ Failed to push vehicle types: $e');
        success = false;
      }

      // Push gates
      try {
        await pushGates();
        print('✅ Gates pushed successfully');
      } catch (e) {
        print('❌ Failed to push gates: $e');
        success = false;
      }

      // Push spaces
      try {
        await pushSpaces();
        print('✅ Spaces pushed successfully');
      } catch (e) {
        print('❌ Failed to push spaces: $e');
        success = false;
      }

      // Push user info
      try {
        await pushUserInfo();
        print('✅ User info pushed successfully');
      } catch (e) {
        print('❌ Failed to push user info: $e');
        success = false;
      }

      if (success) {
        await saveLastSyncTime(DateTime.now());
        print('🎉 Push operation completed successfully');
      } else {
        print('⚠️ Push operation completed with some errors');
      }

      return success;
    } catch (e) {
      print('💥 Unexpected error during push operation: $e');
      return false;
    }
  }

  /// Full bidirectional sync (push then pull)
  Future<bool> syncDatabase() async {
    print('Starting full database sync...');
    print('baseUrl: $baseUrl');

    if (!await hasInternetConnection()) {
      print('No internet connection. Sync skipped.');
      return false;
    }

    bool pushSuccess = await pushAllToServer();
    bool pullSuccess = await pullAllFromServer();

    bool overallSuccess = pushSuccess && pullSuccess;

    if (overallSuccess) {
      await saveLastSyncTime(DateTime.now());
      print('🎉 Database sync completed successfully');
    } else {
      print('⚠️ Database sync completed with some errors');
      print('Push success: $pushSuccess, Pull success: $pullSuccess');
    }

    return overallSuccess;
  }

  // ==============================================
  // PULL OPERATIONS (SERVER TO LOCAL)
  // ==============================================

  Future<void> pullParkingEntries(DateTime? lastSync) async {
    try {
      String url = '$baseUrl/parking-entries';
      if (lastSync != null) {
        url += '?updatedAfter=${Uri.encodeComponent(lastSync.toIso8601String())}';
      }

      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> entries = json.decode(response.body);
        final gates = await dbHelper.getAllGates();

        for (var entry in entries) {
          final String billNumber = entry['billNumber'];

          // Add gate names
          final entryGate = gates.firstWhere(
                (g) => g['id'] == entry['entryGateId'],
            orElse: () => <String, dynamic>{},
          );
          if (entryGate.isNotEmpty) {
            entry['entryGateName'] = entryGate['name'];
          }

          if (entry['exitGateId'] != null) {
            final exitGate = gates.firstWhere(
                  (g) => g['id'] == entry['exitGateId'],
              orElse: () => <String, dynamic>{},
            );
            if (exitGate.isNotEmpty) {
              entry['exitGateName'] = exitGate['name'];
            }
          }

          // Normalize isPaid
          entry['isPaid'] =
          (entry['isPaid'] == true || entry['isPaid'] == 1 || entry['isPaid'] == 'true') ? 1 : 0;

          // Remove MongoDB-specific fields
          entry.remove('_id');

          // Clean entry before inserting/updating
          final filteredEntry = cleanEntry(entry);

          final existingEntry = await dbHelper.getEntryByBill(billNumber);
          if (existingEntry == null) {
            await dbHelper.insertEntry(filteredEntry);
          } else {
            await dbHelper.updateEntry(billNumber, filteredEntry);
          }
        }
      } else {
        throw Exception('Failed to fetch entries: ${response.statusCode}');
      }
    } catch (e) {
      print('Error pulling parking entries: $e');
      rethrow;
    }
  }

  Future<void> pullVehicleTypes() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/vehicle-types'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> types = json.decode(response.body);
        final existingTypes = await dbHelper.getVehicleTypes();
        print("Fetched vehicle types: $existingTypes");

        for (var type in types) {
          // Skip if 'id' or 'type' is missing
          if (type['id'] == null || type['type'] == null) {
            print('⚠️ Skipped invalid vehicle type: $type');
            continue;
          }

          // Remove MongoDB and unwanted fields
          type.remove('_id');
          type.remove('__v');

          // Prepare a cleaned local type map
          final localType = {
            'id': type['id'],
            'type': type['type'] ?? '',
            'price': type['price'] ?? 0,
          };

          // Check if the vehicle type exists
          final existingType = existingTypes.firstWhere(
                (t) => t['id'] == localType['id'],
            orElse: () => <String, dynamic>{},
          );

          if (existingType.isEmpty) {
            await dbHelper.insertVehicleType(localType);
            print('🟢 Inserted: ${localType['type']}');
          } else {
            await dbHelper.updateVehicleType(localType['id'], localType);
            print('🔁 Updated: ${localType['type']}');
          }
        }

        print('✅ Vehicle type pull completed.');
      } else {
        throw Exception('Failed to fetch vehicle types: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error pulling vehicle types: $e');
      rethrow;
    }
  }

  Future<void> pullGates() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/gates'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> gates = json.decode(response.body);

        for (var gate in gates) {
          // Clean the gate before using it
          final cleanedGate = cleanGate(gate);

          // Check if gate exists by name
          final existingGates = await dbHelper.getAllGates();
          final existingGate = existingGates.firstWhere(
                (g) => g['name'] == cleanedGate['name'],
            orElse: () => <String, dynamic>{},
          );

          if (existingGate.isEmpty) {
            await dbHelper.insertGate(cleanedGate);
          } else {
            await dbHelper.updateGate(existingGate['id'], cleanedGate);
          }
        }
      } else {
        throw Exception('Failed to fetch gates: ${response.statusCode}');
      }
    } catch (e) {
      print('Error pulling gates: $e');
      rethrow;
    }
  }

  Future<void> pullSpaces() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/spaces'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> spaces = json.decode(response.body);

        // Update local DB with latest totalSpaces if available
        if (spaces.containsKey('totalSpaces')) {
          await dbHelper.updateTotalSpaces(spaces['totalSpaces']);
        }
      } else {
        throw Exception('Failed to pull spaces: ${response.statusCode}');
      }
    } catch (e) {
      print('Error pulling spaces: $e');
      rethrow;
    }
  }

  Future<void> pullUserInfo() async {
    try {
      print('[pullUserInfo] Pulling user info from server...');
      final headers = await _getHeaders();

      final response = await http.get(
        Uri.parse('$baseUrl/user'),
        headers: headers,
      );
      print('[pullUserInfo] Response status: ${response.statusCode}');
      print('[pullUserInfo] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> serverUserInfo = json.decode(response.body);

        // Update local user info
        if (serverUserInfo.isNotEmpty) {
          print('[pullUserInfo] Updating local user info from server data...');
          await dbHelper.saveUser(
            serverUserInfo['name'] ?? '',
            serverUserInfo['companyName'] ?? '',
            serverUserInfo['address'] ?? '',
            logoPath: serverUserInfo['logoPath'],
            footerText: serverUserInfo['footerText'],
          );
          print('[pullUserInfo] Local user info updated successfully.');
        } else {
          print('[pullUserInfo] Server returned empty user info.');
        }
      } else {
        throw Exception('Failed to pull user info from server: ${response.statusCode}');
      }
    } catch (e) {
      print('[pullUserInfo] Error pulling user info: $e');
      rethrow;
    }
  }

  // ==============================================
  // PUSH OPERATIONS (LOCAL TO SERVER)
  // ==============================================

  Future<void> pushParkingEntries([DateTime? lastSync]) async {
    try {
      // Get all entries (or modified since last sync if implemented)
      List<Map<String, dynamic>> entries;
      if (lastSync != null) {
        // This would require a new method in DatabaseHelper to get entries modified after a certain time
        // For now, we'll push all entries as a fallback
        entries = await dbHelper.getAllEntries();
      } else {
        entries = await dbHelper.getAllEntries();
      }

      final headers = await _getHeaders();
      // Send entries to server
      final response = await http.post(
        Uri.parse('$baseUrl/parking-entries/bulk'),
        headers: headers,
        body: json.encode(entries),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to push entries: ${response.statusCode}');
      }
    } catch (e) {
      print('Error pushing parking entries: $e');
      rethrow;
    }
  }

  Future<void> pushVehicleTypes() async {
    try {
      // Step 1: Fetch vehicle types from local DB
      final types = await dbHelper.getVehicleTypes();
      print("📦 Vehicle types fetched from DB: $types");

      // Step 2: Prepare headers
      final headers = await _getHeaders();
      print("🧾 Request headers: $headers");

      // Step 3: Make POST request to server
      final url = Uri.parse('$baseUrl/vehicle-types/bulk');
      print("🌐 Sending POST request to: $url");

      final response = await http.post(
        url,
        headers: headers,
        body: json.encode(types),
      );

      print("📨 Server responded with status: ${response.statusCode}");
      print("📨 Server response body: ${response.body}");

      // Step 4: Check response status
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('❌ Failed to push vehicle types: ${response.statusCode}');
      }

      print("✅ Vehicle types pushed successfully.");
    } catch (e, stackTrace) {
      print('🚨 Error pushing vehicle types: $e');
      print('🧵 Stack trace:\n$stackTrace');
      rethrow;
    }
  }

  Future<void> pushGates() async {
    try {
      final gates = await dbHelper.getAllGates();
      print('Pushing gates: $gates');
      final headers = await _getHeaders();

      final response = await http.post(
        Uri.parse('$baseUrl/gates/bulk'),
        headers: headers,
        body: json.encode(gates),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to push gates: ${response.statusCode}');
      }
    } catch (e) {
      print('Error pushing gates: $e');
      rethrow;
    }
  }

  Future<void> pushSpaces() async {
    try {
      final headers = await _getHeaders();
      final localSpacesSummary = await dbHelper.getParkingSpaceInfo();

      final pushData = {
        'totalSpaces': localSpacesSummary['totalSpaces'],
        'occupiedSpaces': localSpacesSummary['occupiedSpaces'],
      };

      print('Pushing spaces to server: $pushData');

      final response = await http.post(
        Uri.parse('$baseUrl/spaces'),
        headers: headers,
        body: json.encode(pushData),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to push spaces: ${response.statusCode}');
      }
    } catch (e) {
      print('Error pushing spaces: $e');
      rethrow;
    }
  }

  Future<void> pushUserInfo() async {
    try {
      print('[pushUserInfo] Starting user push');

      final headers = await _getHeaders();
      print('[pushUserInfo] Retrieved headers: $headers');

      // Get local user info
      final userInfo = await dbHelper.getUser();
      print('[pushUserInfo] Local user info: $userInfo');

      if (userInfo != null) {
        print('[pushUserInfo] Pushing local user info to server...');
        // Push to server
        final response = await http.post(
          Uri.parse('$baseUrl/user'),
          headers: headers,
          body: json.encode(userInfo),
        );
        print('[pushUserInfo] Push response status: ${response.statusCode}');
        print('[pushUserInfo] Push response body: ${response.body}');

        if (response.statusCode != 200 && response.statusCode != 201) {
          throw Exception('Failed to push user info: ${response.statusCode}');
        }
      } else {
        print('[pushUserInfo] No local user info found to push.');
      }
    } catch (e) {
      print('[pushUserInfo] Error pushing user info: $e');
      rethrow;
    }
  }

  // ==============================================
  // LEGACY SYNC METHODS (for backward compatibility)
  // ==============================================

  /// @deprecated Use pullAllFromServer() and pushAllToServer() instead
  Future<void> syncParkingEntries(DateTime? lastSync) async {
    await pushParkingEntries(lastSync);
    await pullParkingEntries(lastSync);
  }

  /// @deprecated Use pullVehicleTypes() and pushVehicleTypes() instead
  Future<void> syncVehicleTypes(DateTime? lastSync) async {
    await pushVehicleTypes();
    await pullVehicleTypes();
  }

  /// @deprecated Use pullGates() and pushGates() instead
  Future<void> syncGates(DateTime? lastSync) async {
    await pushGates();
    await pullGates();
  }

  /// @deprecated Use pullSpaces() and pushSpaces() instead
  Future<void> syncSpaces() async {
    await pushSpaces();
    await pullSpaces();
  }

  /// @deprecated Use pullUserInfo() and pushUserInfo() instead
  Future<void> syncUserInfo() async {
    await pushUserInfo();
    await pullUserInfo();
  }

  // ==============================================
  // UTILITY METHODS
  // ==============================================

  /// Keeps only allowed fields and sets default values to avoid null errors
  Map<String, dynamic> cleanEntry(Map<String, dynamic> entry) {
    return {
      'id': entry['id'] ?? 0,
      'billNumber': entry['billNumber'] ?? '',
      'vehicleType': entry['vehicleType'] ?? '',
      'vehicleNo': entry['vehicleNo'] ?? '',
      'entryTime': entry['entryTime'] ?? '',
      'exitTime': entry['exitTime'] ?? '',
      'entryGateId': entry['entryGateId'] ?? 0,
      'entryGateName': entry['entryGateName'] ?? '',
      'exitGateId': entry['exitGateId'] ?? 0,
      'exitGateName': entry['exitGateName'] ?? '',
      'hoursSpent': entry['hoursSpent'] ?? 0,
      'price': entry['price'] != null ? entry['price'].toString() : '',
      'totalPrice': entry['totalPrice'] ?? '0',
      'isPaid': entry['isPaid'] ?? 0,
      'notes': entry['notes'] ?? '',
      'lastModified': entry['lastModified'] ?? '',
    };
  }

  /// Ensuring no nulls and removing unnecessary fields.
  Map<String, dynamic> cleanGate(Map<String, dynamic> gate) {
    return {
      'id': gate['id'] ?? 0,
      'name': gate['name'] ?? '',
      'location': gate['location'] ?? '',
      'isActive': (gate['isActive'] == true || gate['isActive'] == 1) ? 1 : 0,
      'type': gate['type'] ?? '',
      'notes': gate['notes'] ?? '',
      'lastModified': gate['updatedAt'] ?? '',
    };
  }

  // ==============================================
  // OFFLINE SYNC QUEUE MANAGEMENT
  // ==============================================

  // Add a method to add to sync queue for offline operation
  Future<void> addToSyncQueue(String operation, String table, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final syncQueueJson = prefs.getString('sync_queue') ?? '[]';
    final List<dynamic> syncQueue = json.decode(syncQueueJson);

    // Add operation to queue
    syncQueue.add({
      'timestamp': DateTime.now().toIso8601String(),
      'operation': operation, // INSERT, UPDATE, DELETE
      'table': table,
      'data': data,
    });

    // Save updated queue
    await prefs.setString('sync_queue', json.encode(syncQueue));
  }

  // Process pending operations in sync queue
  Future<void> processSyncQueue() async {
    if (!await hasInternetConnection()) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final syncQueueJson = prefs.getString('sync_queue') ?? '[]';
    final List<dynamic> syncQueue = json.decode(syncQueueJson);

    if (syncQueue.isEmpty) {
      return;
    }

    final List<dynamic> remainingOperations = [];

    for (var operation in syncQueue) {
      try {
        final success = await _processSingleQueueItem(operation);
        if (!success) {
          remainingOperations.add(operation);
        }
      } catch (e) {
        print('Error processing queue item: $e');
        remainingOperations.add(operation);
      }
    }

    // Update queue with remaining operations
    await prefs.setString('sync_queue', json.encode(remainingOperations));
  }

  Future<bool> _processSingleQueueItem(Map<String, dynamic> operation) async {
    final table = operation['table'];
    final data = Map<String, dynamic>.from(operation['data']);
    final operationType = operation['operation'];

    try {
      switch (table) {
        case 'parking_entries':
          return await _syncParkingEntryOperation(operationType, data);
        case 'vehicle_types':
          return await _syncVehicleTypeOperation(operationType, data);
        case 'gates':
          return await _syncGateOperation(operationType, data);
        default:
          return false;
      }
    } catch (e) {
      print('Error processing operation for $table: $e');
      return false;
    }
  }

  Future<bool> _syncParkingEntryOperation(String operation, Map<String, dynamic> data) async {
    try {
      final headers = await _getHeaders();
      switch (operation) {
        case 'INSERT':
        case 'UPDATE':
          final response = await http.post(
            Uri.parse('$baseUrl/parking-entries'),
            headers: headers,
            body: json.encode(data),
          );
          return response.statusCode >= 200 && response.statusCode < 300;

        case 'DELETE':
          final response = await http.delete(
            Uri.parse('$baseUrl/parking-entries/${data['billNumber']}'),
            headers: headers,
          );
          return response.statusCode >= 200 && response.statusCode < 300;

        default:
          return false;
      }
    } catch (e) {
      print('Error in _syncParkingEntryOperation: $e');
      return false;
    }
  }

  Future<bool> _syncVehicleTypeOperation(String operation, Map<String, dynamic> data) async {
    try {
      final headers = await _getHeaders();
      switch (operation) {
        case 'INSERT':
        case 'UPDATE':
          final response = await http.post(
            Uri.parse('$baseUrl/vehicle-types'),
            headers: headers,
            body: json.encode(data),
          );
          return response.statusCode >= 200 && response.statusCode < 300;

        case 'DELETE':
          final response = await http.delete(
            Uri.parse('$baseUrl/vehicle-types/${data['id']}'),
            headers: headers,
          );
          return response.statusCode >= 200 && response.statusCode < 300;

        default:
          return false;
      }
    } catch (e) {
      print('Error in _syncVehicleTypeOperation: $e');
      return false;
    }
  }

  Future<bool> _syncGateOperation(String operation, Map<String, dynamic> data) async {
    try {
      final headers = await _getHeaders();
      switch (operation) {
        case 'INSERT':
        case 'UPDATE':
          final response = await http.post(
            Uri.parse('$baseUrl/gates'),
            headers: headers,
            body: json.encode(data),
          );
          return response.statusCode >= 200 && response.statusCode < 300;

        case 'DELETE':
          final response = await http.delete(
            Uri.parse('$baseUrl/gates/${data['id']}'),
            headers: headers,
          );
          return response.statusCode >= 200 && response.statusCode < 300;

        default:
          return false;
      }
    } catch (e) {
      print('Error in _syncGateOperation: $e');
      return false;
    }
  }
}