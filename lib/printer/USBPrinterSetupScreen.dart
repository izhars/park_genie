import 'package:flutter/material.dart';
import 'package:usb_serial/usb_serial.dart';
import 'USBPrinterService.dart';

class USBPrinterSetupScreen extends StatefulWidget {
  const USBPrinterSetupScreen({super.key});

  @override
  _USBPrinterSetupScreenState createState() => _USBPrinterSetupScreenState();
}

class _USBPrinterSetupScreenState extends State<USBPrinterSetupScreen> {
  List<UsbDevice> _devices = [];
  UsbDevice? _selectedDevice;
  bool _connecting = false;
  bool _scanning = false;
  String _status = "";
  final USBPrinterService _printerService = USBPrinterService();

  @override
  void initState() {
    super.initState();
    _loadUSBDevices();
  }

  Future<void> _loadUSBDevices() async {
    setState(() => _scanning = true);
    try {
      final devices = await _printerService.scanUSBDevices();
      setState(() {
        _devices = devices;
        _status = devices.isEmpty ? "No USB devices found" : "";
      });
    } catch (e) {
      setState(() => _status = "Error scanning: ${e.toString()}");
    } finally {
      setState(() => _scanning = false);
    }
  }

  Future<void> _connect() async {
    if (_selectedDevice == null) {
      _showSnackBar("Please select a printer first");
      return;
    }

    setState(() {
      _connecting = true;
      _status = "Connecting to ${_selectedDevice!.productName ?? 'device'}...";
    });

    try {
      bool success = await _printerService.connectToDevice(_selectedDevice!);
      setState(() {
        _status = success
            ? "Connected to ${_selectedDevice!.productName ?? 'device'}"
            : "Failed to connect";
      });

      if (success) {
        _showSnackBar("Successfully connected to printer");
      }
    } catch (e) {
      setState(() => _status = "Connection error: ${e.toString()}");
    } finally {
      setState(() => _connecting = false);
    }
  }

  Future<void> _printTest() async {
    if (!_printerService.isConnected()) {
      _showSnackBar("Connect to a printer first");
      return;
    }

    setState(() => _status = "Printing test page...");
    try {
      bool success = await _printerService.printTest();
      setState(() => _status = success ? "Test page printed successfully" : "Failed to print test page");
    } catch (e) {
      setState(() => _status = "Print error: ${e.toString()}");
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message))
    );
  }

  Widget _buildDeviceItem(UsbDevice device) {
    String deviceName = device.productName ?? 'Unknown Device';
    String manufacturer = device.manufacturerName ?? 'Unknown Manufacturer';
    String deviceId = "ID: ${device.deviceId}";

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: RadioListTile<UsbDevice>(
        title: Text(deviceName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('$manufacturer\n$deviceId'),
        value: device,
        groupValue: _selectedDevice,
        onChanged: (device) {
          setState(() => _selectedDevice = device);
        },
        secondary: const Icon(Icons.print),
        isThreeLine: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'USB Printer Setup',
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
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _scanning ? null : _loadUSBDevices,
            tooltip: "Refresh devices",
          )
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.usb, size: 32),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "USB Printer Connection",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Connect your receipt printer via USB",
                            style: TextStyle(
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Device list section
              const Text(
                "Available Devices",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),

              Expanded(
                child: _scanning
                    ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text("Scanning for USB devices..."),
                    ],
                  ),
                )
                    : _devices.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.devices_other, size: 48, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        "No USB devices found",
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text("Scan Again"),
                        onPressed: _loadUSBDevices,
                      ),
                    ],
                  ),
                )
                    : ListView.builder(
                  itemCount: _devices.length,
                  itemBuilder: (context, index) => _buildDeviceItem(_devices[index]),
                ),
              ),

              // Status section
              if (_status.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: _status.contains("Success") || _status.contains("Connected")
                        ? Colors.green.withOpacity(0.1)
                        : _status.contains("Error") || _status.contains("Failed")
                        ? Colors.red.withOpacity(0.1)
                        : Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _status.contains("Success") || _status.contains("Connected")
                          ? Colors.green
                          : _status.contains("Error") || _status.contains("Failed")
                          ? Colors.red
                          : Colors.blue,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _status.contains("Success") || _status.contains("Connected")
                            ? Icons.check_circle
                            : _status.contains("Error") || _status.contains("Failed")
                            ? Icons.error
                            : Icons.info,
                        color: _status.contains("Success") || _status.contains("Connected")
                            ? Colors.green
                            : _status.contains("Error") || _status.contains("Failed")
                            ? Colors.red
                            : Colors.blue,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _status,
                          style: TextStyle(
                            color: _status.contains("Success") || _status.contains("Connected")
                                ? Colors.green
                                : _status.contains("Error") || _status.contains("Failed")
                                ? Colors.red
                                : Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.usb),
                      label: const Text("Connect"),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _connecting ? null : _connect,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.receipt),
                      label: const Text("Print Test"),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _printerService.isConnected() ? _printTest : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}