import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'WifiPrinterService.dart';

class PrinterSetupScreenWifi extends StatefulWidget {
  const PrinterSetupScreenWifi({super.key});

  @override
  _PrinterSetupScreenWifiState createState() => _PrinterSetupScreenWifiState();
}

class _PrinterSetupScreenWifiState extends State<PrinterSetupScreenWifi> {
  final TextEditingController _ipController = TextEditingController();
  final FocusNode _ipFocusNode = FocusNode();
  final WifiPrinterService _printerService = WifiPrinterService();

  bool _isConnecting = false;
  bool _isValidIP = false;
  bool _isScanningNetwork = false;
  String? _currentNetworkName;
  List<String> _discoveredPrinters = [];

  @override
  void initState() {
    super.initState();
    _ipController.addListener(_validateIP);
    _loadInitialState();

    // Listen for connection changes
    _printerService.connectionNotifier.addListener(_updateConnectionUI);
    _printerService.statusNotifier.addListener(_updateStatusUI);
  }

  Future<void> _loadInitialState() async {
    // Load network name
    await _fetchCurrentNetwork();

    // Check if printer is already connected and load saved IP
    await _checkInitialConnection();

    // Initial connection check
    if (_printerService.isConnected) {
      // If already connected, refresh the UI
      setState(() {});
    } else if (_printerService.connectedIpAddress != null) {
      // If we have a saved IP but not connected, try to reconnect
      await _printerService.connectToPrinter(_printerService.connectedIpAddress!);
      setState(() {});
    }
  }

  Future<void> _checkInitialConnection() async {
    if (_printerService.isConnected && _printerService.connectedIpAddress != null) {
      setState(() {
        _ipController.text = _printerService.connectedIpAddress!;
        _isValidIP = true;
      });
    } else {
      // Try to load saved default printer from database
      final defaultPrinter = await _printerService.getDefaultSavedPrinter();
      if (defaultPrinter != null && defaultPrinter.address != null) {
        setState(() {
          _ipController.text = defaultPrinter.address!;
          _validateIP();
        });
      }
    }
  }

  Future<void> _fetchCurrentNetwork() async {
    final networkName = await _printerService.getCurrentNetwork();
    if (mounted) {
      setState(() {
        _currentNetworkName = networkName ?? "Unknown Network";
      });
    }
  }

  void _validateIP() {
    final ipRegExp = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
    setState(() {
      _isValidIP = ipRegExp.hasMatch(_ipController.text);
    });
  }

  void _updateConnectionUI() {
    if (mounted) {
      setState(() {
        // This will trigger a UI rebuild when connection status changes
      });
    }
  }

  void _updateStatusUI() {
    // Show status messages to user
    final status = _printerService.statusNotifier.value;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(status),
            backgroundColor: _getStatusColor(status),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    });
  }

  Color _getStatusColor(String status) {
    if (status.contains("Connected") || status.contains("success")) {
      return Colors.green.shade700;
    } else if (status.contains("error") || status.contains("failed") || status.contains("Error")) {
      return Colors.red.shade700;
    } else if (status.contains("Scanning") || status.contains("Trying")) {
      return Colors.blue.shade700;
    } else {
      return Colors.orange.shade700;
    }
  }

  Future<void> _scanForPrinters() async {
    setState(() {
      _isScanningNetwork = true;
    });

    try {
      final printers = await _printerService.scanNetworkForPrinters();

      if (mounted) {
        setState(() {
          _discoveredPrinters = printers;
          _isScanningNetwork = false;
        });

        if (printers.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Found ${printers.length} printer(s)"),
              backgroundColor: Colors.green.shade700,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("No printers found on the network"),
              backgroundColor: Colors.orange.shade700,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanningNetwork = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error scanning network: $e"),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _connectPrinter() async {
    if (!_isValidIP) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Please enter a valid IP address"),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() {
      _isConnecting = true;
    });

    try {
      final success = await _printerService.connectToPrinter(_ipController.text);

      if (mounted) {
        setState(() {
          _isConnecting = false;
        });

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Connected to printer at ${_ipController.text}!"),
              backgroundColor: Colors.green.shade700,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Connection failed. Please try again."),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Connection failed: $e"),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _disconnectPrinter() async {
    setState(() {
      _isConnecting = true;
    });

    try {
      await _printerService.disconnectPrinter();

      if (mounted) {
        setState(() {
          _isConnecting = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Printer disconnected"),
            backgroundColor: Colors.orange.shade700,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error disconnecting: $e"),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _testPrint() async {
    if (!_printerService.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("No printer connected"),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() {
      _isConnecting = true;
    });

    try {
      await _printerService.printTest();

      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Print error: $e"),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _ipController.dispose();
    _ipFocusNode.dispose();
    _printerService.connectionNotifier.removeListener(_updateConnectionUI);
    _printerService.statusNotifier.removeListener(_updateStatusUI);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isPrinterConnected = _printerService.isConnected;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'WIFI Printer Setup',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color(0xFF1A73E8),
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Connection Status Card
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isPrinterConnected
                        ? [Colors.green.shade400, Colors.green.shade700]
                        : [Colors.red.shade300, Colors.red.shade500],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: isPrinterConnected
                          ? Colors.green.withOpacity(0.3)
                          : Colors.red.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: Icon(
                          isPrinterConnected ? Icons.print : Icons.print_disabled,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isPrinterConnected ? "Printer Connected" : "No Printer Connected",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isPrinterConnected
                                  ? "Connected to: ${_printerService.connectedIpAddress}"
                                  : "Connect to a printer to start printing",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Printer Animation
              SizedBox(
                height: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Lottie.asset(
                      'assets/animations/printer.json',
                      height: 200,
                      repeat: true,
                      fit: BoxFit.contain,
                    ),
                    if (isPrinterConnected)
                      Positioned(
                        bottom: 10,
                        right: 20,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.white, size: 16),
                              SizedBox(width: 4),
                              Text(
                                "Ready",
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
              ),
              const SizedBox(height: 16),

              // Network Info Card
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.wifi,
                      color: Colors.blue.shade700,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Current Network",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue.shade900,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            _currentNetworkName ?? "Loading network...",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.blue.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.refresh,
                        color: Colors.blue.shade700,
                      ),
                      onPressed: _fetchCurrentNetwork,
                      tooltip: "Refresh network",
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // IP Input Section
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Printer IP Address",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A73E8),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Enter the IP address of your network printer",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _ipController,
                        focusNode: _ipFocusNode,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.black87),
                        decoration: InputDecoration(
                          hintText: "e.g., 192.168.1.100",
                          hintStyle: TextStyle(color: Colors.grey[500]),
                          prefixIcon: Icon(
                            Icons.wifi,
                            color: _isValidIP ? Colors.green : Colors.blue,
                          ),
                          suffixIcon: _isValidIP
                              ? const Icon(Icons.check_circle, color: Colors.green)
                              : null,
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide(
                              color: _isValidIP ? Colors.green : Colors.blue,
                              width: 2,
                            ),
                          ),
                        ),
                        onChanged: (text) => _validateIP(),
                      ),
                      const SizedBox(height: 16),

                      // Action Buttons based on connection state
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isScanningNetwork ? null : _scanForPrinters,
                              icon: const Icon(Icons.search),
                              label: Text(_isScanningNetwork ? "Scanning..." : "Scan Network"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber.shade600,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.grey[400],
                                disabledForegroundColor: Colors.white70,
                                elevation: 2,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: isPrinterConnected ?
                            // Show disconnect button if connected
                            ElevatedButton.icon(
                              onPressed: _isConnecting ? null : _disconnectPrinter,
                              icon: const Icon(Icons.link_off),
                              label: const Text("Disconnect"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade600,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.grey[400],
                                disabledForegroundColor: Colors.white70,
                                elevation: 2,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                            ) :
                            // Show connect button if not connected
                            ElevatedButton.icon(
                              onPressed: _isConnecting || !_isValidIP ? null : _connectPrinter,
                              icon: const Icon(Icons.link),
                              label: Text(_isConnecting ? "Connecting..." : "Connect"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade600,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.grey[400],
                                disabledForegroundColor: Colors.white70,
                                elevation: 2,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Test Print button (only when connected)
                      if (isPrinterConnected) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isConnecting ? null : _testPrint,
                            icon: const Icon(Icons.print),
                            label: const Text("Test Print"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey[400],
                              disabledForegroundColor: Colors.white70,
                              elevation: 2,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                          ),
                        )
                      ],
                    ],
                  ),
                ),
              ),

              // Discovered Printers Section
              if (_discoveredPrinters.isNotEmpty) ...[
                const SizedBox(height: 24),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              "Discovered Printers",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A73E8),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                "${_discoveredPrinters.length} found",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.blue.shade800,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Printer List
                        for (int index = 0; index < _discoveredPrinters.length; index++) ...[
                          if (index > 0) const Divider(height: 1, thickness: 1),
                          _buildPrinterListItem(_discoveredPrinters[index]),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrinterListItem(String printerIp) {
    final bool isConnected = _printerService.isConnected &&
        _printerService.connectedIpAddress == printerIp;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: isConnected ? Colors.green.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isConnected ? Colors.green.shade300 : Colors.grey.shade200,
          width: isConnected ? 2 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isConnected ? Colors.green.shade100 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.print,
            color: isConnected ? Colors.green : Colors.grey[700],
            size: 24,
          ),
        ),
        title: Text(
          printerIp,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          isConnected ? "Connected" : "Available",
          style: TextStyle(
            fontSize: 14,
            color: isConnected ? Colors.green : Colors.grey[600],
          ),
        ),
        trailing: ElevatedButton.icon(
          icon: Icon(
            isConnected ? Icons.link_off : Icons.link,
            size: 20,
          ),
          label: Text(isConnected ? "Disconnect" : "Connect"),
          style: ElevatedButton.styleFrom(
            backgroundColor: isConnected ? Colors.red.shade100 : Colors.blue.shade100,
            foregroundColor: isConnected ? Colors.red.shade700 : Colors.blue.shade700,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: _isConnecting ? null : () {
            if (isConnected) {
              _disconnectPrinter();
            } else {
              _ipController.text = printerIp;
              _connectPrinter();
            }
          },
        ),
        onTap: _isConnecting ? null : () {
          if (isConnected) {
            _disconnectPrinter();
          } else {
            _ipController.text = printerIp;
            _connectPrinter();
          }
        },
      ),
    );
  }
}