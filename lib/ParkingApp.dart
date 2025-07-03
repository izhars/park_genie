import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:park_genie/printer/BluetoothPrinterService.dart';
import 'package:park_genie/printer/WifiPrinterService.dart'; // Import WiFi printer service
import 'DatabaseHelper.dart';
import 'HomeScreen.dart';
import 'data/services/ApiConfig.dart';

class ParkingApp extends StatefulWidget {

  const ParkingApp({super.key});

  @override
  _ParkingAppState createState() => _ParkingAppState();
}

class _ParkingAppState extends State<ParkingApp> with WidgetsBindingObserver {
  final BluetoothPrinterService bluetoothPrinterService = BluetoothPrinterService();
  final WifiPrinterService wifiPrinterService = WifiPrinterService(); // Initialize WiFi printer service
  final DatabaseHelper dbHelper = DatabaseHelper( baseUrl: ApiConfig.baseUrl); // Initialized internally

  // Printer status tracking
  bool isAnyPrinterConnected = false;
  String printerStatusMessage = "No Printer Connected";
  String activePrinterType = "none"; // "none", "bluetooth", or "wifi"

  // Parking system stats
  int totalSpaces = 0;
  int occupiedSpaces = 0;
  double totalRevenue = 0;
  int availableSpaces = 0;
  String companyName = 'Admin Control Panel';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeDatabase(); // Call database initialization
    _initializePrinters();
    _fetchTotalRevenue();
    _fetchCompanyDetails();

    // Listen to both printer status changes
    _setupPrinterListeners();
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _fetchTotalRevenue(); // Refresh parking data when returning to the app
      _refreshPrinterStatus(); // Refresh both printer types
    }
  }

  void _setupPrinterListeners() {
    bluetoothPrinterService.connectionNotifier.addListener(_updatePrinterStatus);
    bluetoothPrinterService.statusNotifier.addListener(_updatePrinterStatus);
    wifiPrinterService.connectionNotifier.addListener(_updatePrinterStatus);
    wifiPrinterService.statusNotifier.addListener(_updatePrinterStatus);
  }

  void _updatePrinterStatus() {
    final bool bluetoothConnected = bluetoothPrinterService.connectionNotifier.value;
    final bool wifiConnected = wifiPrinterService.connectionNotifier.value;

    print("checkPrinter: Bluetooth Connected = $bluetoothConnected");
    print("checkPrinter: WiFi Connected = $wifiConnected");

    debugPrint("Bluetooth Connected: $bluetoothConnected");
    debugPrint("WiFi Connected: $wifiConnected");

    setState(() {
      if (bluetoothConnected) {
        isAnyPrinterConnected = true;
        printerStatusMessage = bluetoothPrinterService.statusNotifier.value;
        activePrinterType = "bluetooth";
      } else if (wifiConnected) {
        isAnyPrinterConnected = true;
        printerStatusMessage = wifiPrinterService.statusNotifier.value;
        activePrinterType = "wifi";
      } else {
        isAnyPrinterConnected = false;
        if (activePrinterType == "bluetooth") {
          printerStatusMessage = bluetoothPrinterService.statusNotifier.value;
        } else if (activePrinterType == "wifi") {
          printerStatusMessage = wifiPrinterService.statusNotifier.value;
        } else {
          printerStatusMessage = "No Printer Connected";
        }
        activePrinterType = "none";
      }
    });
  }

  void _initializePrinters() {
    bluetoothPrinterService.refreshDevicesList();
    _checkForDefaultPrinter();
  }

  Future<void> _checkForDefaultPrinter() async {
    try {
      final defaultPrinter = await bluetoothPrinterService.getDefaultSavedPrinter();
      _updatePrinterStatus();
    } catch (e) {
      print("Error checking default printer: $e");
    }
  }

  void _refreshPrinterStatus() {
    bluetoothPrinterService.refreshDevicesList();
    bluetoothPrinterService.checkConnection();
    wifiPrinterService.checkConnection();
  }

  Future<void> _initializeDatabase() async {
    try {
      int version = await dbHelper.getVersion();
      print("Database initialized. Version: $version");
    } catch (e) {
      print("Error initializing database: $e");
    }
  }

  @override
  void dispose() {
    bluetoothPrinterService.connectionNotifier.removeListener(_updatePrinterStatus);
    bluetoothPrinterService.statusNotifier.removeListener(_updatePrinterStatus);
    wifiPrinterService.connectionNotifier.removeListener(_updatePrinterStatus);
    wifiPrinterService.statusNotifier.removeListener(_updatePrinterStatus);

    bluetoothPrinterService.dispose();
    wifiPrinterService.dispose();

    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _fetchTotalRevenue() async {
    double revenueFromDB = await dbHelper.getTotalRevenue();
    Map<String, int> parkingInfo = await dbHelper.getParkingSpaceInfo();

    setState(() {
      totalRevenue = revenueFromDB;
      totalSpaces = parkingInfo['totalSpaces'] ?? 0;
      occupiedSpaces = parkingInfo['occupiedSpaces'] ?? 0;
      availableSpaces = totalSpaces - occupiedSpaces;
    });
  }

  Future<void> _fetchCompanyDetails() async {
    try {
      final userData = await dbHelper.getUser();
      if (mounted) {
        setState(() {
          companyName = userData?['companyName'] ?? 'Admin Control Panel';
        });
      }
    } catch (e) {
      print('Error fetching company details: $e');
    }
  }

  void updateParkingStats({int? occupied, double? revenue}) {
    if (occupied == null && revenue == null) {
      _fetchTotalRevenue();
    } else {
      setState(() {
        if (occupied != null) occupiedSpaces = occupied;
        if (revenue != null) totalRevenue += revenue;
      });
    }
  }

  Future<void> printTest() async {
    if (activePrinterType == "bluetooth") {
      await bluetoothPrinterService.printTest();
    } else if (activePrinterType == "wifi") {
      await wifiPrinterService.printTest();
    } else {
      print("No printer connected");
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Parking System',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A73E8),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        textTheme: GoogleFonts.poppinsTextTheme(),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A73E8),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A73E8),
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
          ),
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: HomeScreen(
        isConnected: isAnyPrinterConnected,
        statusMessage: printerStatusMessage,
        activePrinterType: activePrinterType,
        bluetoothPrinterService: bluetoothPrinterService,
        wifiPrinterService: wifiPrinterService,
        totalSpaces: totalSpaces,
        occupiedSpaces: occupiedSpaces,
        totalRevenue: totalRevenue,
        companyName: companyName,
        updateParkingStats: updateParkingStats,
      ),
    );
  }
}

class ConnectedScreen extends StatelessWidget {
  final Widget child;
  final bool isConnected;
  final String statusMessage;
  final String printerType;

  const ConnectedScreen({
    super.key,
    required this.child,
    required this.isConnected,
    required this.statusMessage,
    this.printerType = "none",
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = isConnected ? Colors.green.shade400 : Colors.red.shade400;
    final connectionText = isConnected
        ? printerType == "bluetooth"
        ? "BT Connected"
        : "WiFi Connected"
        : "Disconnected";
    final connectionIcon = isConnected
        ? printerType == "bluetooth"
        ? Icons.bluetooth
        : Icons.wifi
        : Icons.wifi_off;

    return Scaffold(
      appBar: AppBar(
        elevation: 2,
        shadowColor: Colors.black26,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/icons/parked_car.png',
              width: 24,
              height: 24,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            const Text(
              "Park Genie",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 120),
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,  // Set the background color to white
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: statusColor, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(connectionIcon, size: 14, color: statusColor),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      connectionText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: statusColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          if (statusMessage.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              color: isConnected ? Colors.green.shade50 : Colors.red.shade50,
              child: Text(
                statusMessage,
                style: TextStyle(
                  color: isConnected ? Colors.green.shade700 : Colors.red.shade700,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          height: 6,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isConnected
                  ? [Colors.green.shade200, Colors.blue.shade200]
                  : [Colors.red.shade200, Colors.orange.shade200],
            ),
          ),
        ),
      ),
    );
  }
}
