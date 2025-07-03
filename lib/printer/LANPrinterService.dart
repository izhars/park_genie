import 'dart:convert';
import 'dart:io';
import 'PrinterDatabaseHelper.dart';
import 'PrinterType.dart';

class LANPrinterService {
  static final LANPrinterService _instance = LANPrinterService._internal();
  factory LANPrinterService() => _instance;

  final PrinterDatabaseHelper _dbHelper = PrinterDatabaseHelper();

  Socket? _socket;
  String? _ip;
  int? _port;
  String? _printerName;

  LANPrinterService._internal();

  Future<bool> connectToPrinter(String ip, int port, [String? printerName]) async {
    try {
      // Close any existing connection first
      await disconnect();

      // Attempt to connect with timeout
      _socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 5));
      _ip = ip;
      _port = port;
      _printerName = printerName ?? "LAN Printer ($ip)";

      print("Connected to $_printerName at $_ip:$_port");
      return true;
    } catch (e) {
      print("LAN Printer connection error: $e");
      return false;
    }
  }

  Future<void> savePrinterToDatabase(String ip, int port, [String? printerName]) async {
    final name = printerName ?? "LAN Printer ($ip)";

    final printerType = PrinterType(
      name: name,
      address: "$ip:$port",
      deviceType: "lan",
      isDefault: false, // Don't automatically set as default
      isActive: true,
      lastConnected: DateTime.now(),
      connectionParams: {
        "ip": ip,
        "port": port,
      },
    );

    await _dbHelper.insertPrinterType(printerType.toMap());
  }

  Future<bool> printTest() async {
    if (_socket == null) return false;

    try {
      final List<int> bytes = [
        0x1B, 0x40, // Initialize printer
        0x1B, 0x21, 0x30, // Bold font mode
        ...utf8.encode("   LAN PRINTER TEST PAGE   \n\n"),
        0x1B, 0x21, 0x00, // Normal font mode
        ...utf8.encode("Printer: $_printerName\n"),
        ...utf8.encode("IP Address: $_ip\n"),
        ...utf8.encode("Port: $_port\n\n"),
        ...utf8.encode("Connection established successfully!\n"),
        ...utf8.encode("Current Date/Time: ${DateTime.now()}\n\n"),
        ...utf8.encode("----------------------------\n"),
        ...utf8.encode("     Print Test Successful     \n"),
        ...utf8.encode("----------------------------\n\n\n\n"),
        0x1D, 0x56, 0x41, 0x10 // Cut paper with feed
      ];

      _socket!.add(bytes);
      await _socket!.flush();
      return true;
    } catch (e) {
      print("Test print error: $e");
      return false;
    }
  }

  Future<bool> printText(String text) async {
    if (_socket == null) return false;

    try {
      final List<int> bytes = [
        0x1B, 0x40, // Initialize printer
        0x1B, 0x21, 0x00, // Normal font mode
        ...utf8.encode(text),
        ...utf8.encode("\n\n\n"), // Add some line feeds
        0x1D, 0x56, 0x41, 0x10 // Cut paper with feed
      ];

      _socket!.add(bytes);
      await _socket!.flush();
      return true;
    } catch (e) {
      print("Print text error: $e");
      return false;
    }
  }

  Future<bool> printReceipt({
    required String title,
    required String businessName,
    required List<Map<String, dynamic>> items,
    required double total,
    String? footer,
  }) async {
    if (_socket == null) return false;

    try {
      final now = DateTime.now();
      final dateStr = "${now.day}/${now.month}/${now.year}";
      final timeStr = "${now.hour}:${now.minute.toString().padLeft(2, '0')}";

      final List<int> bytes = [
        0x1B, 0x40, // Initialize printer
        0x1B, 0x61, 0x01, // Center alignment
        0x1B, 0x21, 0x30, // Bold, double height font
        ...utf8.encode("$businessName\n"),
        0x1B, 0x21, 0x00, // Normal font
        ...utf8.encode("$title\n"),
        ...utf8.encode("Date: $dateStr  Time: $timeStr\n"),
        0x1B, 0x61, 0x00, // Left alignment
        ...utf8.encode("--------------------------------\n"),
        0x1B, 0x21, 0x00, // Normal font
      ];

      // Add items
      for (var item in items) {
        final name = item['name'] as String;
        final qty = item['quantity'] as int;
        final price = item['price'] as double;
        final itemTotal = qty * price;

        // Format the item line with proper spacing
        final itemLine = "${name.padRight(20)} ${qty.toString().padLeft(2)} x ${price.toStringAsFixed(2).padLeft(6)} ${itemTotal.toStringAsFixed(2).padLeft(8)}\n";
        bytes.addAll(utf8.encode(itemLine));
      }

      bytes.addAll([
        ...utf8.encode("--------------------------------\n"),
        0x1B, 0x61, 0x02, // Right alignment
        0x1B, 0x21, 0x20, // Bold font
        ...utf8.encode("TOTAL: ${total.toStringAsFixed(2)}\n"),
        0x1B, 0x21, 0x00, // Normal font
        0x1B, 0x61, 0x01, // Center alignment
      ]);

      // Add footer if provided
      if (footer != null && footer.isNotEmpty) {
        bytes.addAll([
          ...utf8.encode("\n$footer\n"),
        ]);
      }

      // Add final spacing and cut
      bytes.addAll([
        ...utf8.encode("\n\n\n"),
        0x1D, 0x56, 0x41, 0x10 // Cut paper with feed
      ]);

      _socket!.add(bytes);
      await _socket!.flush();
      return true;
    } catch (e) {
      print("Print receipt error: $e");
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      await _socket?.close();
    } catch (e) {
      print("Error closing socket: $e");
    } finally {
      _socket = null;
      _ip = null;
      _port = null;
      _printerName = null;
    }
  }

  bool isConnected() => _socket != null;

  String? get connectedPrinterName => _printerName;
  String? get connectedPrinterIP => _ip;
  int? get connectedPrinterPort => _port;
}