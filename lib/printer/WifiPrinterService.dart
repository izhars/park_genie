import 'dart:async';
import 'dart:io';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:ping_discover_network_forked/ping_discover_network_forked.dart';
import 'PrinterDatabaseHelper.dart';
import 'PrinterType.dart';

class WifiPrinterService {
  static final WifiPrinterService _instance = WifiPrinterService._internal();
  factory WifiPrinterService() => _instance;

  final PrinterDatabaseHelper _dbHelper = PrinterDatabaseHelper();

  // Connection tracking properties
  bool isConnected = false;
  String? connectedIpAddress;
  Timer? _connectionCheckTimer;

  // Notifiers for reactive UI updates
  final ValueNotifier<bool> connectionNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String> statusNotifier = ValueNotifier<String>("No Printer Connected");

  WifiPrinterService._internal() {
    _loadSavedPrinter();
  }

  Future<void> _loadSavedPrinter() async {
    try {
      final defaultPrinter = await _dbHelper.getDefaultPrinterType();
      if (defaultPrinter != null && defaultPrinter['type'] == 'wifi') {
        final printerType = PrinterType.fromMap(defaultPrinter);

        if (printerType.address != null) {
          statusNotifier.value = "Trying to connect to saved printer: ${printerType.name}";
          await connectToPrinter(printerType.address!);
        }
      }
    } catch (e) {
      statusNotifier.value = "Failed to load saved printer: $e";
    }
  }

  // Get current WiFi network name
  Future<String?> getCurrentNetwork() async {
    try {
      final info = NetworkInfo();
      return await info.getWifiName();
    } catch (e) {
      return "Unknown Network";
    }
  }

  // Scan network for printers
  Future<List<String>> scanNetworkForPrinters() async {
    final List<String> printers = [];

    try {
      final info = NetworkInfo();
      final String? ip = await info.getWifiIP();

      if (ip == null) return [];

      // Extract subnet from IP
      final subnet = ip.substring(0, ip.lastIndexOf('.'));

      // Scan common printer ports (9100 is common for raw printing)
      final stream = NetworkAnalyzer.discover2(subnet, 9100);

      await for (final addr in stream) {
        if (addr.exists) {
          printers.add(addr.ip);
        }
      }

      statusNotifier.value = "Scan completed: ${printers.length} printers found";
      return printers;
    } catch (e) {
      statusNotifier.value = "Scan error: $e";
      return [];
    }
  }

  // Connect to printer at specified IP
  Future<bool> connectToPrinter(String ipAddress) async {
    if (isConnected) await disconnectPrinter();

    statusNotifier.value = "Connecting to printer at $ipAddress...";

    try {
      // Try to connect to the printer (port 9100 is common for raw printing)
      final socket = await Socket.connect(ipAddress, 9100,
          timeout: const Duration(seconds: 5));

      // Get host information (if possible)
      final internetAddress = socket.remoteAddress;
      final printerName = internetAddress.host; // This might return IP or name

      debugPrint("Connected Printer Details -----");
      debugPrint("connected: true");
      debugPrint("ipAddress: $ipAddress");
      debugPrint("printerName: $printerName");
      debugPrint("hostAddress: ${internetAddress.address}");
      debugPrint("type: ${internetAddress.type.name}");
      debugPrint("-------------------------------------");

      socket.destroy(); // Close the socket as we just needed to test connection

      // Set connection status
      isConnected = true;
      connectedIpAddress = ipAddress;
      connectionNotifier.value = true;
      statusNotifier.value = "Connected to printer at $ipAddress";

      // Save this printer to the database
      await savePrinterToDatabase(ipAddress);

      // Start periodic connection checks
      _startConnectionMonitoring();

      return true;
    } catch (e) {
      isConnected = false;
      connectedIpAddress = null;
      connectionNotifier.value = false;
      statusNotifier.value = "Connection error: $e";
      return false;
    }
  }


  // Save printer to database
  Future<void> savePrinterToDatabase(String ipAddress) async {
    try {
      final printerType = PrinterType(
        name: "WiFi Printer ($ipAddress)",
        address: ipAddress,
        deviceType: "wifi",
        isDefault: true,
        isActive: true,
        lastConnected: DateTime.now(),
      );

      final existingPrinters = await _dbHelper.getAllPrinterTypes();
      final existingPrinter = existingPrinters.firstWhere(
            (printer) =>
        printer['address'] == ipAddress &&
            printer['deviceType'] == 'wifi',
        orElse: () => <String, dynamic>{},
      );

      if (existingPrinter.isEmpty) {
        await _dbHelper.insertPrinterType(printerType.toMap());
        statusNotifier.value = "Printer $ipAddress saved to database";
      } else {
        await _dbHelper.updatePrinterType(
          existingPrinter['id'],
          printerType.copyWith(id: existingPrinter['id']).toMap(),
        );
        statusNotifier.value = "Printer $ipAddress updated in database";
      }

      final defaultId = existingPrinter.isEmpty
          ? await _getLastInsertedPrinterId()
          : existingPrinter['id'];

      await _dbHelper.setDefaultPrinter(defaultId);
    } catch (e) {
      statusNotifier.value = "Error saving printer: $e";
    }
  }


  Future<int> _getLastInsertedPrinterId() async {
    final allPrinters = await _dbHelper.getAllPrinterTypes();
    if (allPrinters.isEmpty) return -1;
    return allPrinters.reduce((a, b) => a['id'] > b['id'] ? a : b)['id'];
  }

  // Check if the printer is still connected
  Future<bool> checkConnection() async {
    if (connectedIpAddress == null) {
      isConnected = false;
      connectionNotifier.value = false;
      return false;
    }

    try {
      // Try to connect to the printer to check if it's still available
      final socket = await Socket.connect(connectedIpAddress!, 9100,
          timeout: const Duration(seconds: 2));
      socket.destroy(); // Close the socket as we just needed to test connection

      // Connection successful
      if (!isConnected) {
        statusNotifier.value = "Reconnected to printer at $connectedIpAddress";
      }

      isConnected = true;
      connectionNotifier.value = true;
      return true;
    } catch (e) {
      // Connection failed
      if (isConnected) {
        statusNotifier.value = "Connection lost to printer at $connectedIpAddress";
      }

      isConnected = false;
      connectionNotifier.value = false;
      return false;
    }
  }

  // Start periodic connection monitoring
  void _startConnectionMonitoring() {
    // Cancel any existing timer
    _connectionCheckTimer?.cancel();

    // Check connection every 5 seconds
    _connectionCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      await checkConnection();
    });
  }

  // Stop connection monitoring
  void _stopConnectionMonitoring() {
    _connectionCheckTimer?.cancel();
    _connectionCheckTimer = null;
  }

  // Disconnect from the printer
  Future<void> disconnectPrinter() async {
    _stopConnectionMonitoring();

    if (isConnected) {
      isConnected = false;
      connectionNotifier.value = false;
      statusNotifier.value = "Disconnected from printer at $connectedIpAddress";
      connectedIpAddress = null;
    }
  }

  // Test print to verify connection
  Future<bool> printTest() async {
    if (!isConnected || connectedIpAddress == null) {
      statusNotifier.value = "Printer not connected";
      return false;
    }

    try {
      // Log printer details
      final printerDetails = await getConnectedPrinterDetails();

      // Print printer details to console (log)
      debugPrint("----- Connected Printer Details -----");
      printerDetails.forEach((key, value) {
        debugPrint("$key: $value");
      });
      debugPrint("-------------------------------------");

      // Continue with the normal test print
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm58, profile);
      List<int> bytes = [];

      bytes += generator.setGlobalCodeTable('CP1252');
      bytes += generator.setStyles(const PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ));
      bytes += generator.text("Test Receipt");

      bytes += generator.setStyles(const PosStyles(align: PosAlign.center));
      bytes += generator.text("Printer Working");

      bytes += generator.feed(3);
      bytes += generator.cut();

      final socket = await Socket.connect(connectedIpAddress!, 9100);
      socket.add(bytes);
      await socket.flush();
      await socket.close();

      statusNotifier.value = "Test printed successfully";
      return true;
    } catch (e) {
      statusNotifier.value = "Print error: $e";
      await checkConnection();
      return false;
    }
  }


  // Get and print all details of the connected printer
  Future<Map<String, dynamic>> getConnectedPrinterDetails() async {
    if (!isConnected || connectedIpAddress == null) {
      statusNotifier.value = "No printer connected";
      return {
        'connected': false,
        'message': 'No printer connected'
      };
    }

    try {
      // Get details about the connected printer
      Map<String, dynamic> printerDetails = {
        'connected': true,
        'ipAddress': connectedIpAddress,
        'connectionTime': null,
        'printerName': 'Unknown',
        'networkName': await getCurrentNetwork(),
        'defaultPrinter': false,
      };

      // Try to get saved printer information from database
      final allPrinters = await _dbHelper.getAllPrinterTypes();
      final matchingPrinter = allPrinters.firstWhere(
            (printer) => printer['address'] == connectedIpAddress && printer['type'] == 'wifi',
        orElse: () => <String, dynamic>{},
      );

      // If we found this printer in the database, get additional details
      if (matchingPrinter.isNotEmpty) {
        final printerType = PrinterType.fromMap(matchingPrinter);
        printerDetails['printerName'] = printerType.name;
        printerDetails['id'] = printerType.id;
        printerDetails['isDefault'] = printerType.isDefault;
        printerDetails['isActive'] = printerType.isActive;
        printerDetails['lastConnected'] = printerType.lastConnected?.toIso8601String();
      }

      statusNotifier.value = "Retrieved printer details for ${printerDetails['printerName']}";
      return printerDetails;
    } catch (e) {
      statusNotifier.value = "Error getting printer details: $e";
      return {
        'connected': isConnected,
        'ipAddress': connectedIpAddress,
        'error': e.toString(),
      };
    }
  }

  // Print comprehensive test receipt with printer details
  Future<bool> printPrinterDetails() async {
    if (!isConnected || connectedIpAddress == null) {
      statusNotifier.value = "Printer not connected";
      return false;
    }

    try {
      // Get printer details
      final printerDetails = await getConnectedPrinterDetails();

      // Print to console (debug log)
      debugPrint("----- Connected Printer Details -----");
      printerDetails.forEach((key, value) {
        debugPrint("$key: $value");
      });
      debugPrint("-------------------------------------");

      // Generate receipt
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm58, profile);
      List<int> bytes = [];

      bytes += generator.setGlobalCodeTable('CP1252');

      // Header
      bytes += generator.setStyles(const PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ));
      bytes += generator.text("Printer Details");
      bytes += generator.feed(1);

      // Reset to normal text
      bytes += generator.setStyles(const PosStyles(align: PosAlign.left));

      // Print details
      bytes += generator.text("Printer Name: ${printerDetails['printerName']}");
      bytes += generator.text("IP Address: ${printerDetails['ipAddress']}");
      bytes += generator.text("Network: ${printerDetails['networkName']}");
      bytes += generator.text("Default Printer: ${printerDetails['isDefault'] ? 'Yes' : 'No'}");
      bytes += generator.text("Status: ${isConnected ? 'Connected' : 'Disconnected'}");

      if (printerDetails['lastConnected'] != null) {
        bytes += generator.text("Last Connected: ${printerDetails['lastConnected']}");
      }

      bytes += generator.feed(1);
      bytes += generator.text("Time: ${DateTime.now().toString()}");

      // Print divider
      bytes += generator.feed(1);
      bytes += generator.text("--------------------------------");
      bytes += generator.feed(1);

      bytes += generator.setStyles(const PosStyles(align: PosAlign.center));
      bytes += generator.text("Connection Test Successful");

      bytes += generator.feed(3);
      bytes += generator.cut();

      final socket = await Socket.connect(connectedIpAddress!, 9100);
      socket.add(bytes);
      await socket.flush();
      await socket.close();

      statusNotifier.value = "Printer details printed successfully";
      return true;
    } catch (e) {
      statusNotifier.value = "Print error: $e";
      await checkConnection();
      return false;
    }
  }


  // Database operations for printer types
  Future<List<PrinterType>> getAllSavedPrinters() async {
    final printerMaps = await _dbHelper.getAllPrinterTypes();
    return printerMaps.map((map) => PrinterType.fromMap(map)).toList();
  }

  Future<List<PrinterType>> getActiveSavedPrinters() async {
    final printerMaps = await _dbHelper.getActivePrinterTypes();
    return printerMaps.map((map) => PrinterType.fromMap(map)).toList();
  }

  Future<PrinterType?> getDefaultSavedPrinter() async {
    final printerMap = await _dbHelper.getDefaultPrinterType();
    return printerMap != null ? PrinterType.fromMap(printerMap) : null;
  }

  Future<bool> setDefaultPrinter(int id) async {
    final result = await _dbHelper.setDefaultPrinter(id);
    return result > 0;
  }

  Future<bool> deactivatePrinter(int id) async {
    final result = await _dbHelper.deactivatePrinterType(id);
    return result > 0;
  }

  // Clean up resources
  void dispose() {
    _stopConnectionMonitoring();
    connectionNotifier.dispose();
    statusNotifier.dispose();
  }
}