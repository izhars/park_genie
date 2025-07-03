import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'PrinterType.dart';
import 'BluetoothPrinterService.dart';

// Make sure to add this to your main.dart
// final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();
// Then add to MaterialApp's navigatorObservers: [routeObserver]

class SavedPrintersScreen extends StatefulWidget {
  const SavedPrintersScreen({super.key});

  @override
  _SavedPrintersScreenState createState() => _SavedPrintersScreenState();
}

class _SavedPrintersScreenState extends State<SavedPrintersScreen>
    with SingleTickerProviderStateMixin, RouteAware {
  final BluetoothPrinterService _printerService = BluetoothPrinterService();
  List<PrinterType> _savedPrinters = [];
  bool _isLoading = true;

  // Add a reference to your RouteObserver
  // This should be imported from wherever you defined it (likely main.dart)
  final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

  @override
  void initState() {
    super.initState();
    _loadSavedPrinters();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to route changes
    final route = ModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  // This is called when returning to this screen
  @override
  void didPopNext() {
    super.didPopNext();
    // Refresh data when returning to this screen
    if (mounted) {
      _loadSavedPrinters();
    }
  }

  Future<void> _loadSavedPrinters() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final printers = await _printerService.getAllSavedPrinters();
      setState(() {
        _savedPrinters = printers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Error loading printers: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.blueAccent,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  Future<void> _setAsDefault(PrinterType printer) async {
    if (printer.id == null) return;

    try {
      final success = await _printerService.setDefaultPrinter(printer.id!);
      if (success) {
        _showSnackBar('${printer.name} set as default');
        await _loadSavedPrinters();
      } else {
        _showSnackBar('Failed to set as default', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    }
  }

  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) return 'Never';
    return DateFormat('MMM d, y - h:mm a').format(dateTime.toLocal());
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.print_disabled, size: 72, color: Colors.blueGrey),
          ),
          const SizedBox(height: 24),
          Text(
            'No Saved Printers',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey[800],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'You haven\'t saved any printers yet',
            style: TextStyle(
              fontSize: 16,
              color: Colors.blueGrey[600],
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);  // Go back to printer setup screen
            },
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Add New Printer', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          'Saved Printers',
          style: GoogleFonts.poppins(
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadSavedPrinters,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : _savedPrinters.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
        onRefresh: _loadSavedPrinters,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _savedPrinters.length,
          itemBuilder: (context, index) {
            final printer = _savedPrinters[index];
            return _buildPrinterCard(printer);
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pop(context); // Go back to printer setup screen
        },
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildPrinterCard(PrinterType printer) {
    final bool isDefault = printer.isDefault;
    final bool isActive = printer.isActive;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDefault ? Colors.blue : Colors.transparent,
          width: isDefault ? 2 : 0,
        ),
      ),
      child: Column(
        children: [
          // Status indicator
          Container(
            width: double.infinity,
            height: 6,
            decoration: BoxDecoration(
              color: isDefault
                  ? Colors.blue
                  : (isActive ? Colors.green : Colors.grey),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with icon and name
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDefault
                            ? Colors.blue.withOpacity(0.1)
                            : (isActive ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.print,
                        color: isDefault
                            ? Colors.blue
                            : (isActive ? Colors.green : Colors.grey),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            printer.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isActive ? Colors.green : Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isActive ? 'Active' : 'Inactive',
                                style: TextStyle(
                                  color: isActive ? Colors.green : Colors.grey,
                                ),
                              ),
                              if (isDefault) ...[
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'Default',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Details section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow(
                        label: 'Device Type',
                        value: printer.deviceType,
                        icon: Icons.devices,
                      ),
                      const Divider(height: 16),
                      _buildDetailRow(
                        label: 'Address',
                        value: printer.address ?? 'Unknown',
                        icon: Icons.bluetooth,
                      ),
                      const Divider(height: 16),
                      _buildDetailRow(
                        label: 'Last Connected',
                        value: _formatDate(printer.lastConnected),
                        icon: Icons.access_time,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Action button - simplified to just set default
                if (!isDefault)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.star, color: Colors.white),
                      label: const Text('Set as Default', style: TextStyle(color: Colors.white)),
                      onPressed: () => _setAsDefault(printer),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                if (isDefault)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Current Default'),
                      onPressed: null, // Disabled button
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.blueGrey),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blueGrey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}