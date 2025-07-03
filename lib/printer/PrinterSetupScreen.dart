import 'package:flutter/material.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'BluetoothPrinterService.dart';

class PrinterSetupScreen extends StatefulWidget {
  const PrinterSetupScreen({super.key});

  @override
  _PrinterSetupScreenState createState() => _PrinterSetupScreenState();
}

class _PrinterSetupScreenState extends State<PrinterSetupScreen> {
  final BluetoothPrinterService _printerService = BluetoothPrinterService();
  List<BluetoothDevice> pairedDevices = [];
  List<BluetoothDevice> unpairDevices = [];
  BluetoothDevice? selectedDevice;
  bool isConnected = false;
  String statusMessage = "No Printer Connected";
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initPrinterState();
    });
  }

  Future<void> _initPrinterState() async {
    setState(() {
      isConnected = _printerService.isConnected;
      statusMessage = _printerService.statusMessage;
      selectedDevice = _printerService.selectedDevice;
    });
    await _refreshDevices();
  }

  Future<void> _refreshDevices() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      statusMessage = "Scanning for devices...";
    });

    try {
      bool? isBluetoothOn = await _printerService.printer.isAvailable;

      if (!mounted) return;

      if (isBluetoothOn != true) {
        setState(() {
          pairedDevices = [];
          unpairDevices = [];
          statusMessage = "Bluetooth is turned off";
          isLoading = false;
        });
        return;
      }

      // Get paired devices
      List<BluetoothDevice> bondedDevices = await _printerService.printer.getBondedDevices();

      // Get all devices including unpaired
      List<BluetoothDevice> allDevices = await _printerService.getAllBluetoothDevices();

      if (!mounted) return;

      // Separate paired and unpaired devices
      List<BluetoothDevice> nearbyDevices = allDevices.where((device) =>
      !bondedDevices.any((paired) => paired.address == device.address)).toList();

      setState(() {
        pairedDevices = bondedDevices;
        unpairDevices = nearbyDevices;
        statusMessage = "Found ${pairedDevices.length} paired and ${unpairDevices.length} nearby devices";
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        statusMessage = "Error scanning for devices: $e";
        pairedDevices = [];
        unpairDevices = [];
        isLoading = false;
      });
    }
  }

  Future<void> _connectToPrinter(BluetoothDevice device) async {
    if (!mounted) return;

    setState(() {
      selectedDevice = device;
      statusMessage = "Connecting to ${device.name}...";
    });

    try {
      bool connected = await _printerService.connectToPrinter(device);

      if (!mounted) return;

      setState(() {
        isConnected = connected;
        statusMessage = connected
            ? "Connected to ${device.name}"
            : "Failed to connect to ${device.name}";
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        statusMessage = "Connection error: $e";
      });
    }
  }

  Future<void> _disconnectPrinter() async {
    try {
      await _printerService.disconnectPrinter();

      if (!mounted) return;

      setState(() {
        isConnected = false;
        statusMessage = "Disconnected from Printer";
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        statusMessage = "Disconnect error: $e";
      });
    }
  }

  Future<void> _testPrint() async {
    if (!isConnected) {
      setState(() {
        statusMessage = "Printer not connected";
      });
      return;
    }

    try {
      await _printerService.printTest();

      if (!mounted) return;

      setState(() {
        statusMessage = "Test printed successfully";
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        statusMessage = "Print error: $e";
      });
    }
  }

  Widget _buildDeviceList(List<BluetoothDevice> devices, String title) {
    if (devices.isEmpty) {
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 10),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.bluetooth_disabled, size: 32, color: Colors.grey[400]),
                const SizedBox(height: 8),
                Text(
                  "No $title devices found",
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.blueGrey[800],
            ),
          ),
        ),
        ...devices.map((device) {
          final bool isSelected = selectedDevice?.address == device.address;

          return Card(
            elevation: isSelected ? 3 : 1,
            margin: const EdgeInsets.only(bottom: 12),
            color: isSelected ? const Color(0xFFE3F2FD) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isSelected ? const Color(0xFF1A73E8) : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: InkWell(
              onTap: () {
                setState(() {
                  selectedDevice = device;
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF1A73E8) : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.print,
                            color: isSelected ? Colors.white : Colors.blueGrey,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                device.name ?? "Unknown Device",
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                device.address ?? "No Address",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isConnected && isSelected
                            ? _disconnectPrinter
                            : () => _connectToPrinter(device),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isConnected && isSelected
                              ? Colors.redAccent
                              : const Color(0xFF1A73E8),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          isConnected && isSelected ? "Disconnect" : "Connect",
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Bluetooth Printer Setup',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color(0xFF1A73E8),
        iconTheme: const IconThemeData(color: Colors.white), // 👈 this changes the back button color
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: isConnected ? Colors.greenAccent : Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isConnected ? "Connected" : "Disconnected",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white, // 👈 add this line
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Refresh button at the top
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 20.0),
              child: ElevatedButton.icon(
                icon: isLoading
                    ? LoadingAnimationWidget.threeArchedCircle(
                  color: Colors.white,
                  size: 24,
                ) : const Icon(Icons.refresh, color: Colors.white),
                label: Text(
                  isLoading ? "Scanning..." : "Scan for devices",
                  style: const TextStyle(color: Colors.white),
                ),
                onPressed: isLoading ? null : _refreshDevices,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A73E8),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(40),
                ),
              ),
            ),

            // Main content
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Card
                      Card(
                        color: isConnected ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isConnected ? const Color(0xFF4CAF50) : const Color(0xFFFFA000),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  isConnected ? Icons.check_circle : Icons.info,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isConnected ? "Printer Connected" : "Printer Status",
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      statusMessage,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),
                      const Text(
                        "Available Printers",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "Select a printer to connect and print tickets",
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),

                      // Device Lists with Loading state
                      if (isLoading)
                         Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                LoadingAnimationWidget.threeArchedCircle(
                                  color: const Color(0xFF1A73E8),
                                  size: 50,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  "Scanning for Bluetooth devices...",
                                  style: TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (pairedDevices.isEmpty && unpairDevices.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              children: [
                                Icon(Icons.bluetooth_disabled, size: 48, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                const Text(
                                  "No Bluetooth devices found",
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  "Make sure Bluetooth is enabled and devices are in range",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Paired devices section
                            _buildDeviceList(pairedDevices, "Paired Devices"),
                            const SizedBox(height: 20),
                            // Unpaired devices section
                            _buildDeviceList(unpairDevices, "Nearby Devices"),
                          ],
                        ),

                      const SizedBox(height: 20),

                      // Test Print Button
                      if (isConnected)
                        ElevatedButton.icon(
                          icon: const Icon(Icons.print),
                          label: const Text("Test Print"),
                          onPressed: _testPrint,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFFFFF),
                            minimumSize: const Size.fromHeight(50),
                          ),
                        ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}