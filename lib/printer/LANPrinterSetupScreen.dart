import 'package:flutter/material.dart';
import 'LANPrinterService.dart';
import 'PrinterType.dart';
import 'PrinterDatabaseHelper.dart';

class LANPrinterSetupScreen extends StatefulWidget {
  const LANPrinterSetupScreen({super.key});

  @override
  State<LANPrinterSetupScreen> createState() => _LANPrinterSetupScreenState();
}

class _LANPrinterSetupScreenState extends State<LANPrinterSetupScreen> {
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _portController = TextEditingController(text: '9100');
  final TextEditingController _printerNameController = TextEditingController();
  final LANPrinterService _printerService = LANPrinterService();
  final PrinterDatabaseHelper _dbHelper = PrinterDatabaseHelper();

  bool _isConnecting = false;
  bool _isPrinting = false;
  bool _isConnected = false;
  String _statusMessage = "";
  Color _statusColor = Colors.grey;
  List<PrinterType> _savedPrinters = [];

  @override
  void initState() {
    super.initState();
    _loadSavedPrinters();
  }

  Future<void> _loadSavedPrinters() async {
    final printerMaps = await _dbHelper.getActivePrinterTypes();
    final printers = printerMaps.map((map) => PrinterType.fromMap(map)).toList();
    setState(() {
      _savedPrinters = printers;
    });
  }


  void _connect() async {
    if (_ipController.text.isEmpty) {
      _showSnackBar("Please enter an IP address", Colors.red);
      return;
    }

    setState(() {
      _isConnecting = true;
      _statusMessage = "Connecting...";
      _statusColor = Colors.orange;
    });

    final ip = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 9100;
    final printerName = _printerNameController.text.trim().isEmpty
        ? "LAN Printer ($ip)"
        : _printerNameController.text.trim();

    try {
      final success = await _printerService.connectToPrinter(ip, port);

      setState(() {
        _isConnecting = false;
        _isConnected = success;
        _statusMessage = success
            ? "Connected to $printerName"
            : "Failed to connect to printer";
        _statusColor = success ? Colors.green : Colors.red;
      });

      if (success) {
        await _printerService.savePrinterToDatabase(ip, port, printerName);
        await _loadSavedPrinters();
      }
    } catch (e) {
      setState(() {
        _isConnecting = false;
        _isConnected = false;
        _statusMessage = "Error: ${e.toString()}";
        _statusColor = Colors.red;
      });
    }
  }

  void _printTestPage() async {
    if (!_isConnected) {
      _showSnackBar("Not connected to any printer", Colors.red);
      return;
    }

    setState(() {
      _isPrinting = true;
    });

    try {
      final success = await _printerService.printTest();
      setState(() {
        _isPrinting = false;
      });
      _showSnackBar(
          success ? "Test page printed successfully" : "Failed to print test page",
          success ? Colors.green : Colors.red);
    } catch (e) {
      setState(() {
        _isPrinting = false;
      });
      _showSnackBar("Error printing: ${e.toString()}", Colors.red);
    }
  }

  void _disconnect() async {
    await _printerService.disconnect();
    setState(() {
      _isConnected = false;
      _statusMessage = "Disconnected";
      _statusColor = Colors.grey;
    });
  }

  void _connectToSavedPrinter(PrinterType printer) async {
    final connectionParams = printer.connectionParams;
    if (!connectionParams.containsKey('ip') ||
        !connectionParams.containsKey('port')) {
      _showSnackBar("Invalid printer connection parameters", Colors.red);
      return;
    }

    _ipController.text = connectionParams['ip'];
    _portController.text = connectionParams['port'].toString();
    _printerNameController.text = printer.name;
    _connect();
  }

  void _deleteSavedPrinter(int id) async {
    await _dbHelper.deletePrinterType(id);
    await _loadSavedPrinters();
    _showSnackBar("Printer removed from saved list", Colors.blue);
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: color,
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'LAN Printer Setup',
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
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.indigoAccent.withOpacity(0.3), Colors.white],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Connection Setup Card
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Connect to Printer",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _printerNameController,
                          decoration: InputDecoration(
                            labelText: "Printer Name (Optional)",
                            prefixIcon: const Icon(Icons.print),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _ipController,
                          decoration: InputDecoration(
                            labelText: "Printer IP Address",
                            prefixIcon: const Icon(Icons.wifi),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _portController,
                          decoration: InputDecoration(
                            labelText: "Port (default: 9100)",
                            prefixIcon: const Icon(Icons.router),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.link),
                                label: const Text("Connect", style: TextStyle(color: Colors.white)),
                                onPressed: _isConnecting ? null : _connect,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.indigoAccent,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.power_off),
                              label: const Text("Disconnect"),
                              onPressed: _isConnected ? _disconnect : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_isConnecting)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: LinearProgressIndicator(),
                          ),
                        const SizedBox(height: 12),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _statusColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _statusColor),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _isConnected ? Icons.check_circle : Icons.info,
                                color: _statusColor,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _statusMessage.isEmpty
                                      ? "Not connected"
                                      : _statusMessage,
                                  style: TextStyle(color: _statusColor),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Actions Card
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Printer Actions",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.description),
                                label: const Text("Print Test Page"),
                                onPressed: _isConnected && !_isPrinting
                                    ? _printTestPage
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_isPrinting)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: LinearProgressIndicator(
                              valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.green),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Saved Printers Section
                const Text(
                  "Saved Printers",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),

                Expanded(
                  child: _savedPrinters.isEmpty
                      ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.save_alt,
                            size: 48,
                            color: Colors.grey
                        ),
                        SizedBox(height: 12),
                        Text(
                          "No saved printers",
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                      : ListView.builder(
                    itemCount: _savedPrinters.length,
                    itemBuilder: (context, index) {
                      final printer = _savedPrinters[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.print, color: Colors.indigoAccent),
                          title: Text(printer.name),
                          subtitle: Text(printer.address ?? 'Unknown address'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.link, color: Colors.green),
                                onPressed: () => _connectToSavedPrinter(printer),
                                tooltip: "Connect",
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteSavedPrinter(printer.id!),
                                tooltip: "Delete",
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}