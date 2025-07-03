import 'dart:async';
import 'dart:io';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/material.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:park_genie/printer/PrinterDatabaseHelper.dart';
import 'package:park_genie/printer/WifiPrinterService.dart';
import 'DatabaseHelper.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class BillEntryScreen extends StatefulWidget {
  const BillEntryScreen({super.key});

  @override
  _BillEntryScreenState createState() => _BillEntryScreenState();
}

class _BillEntryScreenState extends State<BillEntryScreen> with SingleTickerProviderStateMixin {
  final TextEditingController vehicleTypeController = TextEditingController();
  final TextEditingController vehicleNoController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final BlueThermalPrinter printer = BlueThermalPrinter.instance;
  bool isConnected = false;
  bool isLoading = false;
  bool _isLoading = true;
  bool _isPrinting = false;
  bool _useSpacesTracking = true; // Variable to store preference
  List<Map<String, dynamic>> vehicleTypeList = [];
  List<Map<String, dynamic>> _entryGates = [];
  int? _selectedEntryGateId;
  String selectedEntryGateName = '';
  String? selectedVehicleType;
  Map<String, int> _spacesInfo = {
    'totalSpaces': 0,
    'occupiedSpaces': 0,
    'availableSpaces': 0,
  };

  String billNumber = '';
  String entryTime = '';
  String vehicleType = '';
  String formattedVehicleNo = '';

  @override
  void initState() {
    super.initState();
    _checkPrinterConnection();
    _loadVehicleTypes();
    _loadSpacesInfo();
    _loadSpacesTrackingPreference();
    _loadGateInfo();

    // Add a periodic check if needed
    Timer.periodic(Duration(seconds: 30), (timer) {
      if (mounted) {
        _checkPrinterConnection();
      }
    });
  }

  Future<void> _loadSpacesInfo() async {
    setState(() => _isLoading = true);
    try {
      final spacesInfo = await DatabaseHelper.instance.getParkingSpaceInfo();
      setState(() {
        _spacesInfo = spacesInfo;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to load spaces information');
    }
  }

  Future<void> _loadSpacesTrackingPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _useSpacesTracking = prefs.getBool('useSpacesTracking') ?? true;
      print("wiehrwugdfw, $_useSpacesTracking");
    });
  }

  // final exitGates = await DatabaseHelper.instance.getGatesByType('exit');
  Future<void> _loadGateInfo() async {
    setState(() {
      _isLoading = true;
    });

    // Load gates based on their type
    final entryGates = await DatabaseHelper.instance.getGatesByType('entry');

    setState(() {
      _entryGates = entryGates;

      // Set defaults if not editing
      if (entryGates.isNotEmpty) {
        _selectedEntryGateId = entryGates.first['id'];  // Default to the first entry gate's id
        selectedEntryGateName = entryGates.first['name'];  // Store the name in the global variable
        print('Selected Entry Gate: $selectedEntryGateName');  // Print the name
      }

      _isLoading = false;
    });
  }

  Future<void> _loadVehicleTypes() async {
    List<Map<String, dynamic>> fetchedTypes = await DatabaseHelper.instance.getVehicleTypes();
    setState(() {
      vehicleTypeList = fetchedTypes;
    });
  }

  Future<void> _checkPrinterConnection() async {
    // Check Bluetooth printer connection
    bool? bluetoothConnected = await printer.isConnected;
    debugPrint("🖨️ Bluetooth printer connected: $bluetoothConnected");

    // Check WiFi printer connection
    bool wifiConnected = false;
    try {
      final connectedPrinter = await PrinterDatabaseHelper().getDefaultPrinterType();
      debugPrint("🖨️ Default printer: ${connectedPrinter != null ? connectedPrinter['deviceType'] : 'none'}");

      if (connectedPrinter != null && connectedPrinter['deviceType']?.toLowerCase() == 'wifi') {
        final WifiPrinterService printerService = WifiPrinterService();
        final String? ipAddress = printerService.connectedIpAddress;
        debugPrint("🖨️ WiFi printer IP: $ipAddress");
        debugPrint("🖨️ WiFi printer service reports connected: ${printerService.isConnected}");

        wifiConnected = ipAddress != null && ipAddress.isNotEmpty && printerService.isConnected;
        debugPrint("🖨️ WiFi printer connected status: $wifiConnected");
      }
    } catch (e) {
      debugPrint("🛑 Error checking WiFi printer connection: $e");
    }

    // Update connection status
    setState(() {
      isConnected = (bluetoothConnected ?? false) || wifiConnected;
      debugPrint("🖨️ Overall printer connection status: $isConnected");
    });
  }

  Future<void> fetchPriceForVehicleType(String vehicleType) async {
    print('Fetching price for vehicle type: $vehicleType');

    final price = await DatabaseHelper.instance.getPriceForVehicleType(vehicleType);

    if (price != null) {
      print('Price found: $price');
      setState(() {
        priceController.text = price;
      });
    } else {
      print('No price found for vehicle type: $vehicleType');
    }
  }


  String formatVehicleNumber(String vehicleNo) {
    RegExp regExp = RegExp(r'^([A-Z]{2})(\d{2})([A-Z]?)(\d{4})$');
    Match? match = regExp.firstMatch(vehicleNo);

    if (match != null) {
      String part1 = match.group(1)!; // State code (e.g., UP)
      String part2 = match.group(2)!; // District number (e.g., 55)
      String part3 = match.group(3)!; // Optional letter (e.g., Z or ZE)
      String part4 = match.group(4)!; // Vehicle number (e.g., 1748)

      return "$part1 $part2 ${part3.isNotEmpty ? "$part3 " : ""}$part4";
    }
    return vehicleNo; // Return original if format is incorrect
  }

  Future<void> saveEntry() async {
    // Validate all required fields
    if (selectedVehicleType == null && vehicleTypeController.text.isEmpty) {
      _showErrorSnackBar('Please select or enter a vehicle type');
      return;
    }

    if (vehicleNoController.text.isEmpty) {
      _showErrorSnackBar('Please enter vehicle number');
      return;
    }

    if (priceController.text.isEmpty) {
      _showErrorSnackBar('Please enter rate');
      return;
    }

    if (_selectedEntryGateId == null) {
      _showErrorSnackBar('Please select entry gate');
      return;
    }

    // Check printer connection
    if (!isConnected) {
      bool proceedWithoutPrinting = await _showPrinterNotConnectedDialog();
      if (!proceedWithoutPrinting) {
        return; // User chose not to proceed
      }
    }

    setState(() {
      isLoading = true;
    });

    try {
      // If space tracking is enabled, check for available spaces
      if (_useSpacesTracking) {
        if (_spacesInfo['availableSpaces'] != null &&
            _spacesInfo['availableSpaces']! <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No available parking spaces!'),
              backgroundColor: Colors.orange,
            ),
          );
          setState(() {
            isLoading = false;
          });
          return;
        }
      }

      billNumber = await DatabaseHelper.instance.generateBillNumber();
      entryTime = DateTime.now().toString();
      vehicleType = selectedVehicleType ?? vehicleTypeController.text;
      formattedVehicleNo = formatVehicleNumber(vehicleNoController.text.toUpperCase());

      Map<String, dynamic> entryData = {
        'billNumber': billNumber,
        'vehicleType': vehicleType,
        'vehicleNo': formattedVehicleNo,
        'entryTime': entryTime,
        'entryGateId': _selectedEntryGateId,
        'price': priceController.text,
        'entryGateName': selectedEntryGateName,
      };

      await DatabaseHelper.instance.insertEntry(entryData);

      // Increment occupied spaces only if space tracking is enabled
      if (_useSpacesTracking) {
        await DatabaseHelper.instance.incrementOccupiedSpaces();
      }

      // Only print if printer is connected
      if (isConnected) {
        _printBill();
      }

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 10),
              Text(
                  'Entry Saved! Bill No: ${billNumber.substring(billNumber.length - 6)}'),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );

      // Clear form
      setState(() {
        vehicleNoController.clear();
        selectedVehicleType = null;
        vehicleTypeController.clear();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

// Show dialog when printer is not connected
  Future<bool> _showPrinterNotConnectedDialog() async {
    // First check if either Bluetooth or WiFi printer is connected
    bool bluetoothConnected = isConnected;
    bool wifiConnected = false;

    // Check for a default WiFi printer in the database
    final connectedPrinter = await PrinterDatabaseHelper().getDefaultPrinterType();
    if (connectedPrinter != null && connectedPrinter['deviceType']?.toLowerCase() == 'wifi') {
      final WifiPrinterService printerService = WifiPrinterService();
      wifiConnected = printerService.isConnected;
    }

    // If either printer is connected, return true (no need for dialog)
    if (bluetoothConnected || wifiConnected) {
      return true;
    }

    // If no printer is connected, show the dialog
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.print_disabled, color: Colors.orange),
              SizedBox(width: 10),
              Text('Printer Not Connected'),
            ],
          ),
          content: const Text(
              'No thermal or WiFi printer is connected. You can proceed without printing, but no receipt will be generated. Do you want to proceed?'
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text('Proceed Without Printing', style: TextStyle(color: Color(0xFF4CAF50))),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        );
      },
    ) ?? false; // Default to false if dialog is dismissed
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _printBill() async {
    setState(() {
      _isPrinting = true;
    });

    try {
      // Get the default connected printer from database
      final connectedPrinter = await PrinterDatabaseHelper().getDefaultPrinterType();

      if (connectedPrinter == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("No default printer is set!"),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final String defaultPrinterType = connectedPrinter['deviceType'] ?? '';
      debugPrint("🖨️ Default printer type: $defaultPrinterType");

      // Check if the default printer is actually connected
      bool isDefaultPrinterConnected = false;
      bool isAlternatePrinterConnected = false;
      String alternatePrinterType = '';

      // Check both printer types and their connection status
      if (defaultPrinterType.toLowerCase() == 'thermal') {
        bool? bluetoothConnected = await printer.isConnected;
        isDefaultPrinterConnected = bluetoothConnected ?? false;

        // Check if WiFi printer is available as fallback
        final WifiPrinterService printerService = WifiPrinterService();
        isAlternatePrinterConnected = printerService.isConnected;
        alternatePrinterType = 'wifi';
      } else if (defaultPrinterType.toLowerCase() == 'wifi') {
        final WifiPrinterService printerService = WifiPrinterService();
        isDefaultPrinterConnected = printerService.isConnected;

        // Check if Bluetooth printer is available as fallback
        bool? bluetoothConnected = await printer.isConnected;
        isAlternatePrinterConnected = bluetoothConnected ?? false;
        alternatePrinterType = 'thermal';
      }

      // If default printer is connected, use it
      if (isDefaultPrinterConnected) {
        debugPrint("🖨️ Using default $defaultPrinterType printer");
        if (defaultPrinterType.toLowerCase() == 'thermal') {
          await _printReceipt(billNumber, entryTime, vehicleType, formattedVehicleNo, priceController.text);
        } else if (defaultPrinterType.toLowerCase() == 'wifi') {
          await _printToWifiPrinter(billNumber, entryTime, vehicleType, formattedVehicleNo, priceController.text);
        }
      }
      // If default printer is not connected but alternate printer is, use the alternate
      else if (isAlternatePrinterConnected) {
        debugPrint("🖨️ Default printer not connected. Falling back to $alternatePrinterType printer");

        // Show fallback notification
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Default printer not connected. Using $alternatePrinterType printer instead."),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );

        if (alternatePrinterType.toLowerCase() == 'thermal') {
          await _printReceipt(billNumber, entryTime, vehicleType, formattedVehicleNo, priceController.text);
        } else if (alternatePrinterType.toLowerCase() == 'wifi') {
          await _printToWifiPrinter(billNumber, entryTime, vehicleType, formattedVehicleNo, priceController.text);
        }
      }
      // If no printer is connected at all
      else {
        debugPrint("❌ No printer connected");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("No printer is connected! Please connect a printer to print receipts."),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Receipt printed successfully"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Handle errors
      debugPrint("🛑 Print Error: ${e.toString()}");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to print receipt: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      // Hide loading indicator
      setState(() {
        _isPrinting = false;
      });
    }
  }

  Future<void> _printReceipt(
      String billNumber,
      String entryTime,
      String vehicleType,
      String vehicleNo,
      String price,
      ) async {
    if (!isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 10),
              Text("Printer not connected!"),
            ],
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Fetch user/company info
      final user = await DatabaseHelper.instance.getUser();
      final companyName = user?['companyName'] ?? 'Your Company';
      final companyAddress = user?['address'] ?? 'Your Address';
      final logoPath = user?['logoPath'];
      final footerText = user?['footerText']?.toString().trim();

      // Parse and format entry time
      final parsedTime = DateTime.tryParse(entryTime) ?? DateTime.now();
      final formattedDate = DateFormat('dd MMM yyyy').format(parsedTime);
      final formattedTime = DateFormat('hh:mm a').format(parsedTime);

      // Determine which logo to use
      String imagePath;
      if (logoPath != null && File(logoPath).existsSync()) {
        final bytes = await File(logoPath).readAsBytes();
        final img.Image? originalImage = img.decodeImage(bytes);

        if (originalImage != null) {
          final resized = img.copyResize(originalImage, width: 60); // reduce more
          final bwImage = img.grayscale(resized);

          final whiteBg = img.Image(width: bwImage.width, height: bwImage.height);
          img.fill(whiteBg, color: img.ColorRgb8(255, 255, 255));
          img.compositeImage(whiteBg, bwImage);

          final tempDir = await getTemporaryDirectory();
          imagePath = '${tempDir.path}/custom_logo_print.jpg';
          File(imagePath)..writeAsBytesSync(img.encodeJpg(whiteBg, quality: 75)); // switch to JPG
        } else {
          imagePath = await _prepareDefaultLogo();
        }
      } else {
        imagePath = await _prepareDefaultLogo();
      }
      // 🔸 Begin Thermal Printing 🔸

      await printer.printImage(imagePath); // Logo
      await printer.printCustom(companyName, 1, 1);    // Centered, medium
      await printer.printCustom(companyAddress, 1, 1); // Centered, small
      await printer.printCustom("PARKING RECEIPT", 1, 1);

      await printer.printCustom("--------------------------------", 1, 1);
      await printer.printCustom("Bill No: #$billNumber", 1, 1);
      await printer.printCustom("--------------------------------", 1, 1);

      await printer.printLeftRight("Vehicle Type:", vehicleType, 1);
      await printer.printLeftRight("Vehicle No:", vehicleNo, 1);
      await printer.printLeftRight("Entry Date:", formattedDate, 1);
      await printer.printLeftRight("Entry Time:", formattedTime, 1);
      await printer.printLeftRight("Rate:", "Rs. $price/hr", 1);
      await printer.printLeftRight("Gate:", selectedEntryGateName ?? '-', 1);

      await printer.printQRcode(billNumber, 200, 200, 1);

      // Get footerText or use default
      final footerMessage = (footerText == null || footerText.isEmpty)
          ? "Thank you for your visit"  // Default fallback
          : footerText;

      // Print the footer
      await printer.printCustom(footerMessage, 1, 1);
      await printer.printCustom("Drive safe", 1, 1);
      await printer.printNewLine();
    } catch (e, stack) {
      debugPrint("🛑 Printing Error: $e\n$stack");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Printing error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

// Helper to load and process default logo
  Future<String> _prepareDefaultLogo() async {
    final ByteData data = await rootBundle.load('assets/icons/parking_logo.png');
    final Uint8List bytes = data.buffer.asUint8List();
    final img.Image? originalImage = img.decodeImage(bytes);

    if (originalImage == null) {
      throw Exception('Failed to decode default logo image');
    }

    final resized = img.copyResize(originalImage, width: 80);
    final bwImage = img.grayscale(resized);

    final whiteBg = img.Image(width: bwImage.width, height: bwImage.height);
    img.fill(whiteBg, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(whiteBg, bwImage);

    final tempDir = await getTemporaryDirectory();
    final imagePath = '${tempDir.path}/parking_logo.png';
    File(imagePath)..writeAsBytesSync(img.encodePng(whiteBg));

    return imagePath;
  }


  Future<void> _printToWifiPrinter(
      String billNumber,
      String entryTime,
      String vehicleType,
      String vehicleNo,
      String price,
      ) async {
    try {
      final WifiPrinterService printerService = WifiPrinterService();
      final String? ipAddress = printerService.connectedIpAddress;

      debugPrint("🖨️ Attempting to print to WiFi printer at IP: $ipAddress");

      if (ipAddress == null || ipAddress.isEmpty) {
        debugPrint("❌ WiFi printer IP address is null or empty");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("No WiFi printer connected"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (!printerService.isConnected) {
        debugPrint("❌ WiFi printer service reports not connected");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("WiFi printer not connected"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm58, profile);

      final user = await DatabaseHelper.instance.getUser();
      final companyName = user?['companyName'] ?? 'Your Company';
      final companyAddress = user?['address'] ?? 'Your Address';
      final logoPath = user?['logoPath'];
      final footerText = user?['footerText'];

      final parsedTime = DateTime.tryParse(entryTime) ?? DateTime.now();
      final formattedDate = DateFormat('dd MMM yyyy').format(parsedTime);
      final formattedTime = DateFormat('hh:mm a').format(parsedTime);

      List<int> bytes = [];

      try {
        String imagePath;
        if (logoPath != null && File(logoPath).existsSync()) {
          final bytesLogo = await File(logoPath).readAsBytes();
          final img.Image? originalImage = img.decodeImage(bytesLogo);

          if (originalImage != null) {
            final resized = img.copyResize(originalImage, width: 100);
            final bwImage = img.grayscale(resized);

            final whiteBg = img.Image(width: bwImage.width, height: bwImage.height);
            img.fill(whiteBg, color: img.ColorRgb8(255, 255, 255));
            img.compositeImage(whiteBg, bwImage);

            final tempDir = await getTemporaryDirectory();
            imagePath = '${tempDir.path}/custom_logo_wifi.png';
            File(imagePath).writeAsBytesSync(img.encodePng(whiteBg));
          } else {
            imagePath = await _prepareDefaultLogo();
          }
        } else {
          imagePath = await _prepareDefaultLogo();
        }

        final imageBytes = File(imagePath).readAsBytesSync();
        final img.Image? finalImage = img.decodeImage(imageBytes);
        if (finalImage != null) {
          bytes += generator.image(finalImage);
        }
      } catch (e) {
        debugPrint("⚠️ Logo image load failed: $e");
      }

      bytes += generator.setGlobalCodeTable('CP1252');
      bytes += generator.setStyles(const PosStyles(align: PosAlign.center));
      bytes += generator.text(companyName, styles: const PosStyles(bold: true));
      bytes += generator.text(companyAddress);
      bytes += generator.text("PARKING RECEIPT");
      bytes += generator.hr();
      bytes += generator.text("Bill No: #$billNumber");
      bytes += generator.hr();

      bytes += generator.row([
        PosColumn(text: 'Vehicle Type:', width: 6, styles: const PosStyles(align: PosAlign.left)),
        PosColumn(text: vehicleType, width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);

      bytes += generator.row([
        PosColumn(text: 'Vehicle No:', width: 6, styles: const PosStyles(align: PosAlign.left)),
        PosColumn(text: vehicleNo, width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);

      bytes += generator.row([
        PosColumn(text: 'Entry Date:', width: 6, styles: const PosStyles(align: PosAlign.left)),
        PosColumn(text: formattedDate, width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);

      bytes += generator.row([
        PosColumn(text: 'Entry Time:', width: 6, styles: const PosStyles(align: PosAlign.left)),
        PosColumn(text: formattedTime, width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);

      bytes += generator.row([
        PosColumn(text: 'Rate:', width: 6, styles: const PosStyles(align: PosAlign.left)),
        PosColumn(text: "Rs. $price/hr", width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);

      bytes += generator.row([
        PosColumn(text: 'Gate:', width: 6, styles: const PosStyles(align: PosAlign.left)),
        PosColumn(text: selectedEntryGateName ?? '-', width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);

      bytes += generator.feed(1);
      bytes += generator.qrcode(billNumber, size: QRSize.size4);
      bytes += generator.feed(1);

      //foter
      if (footerText != null && footerText.isNotEmpty) {
        debugPrint("📝 Footer Text: $footerText");
        bytes += generator.setGlobalCodeTable('CP437'); // use safer code page
        bytes += generator.text(footerText);
      } else {
        bytes += generator.text("Thank you for your visit!");
      }
      bytes += generator.text("Drive safe");
      bytes += generator.cut(mode: PosCutMode.partial);

      debugPrint("🖨️ Creating socket connection to $ipAddress:9100");

      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          final socket = await Socket.connect(ipAddress, 9100, timeout: const Duration(seconds: 5));
          debugPrint("🖨️ Socket connected (Attempt $attempt)");

          socket.add(bytes);
          await socket.flush();
          await socket.close();

          debugPrint("✅ Print job sent successfully");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Printed successfully"),
              backgroundColor: Colors.green,
            ),
          );
          return;
        } catch (e) {
          debugPrint("⚠️ Attempt $attempt failed: $e");
          if (attempt == 3) rethrow;
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    } on SocketException catch (e) {
      debugPrint("📡 SocketException: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Connection to printer failed"),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint("🛑 WiFi Print Error: $e");
      debugPrint("🛑 Stack trace: $stackTrace");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("WiFi Print Error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<bool> _validateSubscription(BuildContext context) async {
    try {
      final dbHelper = DatabaseHelper.instance;
      final userData = await dbHelper.retrieveUserData();

      if (userData.isEmpty || userData.first == null) {
        _showError(context, "No user data found.");
        return false;
      }

      final packageData = userData.first;

      // Subscription field checks
      if (packageData.packageValidTill == null ||
          packageData.packageValidTill.toString().isEmpty ||
          packageData.duration == null ||
          packageData.duration.toString().isEmpty ||
          packageData.durationInDays == null ||
          packageData.maxEntriesPerDay == null) {
        _showError(context, "No subscription package found. Please purchase one to print receipts.");
        return false;
      }

      if (packageData.isActive != true) {
        print("avsghdvaydva, ${packageData.isActive}");
        _showError(context, "Your subscription is inactive. Please renew to print receipts.");
        return false;
      }

      final validTill = DateTime.tryParse(packageData.packageValidTill);
      if (validTill == null || validTill.isBefore(DateTime.now())) {
        _showError(context, "Your subscription has expired. Please renew to print receipts.");
        return false;
      }
      //
      // if (packageData.maxEntriesPerDay <= 0) {
      //   _showError(context, "Invalid subscription limit. Please contact support.");
      //   return false;
      // }

      // Step 1: Check today's entry count from the server
      // final todayEntryCount = await getTodayEntryCountFromServer();
      // if (todayEntryCount >= packageData.maxEntriesPerDay) {
      //   _showError(context, "You’ve reached today’s entry limit (${packageData.maxEntriesPerDay}). Try again tomorrow.");
      //   return false;
      // }

      // Step 2: Optionally, you could still keep local count here, but server will be authoritative
      // final todayEntryCountLocal = await dbHelper.getTodayEntryCount();
      // if (todayEntryCountLocal >= packageData.maxEntriesPerDay) {
      //   _showError(context, "You’ve reached today’s entry limit. Try again tomorrow.");
      //   return false;
      // }

      return true;
    } catch (e) {
      debugPrint("🛑 Subscription Validation Error: ${e.toString()}");
      _showError(context, "Error validating subscription: ${e.toString()}");
      return false;
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Modern Header Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green[100]!, Colors.green[100]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4CAF50).withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.directions_car_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 20),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Vehicle Entry",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Register new vehicle and print entry ticket",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Enhanced Printer Status Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isConnected ? const Color(0xFF4CAF50) : const Color(0xFFFFA726),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isConnected
                            ? const Color(0xFF4CAF50).withOpacity(0.1)
                            : const Color(0xFFFFA726).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isConnected ? Icons.print_rounded : Icons.print_disabled_rounded,
                        color: isConnected ? const Color(0xFF4CAF50) : const Color(0xFFFFA726),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isConnected ? "Printer Ready" : "Printer Not Connected",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isConnected ? const Color(0xFF4CAF50) : const Color(0xFFFFA726),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isConnected ? "Ready to print tickets" : "Please check connection",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isConnected)
                      Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Color(0xFF4CAF50),
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Form Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Vehicle Information",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A202C),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Vehicle Type Dropdown
                    _buildLabel("Vehicle Type"),
                    const SizedBox(height: 8),
                    _buildEnhancedDropdown(),

                    const SizedBox(height: 8),
                    Visibility(
                      visible: selectedVehicleType == 'Other',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          _buildLabel("Specify Vehicle Type"),
                          const SizedBox(height: 8),
                          _buildEnhancedTextField(
                            controller: vehicleTypeController,
                            hint: "Enter Vehicle Type",
                            icon: Icons.edit_rounded,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Vehicle Number
                    _buildLabel("Vehicle Number"),
                    const SizedBox(height: 8),
                    _buildEnhancedTextField(
                      controller: vehicleNoController,
                      hint: "Enter Vehicle Registration Number",
                      icon: Icons.car_rental_rounded,
                      textCapitalization: TextCapitalization.characters,
                      showCamera: true,
                      context: context,
                    ),

                    const SizedBox(height: 24),

                    // Price
                    _buildLabel("Rate (Per Hour)"),
                    const SizedBox(height: 8),
                    _buildEnhancedTextField(
                      controller: priceController,
                      hint: "Enter Rate",
                      icon: Icons.currency_rupee_rounded,
                      keyboardType: TextInputType.number,
                      prefix: "₹ ",
                    ),

                    const SizedBox(height: 24),

                    // Entry Gate Selection
                    _buildLabel("Entry Gate"),
                    const SizedBox(height: 8),
                    _buildEnhancedGateDropdown(),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Enhanced Submit Button
              Container(
                width: double.infinity,
                height: 60,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4CAF50), Color(0xFF45A049)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4CAF50).withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: isLoading
                      ? null
                      : () async {
                    final isValid = await _validateSubscription(context);
                    if (isValid) {
                      saveEntry();
                    }
                  },
                  icon: isLoading
                      ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                      : const Icon(Icons.local_parking_rounded, size: 24),
                  label: Text(
                    isLoading ? "Processing..." : "Register & Print Ticket",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Color(0xFF374151),
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildEnhancedDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          value: selectedVehicleType,
          decoration: const InputDecoration(
            hintText: "Select Vehicle Type",
            hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
            prefixIcon: Icon(Icons.commute_rounded, color: Color(0xFF6B7280)),
            contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            border: InputBorder.none,
          ),
          items: vehicleTypeList.map((Map<String, dynamic> typeData) {
            return DropdownMenuItem<String>(
              value: typeData['type'],
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getVehicleIcon(typeData['type']),
                      color: const Color(0xFF4CAF50),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    typeData['type'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF374151),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              selectedVehicleType = newValue;
              if (newValue != null && newValue != 'Other') {
                fetchPriceForVehicleType(newValue);
              } else if (newValue == 'Other') {
                priceController.text = '30';
              }
            });
          },
        ),
      ),
    );
  }

  Widget _buildEnhancedGateDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<int>(
          value: _selectedEntryGateId,
          decoration: const InputDecoration(
            hintText: "Select Entry Gate",
            hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
            prefixIcon: Icon(Icons.door_front_door_rounded, color: Color(0xFF6B7280)),
            contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            border: InputBorder.none,
          ),
          items: _entryGates.map((Map<String, dynamic> gate) {
            return DropdownMenuItem<int>(
              value: gate['id'],
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      gate['type'] == 'both' ? Icons.swap_horiz_rounded : Icons.arrow_circle_right_rounded,
                      color: const Color(0xFF3B82F6),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    gate['name'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF374151),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (int? newValue) {
            setState(() {
              _selectedEntryGateId = newValue;
            });
          },
        ),
      ),
    );
  }

  Widget _buildEnhancedTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? prefix,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool showCamera = false,
    BuildContext? context,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Color(0xFF374151),
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
          prefixIcon: Icon(icon, color: const Color(0xFF6B7280)),
          prefixText: prefix,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          suffixIcon: showCamera && context != null
              ? Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.camera_alt_rounded, color: Color(0xFF4CAF50)),
              onPressed: () => _openCameraBottomSheet(context, controller),
            ),
          )
              : null,
        ),
      ),
    );
  }

  void _openCameraBottomSheet(BuildContext context, TextEditingController controller) async {
    final cameras = await availableCameras();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: CameraBottomSheet(
            cameras: cameras,
            onTextRecognized: (text) {
              controller.text = text; // Update text field with recognized text
              Navigator.pop(context);
            },
          ),
        );
      },
    );
  }

  IconData _getVehicleIcon(String vehicleType) {
    switch (vehicleType.toLowerCase()) {
      case 'car':
        return Icons.directions_car;
      case 'bike':
        return Icons.two_wheeler;
      case 'bus':
        return Icons.directions_bus;
      case 'truck':
        return Icons.local_shipping;
      case 'cycle':
        return Icons.pedal_bike;
      case 'auto':
      case 'rickshaw':
        return Icons.electric_rickshaw;
      case 'other':
        return Icons.commute;
      default:
        return Icons.directions_car;
    }
  }
}

class CameraBottomSheet extends StatefulWidget {
  final List<CameraDescription> cameras;
  final Function(String) onTextRecognized;

  const CameraBottomSheet({super.key, required this.cameras, required this.onTextRecognized});

  @override
  _CameraBottomSheetState createState() => _CameraBottomSheetState();
}

class _CameraBottomSheetState extends State<CameraBottomSheet> {
  CameraController? _cameraController;
  bool _isProcessing = false;
  bool _flashOn = false;
  double _zoomLevel = 1.0;
  final double _minZoom = 1.0;
  final double _maxZoom = 5.0;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameraController = CameraController(
        widget.cameras[0],
        ResolutionPreset.high,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      print('Camera initialization error: $e');
    }
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    try {
      final newFlashMode = _flashOn ? FlashMode.off : FlashMode.torch;
      await _cameraController!.setFlashMode(newFlashMode);
      setState(() => _flashOn = !_flashOn);
    } catch (e) {
      print('Error toggling flash: $e');
    }
  }

  Future<void> _setZoomLevel(double zoom) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    try {
      await _cameraController!.setZoomLevel(zoom);
      setState(() => _zoomLevel = zoom);
    } catch (e) {
      print('Error setting zoom: $e');
    }
  }

  Future<void> _captureAndRecognizeText() async {
    if (_isProcessing || _cameraController == null || !_cameraController!.value.isInitialized) return;

    setState(() => _isProcessing = true);

    try {
      // Visual feedback when capturing
      HapticFeedback.mediumImpact();

      final XFile imageFile = await _cameraController!.takePicture();
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final textRecognizer = TextRecognizer();

      // Show scanning animation
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 16),
              Text('Processing text...'),
            ],
          ),
          duration: Duration(seconds: 1),
          backgroundColor: Color(0xFF4CAF50),
        ),
      );

      final RecognizedText recognized = await textRecognizer.processImage(inputImage);
      textRecognizer.close();

      // Process the recognized text to find a vehicle number pattern
      String processedText = _extractVehicleNumber(recognized.text);

      widget.onTextRecognized(processedText);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to process image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  String _extractVehicleNumber(String text) {
    // Simple vehicle number extraction - could be enhanced with regex
    // This looks for standard formats like AB12CD3456
    final lines = text.split('\n');
    for (String line in lines) {
      // Remove spaces and make uppercase
      String processed = line.replaceAll(' ', '').toUpperCase();

      // Look for patterns that resemble vehicle registration numbers
      // This is a simple check - could be enhanced for specific regional formats
      if (processed.length >= 8 && processed.length <= 12 &&
          RegExp(r'[A-Z]{2}\d{1,2}[A-Z]{1,3}\d{1,4}').hasMatch(processed)) {
        return processed;
      }
    }
    // If no pattern found, return the original text trimmed
    return text.trim();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Column(
        children: [
          // Header bar
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: const BoxDecoration(
              color: Color(0xFF222222),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Scan Vehicle Number',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Camera preview
          if (_cameraController != null && _cameraController!.value.isInitialized)
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Camera preview
                  CameraPreview(_cameraController!),

                  // Overlay with targeting frame
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                    ),
                    child: Center(
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.8,
                        height: 100,
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFF4CAF50), width: 2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Align vehicle number in this area',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Processing indicator
                  if (_isProcessing)
                    Container(
                      color: Colors.black54,
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              color: Color(0xFF4CAF50),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Reading text...',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            )
          else
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF4CAF50),
                ),
              ),
            ),

          // Camera controls
          Container(
            color: const Color(0xFF222222),
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              children: [
                // Zoom slider
                Row(
                  children: [
                    const Icon(Icons.zoom_out, color: Colors.white70, size: 20),
                    Expanded(
                      child: Slider(
                        value: _zoomLevel,
                        min: _minZoom,
                        max: _maxZoom,
                        activeColor: const Color(0xFF4CAF50),
                        inactiveColor: Colors.white24,
                        onChanged: (value) => _setZoomLevel(value),
                      ),
                    ),
                    const Icon(Icons.zoom_in, color: Colors.white70, size: 20),
                  ],
                ),

                const SizedBox(height: 16),

                // Bottom controls row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Flash toggle
                    IconButton(
                      icon: Icon(
                        _flashOn ? Icons.flash_on : Icons.flash_off,
                        color: _flashOn ? const Color(0xFF4CAF50) : Colors.white70,
                        size: 28,
                      ),
                      onPressed: _toggleFlash,
                    ),

                    // Capture button
                    GestureDetector(
                      onTap: _captureAndRecognizeText,
                      child: Container(
                        height: 70,
                        width: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF4CAF50), width: 3),
                          color: Colors.transparent,
                        ),
                        child: Center(
                          child: Container(
                            height: 56,
                            width: 56,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF4CAF50),
                            ),
                            child: _isProcessing
                                ? const CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              strokeWidth: 2,
                            )
                                : const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Switch camera (assuming there's a rear and front camera)
                    IconButton(
                      icon: const Icon(
                        Icons.flip_camera_ios,
                        color: Colors.white70,
                        size: 28,
                      ),
                      onPressed: widget.cameras.length > 1 ? () async {
                        final cameraIndex = widget.cameras.indexOf(_cameraController!.description);
                        final nextCameraIndex = (cameraIndex + 1) % widget.cameras.length;

                        await _cameraController?.dispose();

                        _cameraController = CameraController(
                          widget.cameras[nextCameraIndex],
                          ResolutionPreset.high,
                          enableAudio: false,
                        );

                        await _cameraController!.initialize();
                        if (mounted) setState(() {});
                      } : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}