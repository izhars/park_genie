import 'dart:io';

import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:park_genie/printer/BluetoothPrinterService.dart';
import 'package:park_genie/printer/PrinterDatabaseHelper.dart';
import 'package:park_genie/printer/WifiPrinterService.dart';
import 'DatabaseHelper.dart';
import 'data/VehicleHistoryScreen.dart';
import 'dart:async';
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class TransactionHistory extends StatefulWidget {

  const TransactionHistory({
    super.key,
  });

  @override
  _TransactionHistoryState createState() => _TransactionHistoryState();
}

class _TransactionHistoryState extends State<TransactionHistory> {
  final BluetoothPrinterService _printerService = BluetoothPrinterService(); // Printer service instance

  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;
  String _filterStatus = 'All'; // 'All', 'Paid', 'Unpaid'
  DateTime? _startDate;
  DateTime? _endDate;
  bool isConnected = false;
  final BlueThermalPrinter printer = BlueThermalPrinter.instance;

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
    _checkPrinterConnection();
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


  Future<void> _fetchTransactions() async {
    final data = await DatabaseHelper.instance.getTransactionHistory();
    // Print data to log
    for (var transaction in data) {
      print(transaction);
    }
    setState(() {
      _transactions = data;
      _isLoading = false;
    });
  }

  List<Map<String, dynamic>> get _filteredTransactions {
    List<Map<String, dynamic>> filteredList = _transactions;

    // Apply status filter
    if (_filterStatus != 'All') {
      bool isPaid = _filterStatus == 'Paid';
      filteredList = filteredList.where((tx) => (tx['isPaid'] == 1) == isPaid).toList();
    }

    // Apply date filter
    if (_startDate != null && _endDate != null) {
      filteredList = filteredList.where((tx) {
        // Parse the entryTime string to DateTime
        // Make sure we handle potential format issues
        DateTime? entryDate;
        try {
          entryDate = DateTime.parse(tx['entryTime']);
        } catch (e) {
          print('Error parsing date: ${tx['entryTime']} - $e');
          return false;
        }

        // Set the time components to 00:00:00 for start date to include the entire day
        final startComparison = DateTime(
          _startDate!.year,
          _startDate!.month,
          _startDate!.day,
        );

        // Set the time components to 23:59:59 for end date to include the entire day
        final endComparison = DateTime(
            _endDate!.year,
            _endDate!.month,
            _endDate!.day,
            23, 59, 59
        );

        // Check if entry date is within range (inclusive)
        return entryDate.isAtSameMomentAs(startComparison) ||
            entryDate.isAtSameMomentAs(endComparison) ||
            (entryDate.isAfter(startComparison) && entryDate.isBefore(endComparison));
      }).toList();
    }

    return filteredList;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          'Transaction History',
          style: GoogleFonts.poppins(
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
              _fetchTransactions();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterSection(),
          _buildDateFilterSection(),
          _buildSummaryCard(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredTransactions.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 70, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No transactions found',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
                : _buildTransactionList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).primaryColor.withOpacity(0.05),
      child: Row(
        children: [
          const Text(
            'Filter: ',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('All'),
            selected: _filterStatus == 'All',
            onSelected: (selected) {
              if (selected) {
                setState(() {
                  _filterStatus = 'All';
                });
              }
            },
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('Paid'),
            selected: _filterStatus == 'Paid',
            onSelected: (selected) {
              if (selected) {
                setState(() {
                  _filterStatus = 'Paid';
                });
              }
            },
            selectedColor: Colors.green[100],
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('Unpaid'),
            selected: _filterStatus == 'Unpaid',
            onSelected: (selected) {
              if (selected) {
                setState(() {
                  _filterStatus = 'Unpaid';
                });
              }
            },
            selectedColor: Colors.red[100],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    // Calculate summary data
    int totalTransactions = _filteredTransactions.length;
    int paidTransactions = _filteredTransactions.where((tx) => tx['isPaid'] == 1).length;
    int totalAmount = _filteredTransactions.fold(0, (sum, tx) {
      return sum + (tx['totalPrice'] != null ? (tx['totalPrice'] as num).toInt() : 0);
    });

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _summaryItem(
                'Total',
                totalTransactions.toString(),
                Icons.receipt_long,
                Colors.blue,
              ),
              _summaryItem(
                'Paid',
                paidTransactions.toString(),
                Icons.check_circle,
                Colors.green,
              ),
              _summaryItem(
                'Amount',
                '₹${totalAmount.toStringAsFixed(2)}',
                Icons.currency_rupee,
                Colors.purple,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateFilterSection() {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Date Range',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: _startDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: ColorScheme.light(
                                primary: Theme.of(context).primaryColor,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (pickedDate != null) {
                        setState(() {
                          _startDate = pickedDate;
                          // If end date is before start date, set end date to start date
                          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
                            _endDate = pickedDate;
                          }
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, size: 18, color: Theme.of(context).primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            _startDate == null
                                ? 'Start Date'
                                : DateFormat('MMM dd, yyyy').format(_startDate!),
                            style: TextStyle(
                              color: _startDate == null ? Colors.grey : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Container(
                    width: 24,
                    height: 2,
                    color: Colors.grey.shade400,
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      if (_startDate == null) {
                        // If start date is not set, show a message
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select a start date first'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                        return;
                      }

                      DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: _endDate ?? _startDate ?? DateTime.now(),
                        firstDate: _startDate ?? DateTime(2000),
                        lastDate: DateTime.now(),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: ColorScheme.light(
                                primary: Theme.of(context).primaryColor,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (pickedDate != null) {
                        setState(() {
                          _endDate = pickedDate;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, size: 18, color: Theme.of(context).primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            _endDate == null
                                ? 'End Date'
                                : DateFormat('MMM dd, yyyy').format(_endDate!),
                            style: TextStyle(
                              color: _endDate == null ? Colors.grey : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_startDate != null || _endDate != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _startDate = null;
                      _endDate = null;
                    });
                  },
                  icon: const Icon(Icons.clear, size: 18),
                  label: const Text('Clear'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  ),
                ),
              ),
            if (_startDate != null && _endDate != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Selected range: ${DateFormat('MMM dd').format(_startDate!)} - ${DateFormat('MMM dd').format(_endDate!)} (${_endDate!.difference(_startDate!).inDays + 1} days)',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredTransactions.length,
      itemBuilder: (context, index) {
        final transaction = _filteredTransactions[index];
        final entryDateTime = DateTime.parse(transaction['entryTime']);
        final formattedDate = DateFormat('MMM dd, yyyy').format(entryDateTime);
        final formattedTime = DateFormat('hh:mm a').format(entryDateTime);
        final billNumber = transaction['billNumber'];
        final vehicleType = transaction['vehicleType'];
        final vehicleNo = transaction['vehicleNo'];
        final price = transaction['price'];
        final totalPrice = transaction['totalPrice'];
        final isPaid = transaction['isPaid'] == 1;

        // Get vehicle icon based on vehicle type
        IconData vehicleIcon = Icons.directions_car;
        if (vehicleType.toLowerCase().contains('bike') ||
            vehicleType.toLowerCase().contains('motorcycle')) {
          vehicleIcon = Icons.motorcycle;
        } else if (vehicleType.toLowerCase().contains('truck')) {
          vehicleIcon = Icons.local_shipping;
        } else if (vehicleType.toLowerCase().contains('bus')) {
          vehicleIcon = Icons.directions_bus;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isPaid ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              // Show transaction details
              _showTransactionDetails(transaction);
            },
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: isPaid ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      vehicleIcon,
                      color: isPaid ? Colors.green : Colors.red,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start, // Align items to the start
                          children: [
                            Text(
                              vehicleNo,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 8), // Add space between texts
                            Text(
                              '#$billNumber', // Adding hashtag before billNumber
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.grey, // Gray color
                              ),
                            ),
                          ],
                        ),
                        Text(
                          vehicleType,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 12,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              formattedDate,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.access_time,
                              size: 12,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              formattedTime,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${(totalPrice == null || totalPrice == 0)
                            ? (price?.isNotEmpty == true ? price : '0')
                            : totalPrice.toString()}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isPaid ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isPaid ? 'Paid' : 'Unpaid',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isPaid ? Colors.green : Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showTransactionDetails(Map<String, dynamic> transaction) {
    final entryDateTime = DateTime.parse(transaction['entryTime']);
    // Don't parse exitTime unconditionally
    final formattedEntryDate = DateFormat('MMMM dd, yyyy').format(entryDateTime);
    final formattedEntryTime = DateFormat('hh:mm a').format(entryDateTime);
    final vehicleType = transaction['vehicleType'];
    final vehicleNo = transaction['vehicleNo'];
    final billNumber = transaction['billNumber'];
    final price = transaction['price'];
    final totalPrice = transaction['totalPrice'];
    final isPaid = transaction['isPaid'] == 1;

    // For paid transactions only
    String? formattedExitDate;
    String? formattedExitTime;
    String? hoursSpent;
    DateTime? exitDateTime;

    if (isPaid && transaction['exitTime'] != null && transaction['exitTime'].toString().isNotEmpty) {
      exitDateTime = DateTime.parse(transaction['exitTime']);
      formattedExitDate = DateFormat('MMMM dd, yyyy').format(exitDateTime);
      formattedExitTime = DateFormat('hh:mm a').format(exitDateTime);

      // Calculate hours spent
      final difference = exitDateTime.difference(entryDateTime);
      final hours = difference.inHours;
      final minutes = difference.inMinutes % 60;
      hoursSpent = '$hours hr${hours != 1 ? 's' : ''} $minutes min${minutes != 1 ? 's' : ''}';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 0,
            ),
          ],
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          top: 24,
          left: 24,
          right: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Modal Sheet Handle
            Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),

            // Header with transaction ID and status indicator
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: isPaid ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPaid ? Icons.check_circle : Icons.pending_actions,
                        size: 16,
                        color: isPaid ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isPaid ? 'PAID' : 'PENDING',
                        style: TextStyle(
                          color: isPaid ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Expanded(
                  child: Text(
                    'Transaction Details',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  splashRadius: 20,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Vehicle information card
            Container(
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => VehicleHistoryScreen(vehicleNumber: vehicleNo),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            vehicleType.toLowerCase().contains('bike') ? Icons.motorcycle : Icons.directions_car,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vehicleNo,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              vehicleType,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Time details card with all info in one card for paid transactions
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Entry details
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.login,
                          color: Colors.green,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Entry',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '$formattedEntryDate, $formattedEntryTime',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Duration for paid transactions
                  if (isPaid && hoursSpent != null) ...[
                    const SizedBox(height: 16),
                    Divider(height: 1, color: Colors.grey.withOpacity(0.2)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.indigo.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.timer,
                            color: Colors.indigo,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Duration',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              hoursSpent,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.indigo,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],

                  // Exit details for paid transactions
                  if (isPaid && formattedExitDate != null && formattedExitTime != null) ...[
                    const SizedBox(height: 16),
                    Divider(height: 1, color: Colors.grey.withOpacity(0.2)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.logout,
                            color: Colors.red,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Exit',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '$formattedExitDate, $formattedExitTime',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Payment details card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.currency_rupee,
                      color: Colors.purple,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Amount',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '₹$price',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.purple,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Action button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: isPaid ? Colors.grey.shade200 : Colors.green,
                ),
                onPressed: isPaid
                    ? null
                    : () {
                  // Mark as paid functionality would go here
                  Navigator.pop(context);
                },
                child: Text(
                  isPaid ? 'Transaction Completed' : 'Mark as Paid',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isPaid ? Colors.grey.shade600 : Colors.white,
                  ),
                ),
              ),
            ),

            // Print receipt option (for paid transactions)
            if (isPaid) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                icon: const Icon(Icons.receipt_long, size: 16),
                label: const Text('Print Receipt'),
                onPressed: () {
                  _printTransactionReceipt(transaction);
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _printTransactionReceipt(Map<String, dynamic> transaction) async {
    try {
      // Show initial message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 2),
          content: Text("Preparing to print..."),
        ),
      );

      // Get default printer
      final connectedPrinter = await PrinterDatabaseHelper().getDefaultPrinterType();
      Navigator.of(context).pop(); // Close loading if any dialog shown

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
      debugPrint("🖨️ Default printer type: $defaultPrinterType");

      // Transaction details
      final billNumber = transaction['billNumber'];
      final entryDateTime = DateTime.parse(transaction['entryTime']);
      final formattedEntryTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(entryDateTime);
      final vehicleType = transaction['vehicleType'];
      final vehicleNo = transaction['vehicleNo'];
      final price = transaction['price'].toString();
      final totalPrice = transaction['totalPrice'].toString();
      final isPaid = transaction['isPaid'] == 1 ? 'Paid' : 'Unpaid';

      DateTime? exitDateTime;
      String? exitTime;
      if (transaction['exitTime'] != null && transaction['exitTime'].toString().isNotEmpty) {
        exitDateTime = DateTime.parse(transaction['exitTime']);
        exitTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(exitDateTime);
      }

      // Connectivity checks
      bool isDefaultConnected = false;
      bool isAlternateConnected = false;
      String alternatePrinterType = '';

      if (defaultPrinterType.toLowerCase() == 'thermal' || defaultPrinterType.toLowerCase() == 'bluetooth') {
        bool? bluetoothConnected = await printer.isConnected;
        isDefaultConnected = bluetoothConnected ?? false;

        // Fallback: Check WiFi
        final wifiPrinterService = WifiPrinterService();
        isAlternateConnected = wifiPrinterService.isConnected;
        alternatePrinterType = 'wifi';
      } else if (defaultPrinterType.toLowerCase() == 'wifi') {
        final wifiPrinterService = WifiPrinterService();
        isDefaultConnected = wifiPrinterService.isConnected;

        // Fallback: Check Bluetooth
        bool? bluetoothConnected = await printer.isConnected;
        isAlternateConnected = bluetoothConnected ?? false;
        alternatePrinterType = 'thermal';
      }

      // Use default printer
      if (isDefaultConnected) {
        debugPrint("✅ Printing with default $defaultPrinterType printer");

        if (defaultPrinterType.toLowerCase() == 'wifi') {
          await _printReceiptToWifi(
              billNumber, formattedEntryTime, exitTime, vehicleType, vehicleNo, price, totalPrice, isPaid);
        } else {
          await _printReceiptToBluetooth(
              billNumber, formattedEntryTime, exitTime, vehicleType, vehicleNo, price, totalPrice, isPaid);
        }
      }

      // Use fallback printer if default not connected
      else if (isAlternateConnected) {
        debugPrint("⚠️ Default printer not connected. Falling back to $alternatePrinterType printer");

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Default printer not connected. Using $alternatePrinterType printer instead."),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );

        if (alternatePrinterType.toLowerCase() == 'wifi') {
          await _printReceiptToWifi(
              billNumber, formattedEntryTime, exitTime, vehicleType, vehicleNo, price, totalPrice, isPaid);
        } else {
          await _printReceiptToBluetooth(
              billNumber, formattedEntryTime, exitTime, vehicleType, vehicleNo, price, totalPrice, isPaid);
        }
      }

      // No printers connected
      else {
        debugPrint("❌ No printer connected");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("No printer is connected!"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint("🛑 Error preparing to print: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error preparing to print: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }


  Future<void> _printReceiptToBluetooth(
      String billNumber,
      String entryTime,
      String? exitTime,
      String vehicleType,
      String vehicleNo,
      String price,
      String totalPrice,
      String isPaid, // 🆕 Add this argument
      ) async {
    if (!(await printer.isConnected ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Bluetooth printer not connected!"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Printing receipt...')),
      );

      final entryDateTime = DateTime.parse(entryTime);
      final formattedEntryDate = DateFormat('MMM dd, yyyy').format(entryDateTime);
      final formattedEntryTime = DateFormat('hh:mm a').format(entryDateTime);

      String? formattedExitDate;
      String? formattedExitTime;
      String? hoursSpent;

      if (exitTime != null) {
        final exitDateTime = DateTime.parse(exitTime);
        formattedExitDate = DateFormat('MMM dd, yyyy').format(exitDateTime);
        formattedExitTime = DateFormat('hh:mm a').format(exitDateTime);
        final difference = exitDateTime.difference(entryDateTime);
        final hours = difference.inHours;
        final minutes = difference.inMinutes % 60;
        hoursSpent = '$hours hr${hours != 1 ? 's' : ''} $minutes min${minutes != 1 ? 's' : ''}';
      }

      // Fetch user/company info
      final user = await DatabaseHelper.instance.getUser();
      final companyName = user?['companyName'] ?? 'Your Company';
      final companyAddress = user?['address'] ?? 'Your Address';
      final logoPath = user?['logoPath'];
      final footerText = user?['footerText']?.toString().trim();

      // Parse and format entry time
      final parsedTime = DateTime.tryParse(entryTime) ?? DateTime.now();

      // Determine which logo to use
      String imagePath;
      if (logoPath != null && File(logoPath).existsSync()) {
        // Use custom logo
        final bytes = await File(logoPath).readAsBytes();
        final img.Image? originalImage = img.decodeImage(bytes);

        if (originalImage != null) {
          final resized = img.copyResize(originalImage, width: 80);
          final bwImage = img.grayscale(resized);

          final whiteBg = img.Image(width: bwImage.width, height: bwImage.height);
          img.fill(whiteBg, color: img.ColorRgb8(255, 255, 255));
          img.compositeImage(whiteBg, bwImage);

          final tempDir = await getTemporaryDirectory();
          imagePath = '${tempDir.path}/custom_logo_print.png';
          File(imagePath)..writeAsBytesSync(img.encodePng(whiteBg));
        } else {
          imagePath = await _prepareDefaultLogo();
        }
      } else {
        imagePath = await _prepareDefaultLogo();
      }

      await printer.printImage(imagePath); // Logo
      await printer.printCustom(companyName, 1, 1);    // Centered, medium
      await printer.printCustom(companyAddress, 1, 1); // Centered, small
      await _printerService.printer.printCustom("PARKING RECEIPT", 1, 1);

      await _printerService.printer.printCustom("-" * 32, 1, 1);
      await _printerService.printer.printCustom("Bill No: #$billNumber", 1, 1); // ✅ Fixed line
      await _printerService.printer.printCustom("-" * 32, 1, 1);

      await _printerService.printer.printLeftRight("Vehicle No:", vehicleNo, 1);
      await _printerService.printer.printLeftRight("Vehicle Type:", vehicleType, 1);
      await _printerService.printer.printLeftRight("Entry Date:", formattedEntryDate, 1);
      await _printerService.printer.printLeftRight("Entry Time:", formattedEntryTime, 1);

      if (formattedExitDate != null && formattedExitTime != null) {
        await _printerService.printer.printLeftRight("Exit Date:", formattedExitDate, 1);
        await _printerService.printer.printLeftRight("Exit Time:", formattedExitTime, 1);
        if (hoursSpent != null) {
          await _printerService.printer.printLeftRight("Duration:", hoursSpent, 1);
        }
      }

      await _printerService.printer.printCustom("-" * 32, 1, 1);

      await _printerService.printer.printCustom("TOTAL AMOUNT", 1, 1); // 🛠️ Small text now
      await _printerService.printer.printCustom("Rs. $totalPrice", 2, 1); // slightly bigger
      await _printerService.printer.printCustom("-" * 32, 1, 1);

      await _printerService.printer.printCustom("Payment Status: $isPaid", 1, 1); // 🆕 Payment status line

      await _printerService.printer.printCustom("-" * 32, 1, 1);

      // Get footerText or use default
      final footerMessage = (footerText == null || footerText.isEmpty)
          ? "Thank you for your visit"  // Default fallback
          : footerText;

      // Print the footer
      await printer.printCustom(footerMessage, 1, 1);
      await printer.printCustom("Drive safe", 1, 1);
      await _printerService.printer.printNewLine();
      await _printerService.printer.printNewLine();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Receipt printed successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint("🛑 Bluetooth printing error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Printing failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _printReceiptToWifi(
      String billNumber,
      String entryTime,
      String? exitTime,
      String vehicleType,
      String vehicleNo,
      String price,
      String totalPrice,
      String isPaid
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

      // Verify connection
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

      // Parse and format entry time
      final entryDateTime = DateTime.parse(entryTime);
      final formattedEntryDate = DateFormat('MMM dd, yyyy').format(entryDateTime);
      final formattedEntryTime = DateFormat('hh:mm a').format(entryDateTime);

      // Format exit time if available
      String? formattedExitDate;
      String? formattedExitTime;
      String? hoursSpent;

      if (exitTime != null) {
        final exitDateTime = DateTime.parse(exitTime);
        formattedExitDate = DateFormat('MMM dd, yyyy').format(exitDateTime);
        formattedExitTime = DateFormat('hh:mm a').format(exitDateTime);

        // Calculate duration
        final difference = exitDateTime.difference(entryDateTime);
        final hours = difference.inHours;
        final minutes = difference.inMinutes % 60;
        hoursSpent = '$hours hr${hours != 1 ? 's' : ''} $minutes min${minutes != 1 ? 's' : ''}';
      }

      List<int> bytes = [];

      // Fetch user info for company name, address, and logo
      final user = await DatabaseHelper.instance.getUser();
      final companyName = user?['companyName'] ?? 'Your Company';
      final companyAddress = user?['address'] ?? 'Your Address';
      final logoPath = user?['logoPath'];
      final footerText = user?['footerText'];

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

      bytes += generator.setGlobalCodeTable('CP1252');
      bytes += generator.setStyles(const PosStyles(align: PosAlign.center));
      bytes += generator.text(companyName, styles: const PosStyles(bold: true));
      bytes += generator.text(companyAddress);
      bytes += generator.text("PARKING RECEIPT");
      bytes += generator.hr();
      bytes += generator.text("Bill No: #$billNumber");
      bytes += generator.hr();

      // Continue with the receipt details...
      bytes += generator.setStyles(const PosStyles(align: PosAlign.left));

      bytes += generator.row([
        PosColumn(
          text: 'Vehicle Type:',
          width: 6,
          styles: const PosStyles(align: PosAlign.left),
        ),
        PosColumn(
          text: vehicleType,
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);

      bytes += generator.row([
        PosColumn(
          text: 'Vehicle No:',
          width: 6,
          styles: const PosStyles(align: PosAlign.left),
        ),
        PosColumn(
          text: vehicleNo,
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);

      bytes += generator.row([
        PosColumn(
          text: 'Entry Date:',
          width: 6,
          styles: const PosStyles(align: PosAlign.left),
        ),
        PosColumn(
          text: formattedEntryDate,
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);

      bytes += generator.row([
        PosColumn(
          text: 'Entry Time:',
          width: 6,
          styles: const PosStyles(align: PosAlign.left),
        ),
        PosColumn(
          text: formattedEntryTime,
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);

      if (formattedExitDate != null && formattedExitTime != null) {
        bytes += generator.row([
          PosColumn(
            text: 'Exit Date:',
            width: 6,
            styles: const PosStyles(align: PosAlign.left),
          ),
          PosColumn(
            text: formattedExitDate,
            width: 6,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]);

        bytes += generator.row([
          PosColumn(
            text: 'Exit Time:',
            width: 6,
            styles: const PosStyles(align: PosAlign.left),
          ),
          PosColumn(
            text: formattedExitTime,
            width: 6,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]);

        if (hoursSpent != null) {
          bytes += generator.row([
            PosColumn(
              text: 'Duration:',
              width: 6,
              styles: const PosStyles(align: PosAlign.left),
            ),
            PosColumn(
              text: hoursSpent,
              width: 6,
              styles: const PosStyles(align: PosAlign.right),
            ),
          ]);
        }
      }

      bytes += generator.row([
        PosColumn(
          text: 'Rate:',
          width: 6,
          styles: const PosStyles(align: PosAlign.left),
        ),
        PosColumn(
          text: "Rs. $price/hr",
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);

      bytes += generator.hr(); // Horizontal line
      bytes += generator.setStyles(const PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ));
      bytes += generator.text("TOTAL AMOUNT");
      bytes += generator.text("Rs. $totalPrice");
      bytes += generator.hr(); // Horizontal line

      bytes += generator.setStyles(const PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size1,
        width: PosTextSize.size1,
      ));
      bytes += generator.text("Payment Status: $isPaid");
      bytes += generator.hr(); // Horizontal line

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

      final socket = await Socket.connect(ipAddress, 9100, timeout: const Duration(seconds: 5));
      debugPrint("🖨️ Socket connected successfully");

      debugPrint("🖨️ Sending ${bytes.length} bytes to printer");
      socket.add(bytes);
      await socket.flush();
      await socket.close();

      debugPrint("✅ Print job completed successfully");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Receipt printed successfully"),
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
}