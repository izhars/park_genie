import 'dart:io';
import 'package:flutter/material.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart' as thermal;
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fblue;
import 'package:permission_handler/permission_handler.dart';
import 'PrinterDatabaseHelper.dart';
import 'PrinterType.dart';

class BluetoothPrinterService {
  static final BluetoothPrinterService _instance = BluetoothPrinterService._internal();
  factory BluetoothPrinterService() => _instance;

  final PrinterDatabaseHelper _dbHelper = PrinterDatabaseHelper();

  BluetoothPrinterService._internal() {
    _setupBluetoothListener();
    _loadSavedPrinter();
  }

  final thermal.BlueThermalPrinter printer = thermal.BlueThermalPrinter.instance;
  List<thermal.BluetoothDevice> devices = [];
  thermal.BluetoothDevice? selectedDevice;
  bool isConnected = false;
  String statusMessage = "No Printer Connected";

  final ValueNotifier<bool> connectionNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String> statusNotifier = ValueNotifier<String>("No Printer Connected");
  final ValueNotifier<List<thermal.BluetoothDevice>> devicesNotifier =
  ValueNotifier<List<thermal.BluetoothDevice>>([]);

  Future<void> _loadSavedPrinter() async {
    try {
      final defaultPrinterMap = await _dbHelper.getDefaultPrinterType();

      if (defaultPrinterMap != null) {
        final printerType = PrinterType.fromMap(defaultPrinterMap);

        if (printerType.deviceType == 'thermal' && printerType.address != null) {
          final bondedDevices = await thermal.BlueThermalPrinter.instance.getBondedDevices();

          final bluetoothDevice = PrinterType.findBluetoothDevice(
            bondedDevices,
            printerType.address,
          );

          if (bluetoothDevice != null) {
            _updateStatus("Trying to connect to saved printer: ${printerType.name}");
            await connectToPrinter(bluetoothDevice);
          } else {
            _updateStatus("Saved printer not found in paired devices.");
          }
        }
      }
    } catch (e) {
      _updateStatus("Failed to load saved printer: $e");
    }
  }

  // Save a connected printer to the database
  Future<void> savePrinterToDatabase(thermal.BluetoothDevice device, {bool setAsDefault = false}) async {
    final printerType = PrinterType.fromBluetoothDevice(device);

    final updatedPrinter = printerType.copyWith(
      isDefault: setAsDefault,
      lastConnected: DateTime.now(),
    );

    // Check if this printer already exists in the database
    final existingPrinters = await _dbHelper.getAllPrinterTypes();
    final existingPrinter = existingPrinters.firstWhere(
          (printer) => printer['address'] == device.address,
      orElse: () => <String, dynamic>{},
    );

    if (existingPrinter.isEmpty) {
      // Insert new printer
      await _dbHelper.insertPrinterType(updatedPrinter.toMap());
      _updateStatus("Printer ${device.name} saved to database");
    } else {
      // Update existing printer
      await _dbHelper.updatePrinterType(
        existingPrinter['id'],
        updatedPrinter.copyWith(id: existingPrinter['id']).toMap(),
      );
      _updateStatus("Printer ${device.name} updated in database");
    }

    if (setAsDefault) {
      await _dbHelper.setDefaultPrinter(existingPrinter.isEmpty ?
      await _getLastInsertedPrinterId() : existingPrinter['id']);
    }
  }

  Future<int> _getLastInsertedPrinterId() async {
    final allPrinters = await _dbHelper.getAllPrinterTypes();
    if (allPrinters.isEmpty) return -1;
    return allPrinters.reduce((a, b) => a['id'] > b['id'] ? a : b)['id'];
  }

  Future<void> _checkPermissions() async {
    if (Platform.isAndroid) {
      await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location
      ].request();
    }
  }

  Future<void> _checkBluetoothState() async {
    // Check using flutter_blue_plus instead
    if (!await fblue.FlutterBluePlus.isSupported) {
      throw Exception("Bluetooth not supported");
    }

    if (!await fblue.FlutterBluePlus.isOn) {
      _updateStatus("Bluetooth is off");
      if (Platform.isAndroid) {
        await fblue.FlutterBluePlus.turnOn();
      } else {
        throw Exception("Please enable Bluetooth manually");
      }
    }
  }

  Future<List<thermal.BluetoothDevice>> getBluetoothDevices() async {
    await _checkPermissions();
    await _checkBluetoothState();
    return await printer.getBondedDevices();
  }

  Future<List<thermal.BluetoothDevice>> getAllBluetoothDevices() async {
    await _checkPermissions();
    await _checkBluetoothState();

    final List<thermal.BluetoothDevice> allDevices = [];

    // Get paired devices
    final List<thermal.BluetoothDevice> paired = await printer.getBondedDevices();
    allDevices.addAll(paired);

    // Scan for unpaired devices
    final List<fblue.BluetoothDevice> foundDevices = [];

    // Start scanning
    await fblue.FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 5), // Increased timeout
      androidUsesFineLocation: true,
    );

    // Listen to scan results
    final subscription = fblue.FlutterBluePlus.onScanResults.listen((results) {
      for (final result in results) {
        if (!foundDevices.any((d) => d.remoteId == result.device.remoteId)) {
          foundDevices.add(result.device);
          print('Found device: ${result.device.platformName} - ${result.device.remoteId}');
        }
      }
    });

    // Wait for scan to complete
    await Future.delayed(const Duration(seconds: 15));
    await fblue.FlutterBluePlus.stopScan();
    await subscription.cancel();

    // Convert and merge unpaired devices
    for (final fbpDevice in foundDevices) {
      final address = _normalizeAddress(fbpDevice.remoteId.toString());
      final deviceName = fbpDevice.platformName ??
          fbpDevice.advName.replaceAll(RegExp(r'\s+'), ' ') ??
          'Unknown Device';

      // Check if device is already in paired list
      if (!allDevices.any((d) => _normalizeAddress(d.address.toString()) == address)) {
        allDevices.add(thermal.BluetoothDevice(deviceName.trim(), address));
        print('Added unpaired device: $deviceName - $address');
      }
    }

    return allDevices;
  }

  Future<bool> connectWithPin(thermal.BluetoothDevice device, String pin) async {
    try {
      // Note: blue_thermal_printer doesn't have direct PIN functionality
      // This is a conceptual implementation

      // For now, we'll provide a more pragmatic approach:
      // 1. Inform user to go to system settings
      // 2. Then try the normal connection once pairing is complete

      // Assuming the user has paired the device in system settings with the PIN
      // Now try to connect normally:
      return await connectToPrinter(device);
    } catch (e) {
      connectionNotifier.value = false;
      selectedDevice = null;
      rethrow;
    }
  }

  String _normalizeAddress(String address) {
    return address
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-f0-9]'), '') // Remove non-hex characters
        .padLeft(12, '0'); // Ensure 12-character MAC address
  }

  Future<bool> connectToPrinter(thermal.BluetoothDevice device) async {
    if (isConnected) await disconnectPrinter();

    try {
      await printer.connect(device);
      final connected = await printer.isConnected ?? false;

      if (connected) {
        selectedDevice = device;
        isConnected = true;
        _updateStatus("Connected to ${device.name}");

        // Save this printer to the database when successfully connected
        await savePrinterToDatabase(device);
      } else {
        _updateStatus("Failed to connect to ${device.name}");
      }
      connectionNotifier.value = connected;
      return connected;
    } catch (e) {
      _updateStatus("Connection error: $e");
      return false;
    }
  }

  Future<void> disconnectPrinter() async {
    try {
      await printer.disconnect();
      isConnected = false;
      selectedDevice = null;
      _updateStatus("Disconnected from printer");
      connectionNotifier.value = false;
    } catch (e) {
      _updateStatus("Error disconnecting: $e");
      rethrow;
    }
  }

  Future<void> refreshDevicesList() async {
    try {
      await _checkPermissions();
      await _checkBluetoothState();

      final List<thermal.BluetoothDevice> availableDevices = await getAllBluetoothDevices();
      devices = availableDevices;
      devicesNotifier.value = availableDevices;

      _updateStatus(devices.isEmpty
          ? "No devices found"
          : "Found ${devices.length} devices (${availableDevices.length - (await printer.getBondedDevices()).length} new)");
    } catch (e) {
      _updateStatus("Error refreshing devices: $e");
      devices = [];
      devicesNotifier.value = [];
    }
  }

  Future<bool> checkConnection() async {
    final bool connected = await printer.isConnected ?? false;
    isConnected = connected;
    connectionNotifier.value = connected;
    return connected;
  }

  void _setupBluetoothListener() {
    printer.onStateChanged().listen((state) async {
      if (state == thermal.BlueThermalPrinter.DISCONNECTED) {
        isConnected = false;
        connectionNotifier.value = false;
        _updateStatus("Printer Disconnected");

        await Future.delayed(const Duration(seconds: 3));
        if (selectedDevice != null) {
          await connectToPrinter(selectedDevice!);
        }
      }
    });
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

  Future<void> printTest() async {
    if (!isConnected) {
      _updateStatus("Printer not connected");
      return;
    }

    try {
      printer.printNewLine();
      printer.printCustom("Test Receipt", 3, 1);
      printer.printNewLine();
      printer.printCustom("Printer Working", 1, 1);
      printer.printNewLine();
      printer.printNewLine();
      _updateStatus("Test printed successfully");
    } catch (e) {
      _updateStatus("Print error: $e");
    }
  }

  void _updateStatus(String message) {
    statusMessage = message;
    statusNotifier.value = message;
  }

  void dispose() {
    connectionNotifier.dispose();
    statusNotifier.dispose();
    devicesNotifier.dispose();
  }
}