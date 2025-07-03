import 'package:flutter/material.dart';
import 'package:park_genie/presentation/screens/AboutUsScreen.dart';
import 'package:park_genie/presentation/screens/LoginPage.dart';
import 'package:park_genie/presentation/screens/SettingsScreen.dart';
import 'package:park_genie/printer/BluetoothPrinterService.dart';
import 'package:park_genie/printer/WifiPrinterService.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:park_genie/printer/LANPrinterSetupScreen.dart';
import 'package:park_genie/printer/PrinterSetupScreen.dart';
import 'package:park_genie/printer/USBPrinterSetupScreen.dart';
import 'BillEntryScreen.dart';
import 'BillExitScreen.dart';
import 'DatabaseHelper.dart';
import 'ParkingApp.dart';
import 'data/AppInfoUtil.dart';
import 'data/services/ApiConfig.dart';
import 'data/services/PrivacyPolicyPage.dart';
import 'data_synchronization/DatabaseSyncService.dart';
import 'data_synchronization/background/background_sync_manager.dart';
import 'printer/PrinterSetupScreenWifi.dart';


class HomeScreen extends StatefulWidget {
  final bool isConnected;
  final String statusMessage;
  final String activePrinterType;
  final BluetoothPrinterService bluetoothPrinterService;
  final WifiPrinterService wifiPrinterService;
  final int totalSpaces;
  final int occupiedSpaces;
  final double totalRevenue;
  final String companyName;
  final Function({int? occupied, double? revenue}) updateParkingStats;

  const HomeScreen({
    super.key,
    required this.isConnected,
    required this.statusMessage,
    required this.activePrinterType,
    required this.bluetoothPrinterService,
    required this.wifiPrinterService,
    required this.totalSpaces,
    required this.occupiedSpaces,
    required this.totalRevenue,
    required this.companyName,
    required this.updateParkingStats,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _version = '';
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  late DatabaseHelper _dbHelper;

  @override
  void initState() {
    super.initState();
    _dbHelper = DatabaseHelper.instance;
    _loadVersion();
    _performInitialSync();
  }

  Future<void> _performInitialSync() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool shouldSyncOnStartup = prefs.getBool('syncOnStartup') ?? true;
    print('shouldSyncOnStartup: $shouldSyncOnStartup'); // Debug log
    if (shouldSyncOnStartup) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        print('Initiating sync'); // Debug log
        _syncData();
      });
    } else {
      print('Sync skipped due to syncOnStartup being false'); // Debug log
    }

    String? lastSync = prefs.getString('lastSyncTime');
    if (lastSync != null) {
      setState(() {
        _lastSyncTime = DateTime.parse(lastSync);
      });
    }
  }

  Future<void> _syncData() async {
    if (_isSyncing) {
      print('Sync already in progress, skipping'); // Debug log
      return;
    }

    setState(() {
      _isSyncing = true;
    });

    try {
      await BackgroundSyncManager.performManualSync();
      final now = DateTime.now();
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('lastSyncTime', now.toIso8601String());
      print('Sync completed, lastSyncTime: $now'); // Debug log

      setState(() {
        _lastSyncTime = now;
      });

      widget.updateParkingStats();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sync completed successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Sync error: $e'); // Debug log
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sync failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  Widget _buildSyncButton() {
    return IconButton(
      icon: _isSyncing
          ? SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.white,
        ),
      )
          : Icon(Icons.sync),
      onPressed: _isSyncing ? null : _syncData,
      tooltip: 'Sync data',
    );
  }

  Widget _buildSyncStatus() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
          SizedBox(width: 4),
          Text(
            _lastSyncTime != null
                ? 'Last sync: ${_formatDateTime(_lastSyncTime!)}'
                : 'Not synced yet',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _loadVersion() async {
    String version = await AppInfoUtil.getVersion();
    setState(() {
      _version = version;
    });
  }

  @override
  void dispose() {
    // Clean up resources or listeners here
    super.dispose();
  }

  void _navigateTo(BuildContext context, Widget screen) async {
    // First close the drawer if it's open
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }

    // Then navigate to the screen
    await Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) {
          return ConnectedScreen(
            isConnected: widget.isConnected,
            statusMessage: widget.statusMessage,
            printerType: widget.activePrinterType,
            child: screen,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );

    // Update stats when returning from the screen
    widget.updateParkingStats(occupied: null, revenue: null);
  }

  void _navigateFromDrawer(BuildContext context, Widget screen) {
    // First close the drawer
    Navigator.of(context).pop();

    // Then navigate to the screen using smooth transition
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey, // Add scaffold key to control the drawer
      appBar: AppBar(
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
            padding: const EdgeInsets.all(8.0),
            child: Icon(
              widget.isConnected
                  ? (widget.activePrinterType == 'wifi'
                      ? Icons.wifi
                      : Icons.bluetooth_connected)
                  : Icons.signal_wifi_off,
              color: widget.isConnected ? Colors.white : Colors.white70,
            ),
          ),
        ],
      ),
      // Add drawer only to the home screen
      drawer: Drawer(
        child: ParkingSideBar(
          scaffoldKey: _scaffoldKey, // 👈 pass key to the sidebar
          totalSpaces: widget.totalSpaces,
          occupiedSpaces: widget.occupiedSpaces,
          availableSpaces: widget.totalSpaces - widget.occupiedSpaces,
          totalRevenue: widget.totalRevenue,
          isConnected: widget.isConnected,
          companyName: widget.companyName,
          navigateTo:
              _navigateFromDrawer, // Use the specific drawer navigation method
          dbhelper: _dbHelper, // ✅ Pass it here
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return Dialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        elevation: 0,
                        backgroundColor: Colors.transparent,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 15,
                                offset: Offset(0, 10),
                              )
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Select Connection Type',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 22,
                                  color: Colors.grey[800],
                                ),
                              ),
                              const SizedBox(height: 24),
                              _buildConnectionOption(
                                context: context,
                                icon: Icons.wifi,
                                title: 'WiFi',
                                color: Colors.blue,
                                onTap: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const PrinterSetupScreenWifi(),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 12),
                              _buildConnectionOption(
                                context: context,
                                icon: Icons.bluetooth,
                                title: 'Bluetooth',
                                color: Colors.indigo,
                                onTap: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const PrinterSetupScreen(),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 12),
                              _buildConnectionOption(
                                context: context,
                                icon: Icons.usb,
                                title: 'USB Printer',
                                color: Colors.teal,
                                onTap: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const USBPrinterSetupScreen(),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 12),
                              _buildConnectionOption(
                                context: context,
                                icon: Icons.lan,
                                title: 'LAN Printer',
                                color: Colors.deepPurple,
                                onTap: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const LANPrinterSetupScreen(),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 24),
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: widget.isConnected
                          ? [Colors.green[50]!, Colors.green[100]!]
                          : [Colors.blue[50]!, Colors.blue[100]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.isConnected
                            ? Colors.green.withOpacity(0.2)
                            : Colors.blue.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: widget.isConnected
                                ? Colors.green.withOpacity(0.9)
                                : Colors.blue.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: widget.isConnected
                                    ? Colors.green.withOpacity(0.4)
                                    : Colors.blue.withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              )
                            ],
                          ),
                          child: Icon(
                            widget.isConnected
                                ? Icons.check_circle_rounded
                                : Icons.print_rounded,
                            size: 36,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.isConnected
                                    ? "Printer Ready"
                                    : "No Printer Connected",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                widget.isConnected
                                    ? "You can now start printing"
                                    : "Connect to start printing",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color:
                                widget.isConnected ? Colors.green : Colors.blue,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: widget.isConnected
                                    ? Colors.green.withOpacity(0.4)
                                    : Colors.blue.withOpacity(0.4),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  widget.isConnected
                                      ? Icons.settings
                                      : Icons.bluetooth,
                                  size: 18,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  widget.isConnected ? "Connected" : "Connect",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
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
              const SizedBox(height: 40),
              const Text(
                "Parking Operations",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                "Manage vehicle entry and exit operations",
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 20),

              // Operation Cards
              Row(
                children: [
                  Expanded(
                    child: _buildOperationCard(
                      context,
                      title: "Vehicle Entry",
                      icon: Icons.directions_car,
                      color: const Color(0xFF4CAF50),
                      onTap: () =>
                          _navigateTo(context, const BillEntryScreen()),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildOperationCard(
                      context,
                      title: "Vehicle Exit",
                      icon: Icons.exit_to_app,
                      color: const Color(0xFFF57C00),
                      onTap: () => _navigateTo(context, const BillExitScreen()),
                    ),
                  ),
                ],
              ),

              // Dashboard summary row
              const SizedBox(height: 30),
              Card(
                color: const Color(0xFFE3F2FD),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryItem(
                        icon: Icons.car_rental,
                        title: "Available",
                        value: "${widget.totalSpaces - widget.occupiedSpaces}",
                        color: const Color(0xFF2196F3),
                      ),
                      _buildSummaryItem(
                        icon: Icons.car_crash,
                        title: "Occupied",
                        value: "${widget.occupiedSpaces}",
                        color: const Color(0xFFF57C00),
                      ),
                      _buildSummaryItem(
                        icon: Icons.currency_rupee_sharp,
                        title: "Revenue",
                        value: "₹${widget.totalRevenue.toStringAsFixed(2)}",
                        color: const Color(0xFF4CAF50),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method for connection options in the dialog
  Widget _buildConnectionOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: color.withOpacity(0.1),
            border: Border.all(color: color.withOpacity(0.3), width: 1),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(
                  color: color.withOpacity(0.8),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: color.withOpacity(0.6),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[700],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildOperationCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Process ${title.toLowerCase()} tickets",
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                alignment: Alignment.centerRight,
                child: Icon(Icons.arrow_forward, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Modified ParkingSideBar class - removing management items
class ParkingSideBar extends StatelessWidget {
  final int totalSpaces;
  final int occupiedSpaces;
  final int availableSpaces;
  final double totalRevenue;
  final bool isConnected;
  final String companyName;
  final Function(BuildContext, Widget) navigateTo;
  final DatabaseHelper dbhelper;
  final dynamic scaffoldKey;

  const ParkingSideBar({
    super.key,
    required this.scaffoldKey, // 👈 include in constructor
    required this.totalSpaces,
    required this.occupiedSpaces,
    required this.availableSpaces,
    required this.totalRevenue,
    required this.isConnected,
    required this.companyName,
    required this.navigateTo,
    required this.dbhelper,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        DrawerHeader(
          decoration: const BoxDecoration(
            color: Color(0xFF1A73E8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                radius: 32,
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.local_parking,
                  size: 40,
                  color: Color(0xFF1A73E8),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Parking Dashboard',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                companyName,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),

        // Parking statistics
        _sectionTitle('PARKING STATISTICS'),
        _buildStatsListTile(
          icon: Icons.crop_square,
          title: 'Total Spaces',
          value: totalSpaces.toString(),
          color: const Color(0xFF1A73E8),
        ),
        _buildStatsListTile(
          icon: Icons.directions_car,
          title: 'Occupied Spaces',
          value: occupiedSpaces.toString(),
          color: const Color(0xFFF57C00),
        ),
        _buildStatsListTile(
          icon: Icons.check_circle_outline,
          title: 'Available Spaces',
          value: availableSpaces.toString(),
          color: const Color(0xFF4CAF50),
        ),
        _buildStatsListTile(
          icon: Icons.currency_rupee_sharp,
          title: 'Total Revenue',
          value: '₹${totalRevenue.toStringAsFixed(2)}',
          color: const Color(0xFF5C6BC0),
        ),

        const Divider(),

        // Main navigation
        _sectionTitle('NAVIGATION'),
        ListTile(
          leading: const Icon(Icons.settings, color: Color(0xFF546E7A)),
          title: const Text('Settings'),
          onTap: () => navigateTo(context, SettingsScreen(dbHelper: dbhelper)),
        ),
        ListTile(
          leading: const Icon(Icons.info_outline, color: Color(0xFF546E7A)),
          title: const Text('About Us'),
          onTap: () => navigateTo(context, const AboutUsPage()),
        ),
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined, color: Color(0xFF546E7A)),
          title: const Text('Privacy Policy'),
          onTap: () => navigateTo(context, const PrivacyPolicyPage()),
        ),
        // Option 1: Document with legal symbol
        ListTile(
          leading: const Icon(Icons.gavel, color: Color(0xFF546E7A)),
          title: const Text('Terms & Conditions'),
          onTap: () => navigateTo(context, const TermsAndConditionsPage()),
        ),

        ListTile(
          leading: const Icon(Icons.support_agent, color: Color(0xFF546E7A)),
          title: const Text('Support'),
          onTap: () => navigateTo(context, const SupportPage()),
        ),

        const Divider(),

        // Logout
        ListTile(
          leading: const Icon(Icons.exit_to_app, color: Color(0xFFE53935)),
          title: const Text('Logout', style: TextStyle(color: Color(0xFFE53935))),
            onTap: () async {
              scaffoldKey.currentState?.openEndDrawer();

              Future.delayed(const Duration(milliseconds: 300), () async {
                bool? confirm = await showDialog<bool>(
                  context: scaffoldKey.currentContext!,
                  barrierDismissible: true, // tapping outside will close it
                  builder: (context) => AlertDialog(
                    title: const Text("Confirm Logout"),
                    content: const Text("Do you want to sync data before logout?"),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text("Logout Without Sync"),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text("Sync & Logout"),
                      ),
                    ],
                  ),
                );

                if (confirm == null) {
                  // 🛑 User tapped outside or pressed back — cancel logout
                  return;
                }

                try {
                  if (confirm == true) {
                    final syncService = DatabaseSyncService(
                      dbHelper: dbhelper,
                      baseUrl: ApiConfig.baseUrl,
                    );

                    bool pushSuccess = await syncService.pushAllToServer();

                    if (!pushSuccess) {
                      ScaffoldMessenger.of(scaffoldKey.currentContext!).showSnackBar(
                        const SnackBar(content: Text("Sync failed. Proceeding with logout.")),
                      );
                    }
                  }

                  await dbhelper.clearAllDataOnLogout();
                  SharedPreferences prefs = await SharedPreferences.getInstance();
                  await prefs.clear();

                  Navigator.pushAndRemoveUntil(
                    scaffoldKey.currentContext!,
                    MaterialPageRoute(builder: (context) => LoginPage()),
                        (route) => false,
                  );
                } catch (e) {
                  print('Logout failed: $e');
                  ScaffoldMessenger.of(scaffoldKey.currentContext!).showSnackBar(
                    const SnackBar(content: Text('Error during logout. Please try again.')),
                  );
                }
              });
            }
        ),


        // Footer
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: FutureBuilder<String>(
            future: AppInfoUtil.getVersion(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox.shrink();
              }
              return Column(
                children: [
                  const Text(
                    'Made with ❤️ in India',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    snapshot.data ?? '',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatsListTile({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(title),
      trailing: Text(
        value,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
