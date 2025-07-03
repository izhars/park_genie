import 'dart:io';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/material.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:park_genie/printer/PrinterDatabaseHelper.dart';
import 'package:park_genie/printer/WifiPrinterService.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'DatabaseHelper.dart';

class BillExitScreen extends StatefulWidget {
  const BillExitScreen({super.key});

  @override
  _BillExitScreenState createState() => _BillExitScreenState();
}

class _BillExitScreenState extends State<BillExitScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final TextEditingController billNoController = TextEditingController();
  final BlueThermalPrinter printer = BlueThermalPrinter.instance;
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  List<Map<String, dynamic>> _exitGates = [];
  int? _selectedExitGateId;
  QRViewController? qrController;
  Map<String, dynamic>? billData;
  bool _useSpacesTracking = true; // Variable to store preference
  bool isLoading = false;
  bool _isLoading = true;
  bool isConnected = false;
  bool isBillFound = true;
  bool isScanning = false;
  bool isFlashOn = false;
  bool isAlreadyPaid = false; // New variable to track if bill is already paid
  String selectedExitGateName = '';
  int selectedExitGateId = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
    _checkPrinterConnection();
    _loadSpacesTrackingPreference(); // Load preference
    _loadGateInfo();
  }

  Future<void> _loadSpacesTrackingPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _useSpacesTracking = prefs.getBool('useSpacesTracking') ?? true;
    });
  }

  @override
  void reassemble() {
    super.reassemble();
    if (isScanning && qrController != null) {
      qrController!.pauseCamera();
      qrController!.resumeCamera();
    }
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

  final dbHelper = DatabaseHelper.instance;

  Future<void> fetchBill() async {
    if (billNoController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a bill number")),
      );
      return;
    }

    setState(() {
      isLoading = true;
      billData = null;
      isBillFound = true;
      isAlreadyPaid = false; // Reset paid status
    });

    try {
      String billNumber = billNoController.text;
      Map<String, dynamic>? entry = await dbHelper.getEntryByBill(billNumber);

      if (entry != null) {
        // ✅ Hide keyboard when a valid bill is found
        FocusScope.of(context).unfocus();

        // Check if bill is already paid
        if (entry['isPaid'] == 1) {
          setState(() {
            isAlreadyPaid = true;
            billData = entry; // Still store the data to display details
          });
        } else {
          DateTime entryTime = DateTime.parse(entry['entryTime']);
          DateTime exitTime = DateTime.now();

          int hoursSpent = exitTime.difference(entryTime).inHours;
          double totalPrice = double.parse(entry['price']) * (hoursSpent > 0 ? hoursSpent : 1);

          setState(() {
            billData = {
              ...entry,
              'exitTime': exitTime.toString(),
              'hoursSpent': hoursSpent,
              'totalPrice': totalPrice,
            };
          });
        }

        // Animate
        _animationController.reset();
        _animationController.forward();
      } else {
        setState(() {
          isBillFound = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching bill: $e")),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }


  Future<void> _loadGateInfo() async {
    setState(() {
      _isLoading = true;
    });

    // Load gates based on their type
    final exitGates = await DatabaseHelper.instance.getGatesByType('exit');

    setState(() {
      _exitGates = exitGates;
      if (exitGates.isNotEmpty) selectedExitGateId = exitGates.first['id'];

      if (exitGates.isNotEmpty) {
        _selectedExitGateId = exitGates.first['id'];  // Default to the first exit gate's id
        selectedExitGateName = exitGates.first['name'];  // Store the name in the global variable
        print('Selected Exit Gate: $selectedExitGateName');  // Print the name
      }

      _isLoading = false;
    });
  }

  // Modified _printBill method to support WiFi printing
  Future<void> _printBill() async {
    if (billData == null) return;

    // Check if bill is already paid
    if (isAlreadyPaid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("This bill has already been paid!"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Get the default connected printer from database
    final connectedPrinter = await PrinterDatabaseHelper().getDefaultPrinterType();

    if (connectedPrinter == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No printer is connected or set as default!"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final String defaultPrinterType = connectedPrinter['deviceType'] ?? '';

    // Check all available printer connections
    bool thermalConnected = await printer.isConnected ?? false;
    bool wifiConnected = false;

    try {
      final WifiPrinterService printerService = WifiPrinterService();
      wifiConnected = printerService.isConnected;
    } catch (e) {
      debugPrint("Error checking WiFi printer: $e");
    }

    // Try default printer first
    if (defaultPrinterType.toLowerCase() == 'thermal') {
      if (thermalConnected) {
        await _printToThermalPrinter();
        return;
      } else if (wifiConnected) {
        // Fallback to WiFi printer
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Thermal printer not connected. Using WiFi printer instead."),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
        await _printToWifiPrinter();
        return;
      }
    } else if (defaultPrinterType.toLowerCase() == 'wifi') {
      if (wifiConnected) {
        await _printToWifiPrinter();
        return;
      } else if (thermalConnected) {
        // Fallback to thermal printer
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("WiFi printer not connected. Using thermal printer instead."),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
        await _printToThermalPrinter();
        return;
      }
    }

    // If we get here, neither default nor fallback printer is available
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("No printer connected! Please connect a printer to print receipts."),
        backgroundColor: Colors.red,
      ),
    );
  }

// Extracted thermal printing logic from original _printBill
  Future<void> _printToThermalPrinter() async {
    try {
      // Receipt header
      Map<String, dynamic>? user = await DatabaseHelper.instance.getUser();
      String companyName = user?['companyName'] ?? 'Your Company';
      String companyAddress = user?['address'] ?? 'Your Address';
      String footerText = user?['footerText'];

      // Load and resize the logo (smaller size to save paper)
      final ByteData data = await rootBundle.load('assets/icons/parking_logo.png');
      final Uint8List bytes = data.buffer.asUint8List();
      img.Image? originalImage = img.decodeImage(bytes);
      if (originalImage == null) {
        print('Failed to decode image');
        return;
      }

      // Smaller logo - only 80px width to save space
      int targetWidth = 80;
      img.Image resizedImage = img.copyResize(originalImage, width: targetWidth);

      // Convert to proper 1-bit black and white format
      img.Image bwImage = img.grayscale(resizedImage);

      // Create a white background image
      img.Image whiteBackground = img.Image(
        width: bwImage.width,
        height: bwImage.height,
      );

      // Fill with white
      img.fill(whiteBackground, color: img.ColorRgb8(255, 255, 255));

      // Draw the black and white image on the white background
      img.compositeImage(whiteBackground, bwImage);

      // Save to file
      final Directory tempDir = await getTemporaryDirectory();
      final File imageFile = File('${tempDir.path}/parking_logo.png');
      await imageFile.writeAsBytes(img.encodePng(whiteBackground));

      // Begin printing - compact layout
      await printer.printImage(imageFile.path);

      // Print header on same line when possible
      await printer.printCustom(companyName, 1, 1); // Medium font, centered
      await printer.printCustom(companyAddress, 1, 1); // Small font, centered

      // Print receipt title with minimal separator
      await printer.printCustom("PARKING RECEIPT", 1, 1);
      await printer.printCustom("--------------------------------", 1, 1);

      // Print ticket number (most important info)
      await printer.printCustom("Bill No: #${billData!['billNumber'].toString()}", 1, 1);

      // Divider line
      await printer.printCustom("--------------------------------", 1, 1);

      // Bill and Vehicle info
      await printer.printLeftRight("Vehicle No:", billData!['vehicleNo'], 1);

      // Entry time
      DateTime entryTime = DateTime.parse(billData!['entryTime']);
      String entryDate = DateFormat('MMM dd, yyyy').format(entryTime);
      String entryTimeStr = DateFormat('hh:mm a').format(entryTime);
      await printer.printLeftRight("Entry Date:", entryDate, 1);
      await printer.printLeftRight("Entry Time:", entryTimeStr, 1);

      // Exit time
      DateTime exitTime = DateTime.parse(billData!['exitTime']);
      String exitDate = DateFormat('MMM dd, yyyy').format(exitTime);
      String exitTimeStr = DateFormat('hh:mm a').format(exitTime);
      Duration duration = exitTime.difference(entryTime);
      String durationText;
      if (duration.inHours >= 1) {
        int hours = duration.inHours;
        int minutes = duration.inMinutes % 60;
        if (minutes > 0) {
          durationText = '$hours hr ${minutes.toString().padLeft(2, '0')} min';
        } else {
          durationText = '$hours hr';
        }
      } else {
        durationText = '${duration.inMinutes} min';
      }
      await printer.printLeftRight("Exit Date:", exitDate, 1);
      await printer.printLeftRight("Exit Time:", exitTimeStr, 1);

      // Duration and Gate info
      await printer.printLeftRight("Duration:", durationText.toUpperCase(), 1);
      await printer.printLeftRight("Gate No:", selectedExitGateName, 1);

      // Divider before total
      await printer.printCustom("--------------------------------", 1, 1);

      // Total amount
      await printer.printCustom("TOTAL AMOUNT", 2, 1);
      final totalPrice = billData!['totalPrice'];
      await printer.printCustom("Rs. ${totalPrice.toStringAsFixed(2)}", 2, 1);

      // Divider after total
      await printer.printCustom("--------------------------------", 1, 1);

      // Get footerText or use default
      final footerMessage = (footerText == null || footerText.isEmpty)
          ? "Thank you for your visit"  // Default fallback
          : footerText;

      // Print the footer
      await printer.printCustom(footerMessage, 1, 1);
      await printer.printCustom("Drive safe", 1, 1);
      await printer.printNewLine();
      await printer.printNewLine();

      // Update database and show success message
      await _updatePaymentStatusInDatabase();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Receipt printed successfully!"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error printing receipt: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

// WiFi printing implementation
  Future<void> _printToWifiPrinter() async {
    try {
      final WifiPrinterService printerService = WifiPrinterService();
      final String? ipAddress = printerService.connectedIpAddress;

      // Debug log the IP address to verify it's not null
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

      // Verify connection before proceeding
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

      // Fetch user/company info
      final user = await DatabaseHelper.instance.getUser();
      final companyName = user?['companyName'] ?? 'Your Company';
      final companyAddress = user?['address'] ?? 'Your Address';
      final footerText = user?['footerText']?.toString().trim();

      // Create the byte array for ESC/POS commands
      List<int> bytes = [];

      final logoPath = user?['logoPath'];

      try {
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
            final String imagePath = '${tempDir.path}/custom_logo_wifi.png';
            File(imagePath).writeAsBytesSync(img.encodePng(whiteBg));

            final finalImageBytes = File(imagePath).readAsBytesSync();
            final img.Image? finalImage = img.decodeImage(finalImageBytes);

            if (finalImage != null) {
              bytes += generator.image(finalImage);
              bytes += generator.feed(1);
            }
          }
        }
      } catch (e) {
        debugPrint("⚠️ Failed to load logo: $e");
      }

      // Generate ESC/POS commands
      bytes += generator.setGlobalCodeTable('CP1252');
      bytes += generator.setStyles(const PosStyles(align: PosAlign.center));
      bytes += generator.text(companyName);
      bytes += generator.text(companyAddress);
      bytes += generator.text("PARKING RECEIPT");
      bytes += generator.hr();
      bytes += generator.text("Bill No: #${billData!['billNumber'].toString()}");
      bytes += generator.hr();

      // Vehicle info
      bytes += generator.row([
        PosColumn(text: 'Vehicle No:', width: 6, styles: const PosStyles(align: PosAlign.left)),
        PosColumn(text: billData!['vehicleNo'], width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);

      // Entry time info
      DateTime entryTime = DateTime.parse(billData!['entryTime']);
      String entryDate = DateFormat('MMM dd, yyyy').format(entryTime);
      String entryTimeStr = DateFormat('hh:mm a').format(entryTime);
      // Entry Date & Time
      bytes += generator.row([
        PosColumn(text: 'Entry Date:', width: 6, styles: const PosStyles(align: PosAlign.left)),
        PosColumn(text: entryDate, width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);
      bytes += generator.row([
        PosColumn(text: 'Entry Time:', width: 6, styles: const PosStyles(align: PosAlign.left)),
        PosColumn(text: entryTimeStr, width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);

      // Exit time info
      DateTime exitTime = DateTime.parse(billData!['exitTime']);
      String exitDate = DateFormat('MMM dd, yyyy').format(exitTime);
      String exitTimeStr = DateFormat('hh:mm a').format(exitTime);
      // Exit Date & Time
      bytes += generator.row([
        PosColumn(text: 'Exit Date:', width: 6, styles: const PosStyles(align: PosAlign.left)),
        PosColumn(text: exitDate, width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);
      bytes += generator.row([
        PosColumn(text: 'Exit Time:', width: 6, styles: const PosStyles(align: PosAlign.left)),
        PosColumn(text: exitTimeStr, width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);

      // Duration calculation
      Duration duration = exitTime.difference(entryTime);
      String durationText;
      if (duration.inHours >= 1) {
        int hours = duration.inHours;
        int minutes = duration.inMinutes % 60;
        if (minutes > 0) {
          durationText = '$hours hr ${minutes.toString().padLeft(2, '0')} min';
        } else {
          durationText = '$hours hr';
        }
      } else {
        durationText = '${duration.inMinutes} min';
      }

      // Duration & Gate
      bytes += generator.row([
        PosColumn(text: 'Duration:', width: 6, styles: const PosStyles(align: PosAlign.left)),
        PosColumn(text: durationText.toUpperCase(), width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);
      bytes += generator.row([
        PosColumn(text: 'Gate No:', width: 6, styles: const PosStyles(align: PosAlign.left)),
        PosColumn(text: selectedExitGateName, width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);

      // Total amount
      bytes += generator.hr();
      bytes += generator.setStyles(const PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ));
      bytes += generator.text("TOTAL AMOUNT");
      final totalPrice = billData!['totalPrice'];
      bytes += generator.text("Rs. ${totalPrice.toStringAsFixed(2)}");
      bytes += generator.hr();

      if (footerText != null && footerText.isNotEmpty) {
        debugPrint("📝 Footer Text: $footerText");
        bytes += generator.setGlobalCodeTable('CP437'); // use safer code page
        bytes += generator.text(footerText);
      } else {
        bytes += generator.text("Thank you for your visit!");
      }
      bytes += generator.text("Drive safe");
      // Use partial cut instead of full cut (optional)
      bytes += generator.cut(mode: PosCutMode.partial);

      // Create socket connection and send print data
      debugPrint("🖨️ Creating socket connection to $ipAddress:9100");
      final socket = await Socket.connect(ipAddress, 9100, timeout: const Duration(seconds: 5));
      debugPrint("🖨️ Socket connected successfully");

      debugPrint("🖨️ Sending ${bytes.length} bytes to printer");
      socket.add(bytes);

      debugPrint("🖨️ Flushing socket");
      await socket.flush();

      debugPrint("🖨️ Closing socket");
      await socket.close();

      // Update database after successful printing
      await _updatePaymentStatusInDatabase();

      debugPrint("✅ Print job completed successfully");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Printed successfully"),
          backgroundColor: Colors.green,
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

// Helper method to update database
  Future<void> _updatePaymentStatusInDatabase() async {
    try {
      if (billData != null && billData!['billNumber'] != null) {
        int updatedRows = await DatabaseHelper.instance.updateExitInfo(
          billData!['billNumber'],
          exitGateId: selectedExitGateId, // Optional: pass exitGateId if available
        );

        if (updatedRows > 0) {
          print("✅ Bill ${billData!['billNumber']} marked as paid successfully.");

          setState(() {
            isAlreadyPaid = true;
          });

          if (_useSpacesTracking) {
            await DatabaseHelper.instance.decrementOccupiedSpaces();
            print("✅ Occupied spaces decremented.");
          }
        } else {
          print("⚠️ Failed to mark bill ${billData!['billNumber']} as paid.");
        }
      } else {
        print("❌ Invalid bill data.");
      }
    } catch (e) {
      print("❌ Error updating payment status: $e");
    }
  }


  void _onQRViewCreated(QRViewController controller) {
    setState(() {
      qrController = controller;
    });

    controller.scannedDataStream.listen((scanData) {
      if (scanData.code != null && scanData.code!.isNotEmpty) {
        // Close the scanner
        Navigator.of(context).pop();

        // Update text field with scanned code
        setState(() {
          billNoController.text = scanData.code!;
          isScanning = false;
        });

        // Fetch bill data with the scanned code
        fetchBill();
      }
    });
  }

  void _showQRScanner() {
    setState(() {
      isScanning = true;
    });

    // Wait for the next frame to ensure the UI is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Header section
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Scan QR Code',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // QR Scanner section
                Expanded(
                  child: Container(
                    width: double.infinity,
                    color: Colors.black,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        QRView(
                          key: qrKey,
                          onQRViewCreated: _onQRViewCreated,
                          overlay: QrScannerOverlayShape(
                            borderColor: const Color(0xFF2196F3),
                            borderRadius: 10,
                            borderLength: 30,
                            borderWidth: 10,
                            cutOutSize: 300,
                          ),
                        ),
                        // Scanner guide elements
                        Container(
                          width: 320,
                          height: 320,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Buttons section with proper padding and layout
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ElevatedButton.icon(
                            onPressed: () {
                              // Flash toggle
                              qrController?.toggleFlash();
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Toggling flash...'))
                              );
                            },
                            icon: const Icon(Icons.flash_on),
                            label: const Text('Flash'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              backgroundColor: Colors.amber,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: ElevatedButton.icon(
                            onPressed: () {
                              // Flip camera
                              qrController?.flipCamera();
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Camera flipped'))
                              );
                            },
                            icon: const Icon(Icons.flip_camera_ios),
                            label: const Text('Flip Camera'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ).then((_) {
        // When bottom sheet is closed
        if (qrController != null) {
          qrController!.dispose();
        }
        setState(() {
          isScanning = false;
        });
      });
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus(); // Dismiss keyboard on tap
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.blue.shade50, Colors.white],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(  // Add this
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Vehicle Exit Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2196F3).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.directions_car,
                            color: Color(0xFF2196F3),
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Vehicle Exit",
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "Process vehicle exit and print receipt",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Bill Information Card
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Bill Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2196F3),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: billNoController,
                                      decoration: const InputDecoration(
                                        hintText: 'Enter Bill Number',
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.qr_code_scanner, color: Color(0xFF2196F3)),
                                    onPressed: _showQRScanner,
                                    tooltip: 'Scan QR Code',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Replace the current isLoading indicator in the Find Bill button
                            SizedBox(
                              height: 50,
                              child: ElevatedButton(
                                onPressed: fetchBill,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2196F3),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: isLoading
                                    ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Text('Searching...', style: TextStyle(fontSize: 16)),
                                  ],
                                )
                                    : const Text(
                                  'Find Bill',
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Bill Not Found Error
                    if (!isBillFound && !isLoading)
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        color: Colors.red.shade50,
                        child: const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 48,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Bill Not Found',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Please check the bill number and try again.',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),

                    if (billData != null && !isLoading)
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,  // This ensures it takes only the space it needs
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.receipt_long,
                                      color: Color(0xFF2196F3),
                                      size: 28,
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      'Bill Details',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF2196F3),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 30),
                                _buildDetailRow('Bill Number', billData!['billNumber']),
                                _buildDetailRow('Veh Number', billData!['vehicleNo']),
                                _buildDetailRow(
                                  'Entry Time',
                                  DateFormat('MMM dd, yyyy - hh:mm a')
                                      .format(DateTime.parse(billData!['entryTime'])),
                                ),
                                _buildDetailRow(
                                  'Exit Time',
                                  DateFormat('MMM dd, yyyy - hh:mm a')
                                      .format(DateTime.parse(billData!['exitTime'])),
                                ),
                                _buildDetailRow('Hours Spent', '${billData!['hoursSpent']} hour(s)'),
                                const Divider(height: 30),
                                _buildDetailRow(
                                  'Total Amount',
                                  '₹${billData!['totalPrice'].toStringAsFixed(2)}',
                                  isBold: true,
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    const Text(
                                      'Payment Status: ',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    _buildPaymentStatusBadge(isAlreadyPaid),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                if (!isAlreadyPaid)
                                  SizedBox(
                                    height: 55,
                                    child: ElevatedButton.icon(
                                      onPressed: _printBill,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF4CAF50),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      icon: const Icon(Icons.print),
                                      label: const Text(
                                        'Print Receipt',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                    ),
                                  ),
                                if (isAlreadyPaid)
                                  SizedBox(
                                    height: 55,
                                    child: ElevatedButton.icon(
                                      onPressed: null, // Disabled button
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.grey,
                                        disabledBackgroundColor: Colors.grey.shade300,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      icon: const Icon(Icons.check_circle),
                                      label: const Text(
                                        'Already Processed',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                if (!isConnected && !isAlreadyPaid)
                                  const Text(
                                    'Printer not connected. Please check connection.',
                                    style: TextStyle(color: Colors.red, fontSize: 13),
                                    textAlign: TextAlign.center,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    if (billData != null && !isLoading)
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Exit Gate',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2196F3),
                                ),
                              ),
                              const SizedBox(height: 16),
                              _isLoading
                                  ? const Center(child: CircularProgressIndicator())
                                  : Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    isExpanded: true,
                                    value: _selectedExitGateId,
                                    hint: const Text('Select Exit Gate'),
                                    onChanged: (int? value) {
                                      setState(() {
                                        _selectedExitGateId = value;
                                        selectedExitGateId = value ?? 0; // Add this line to update the variable used in _printBill

                                        // Update selected gate name if value is not null
                                        if (value != null) {
                                          final selectedGate = _exitGates.firstWhere(
                                                (gate) => gate['id'] == value,
                                            orElse: () => {'name': ''},
                                          );
                                          selectedExitGateName = selectedGate['name'];
                                        } else {
                                          selectedExitGateName = '';
                                        }
                                      });
                                    },
                                    items: _exitGates.map<DropdownMenuItem<int>>((gate) {
                                      return DropdownMenuItem<int>(
                                        value: gate['id'] as int,
                                        child: Text(gate['name'] ?? ''),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,  // Fixed width for alignment
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 15,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: valueColor ?? (isBold ? const Color(0xFF2196F3) : Colors.black87),
              ),
            ),
          ),
        ],
      ),
    );
  }

  _buildPaymentStatusBadge(bool isPaid) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isPaid ? Colors.green.shade100 : Colors.red.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPaid ? Colors.green : Colors.red,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPaid ? Icons.check_circle : Icons.pending,
            size: 18,
            color: isPaid ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 6),
          Text(
            isPaid ? 'PAID' : 'UNPAID',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isPaid ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    qrController?.dispose();
    billNoController.dispose();
    super.dispose();
  }
}