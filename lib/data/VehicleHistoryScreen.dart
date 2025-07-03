import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../DatabaseHelper.dart';

class VehicleHistoryScreen extends StatefulWidget {
  final String vehicleNumber;

  const VehicleHistoryScreen({super.key, required this.vehicleNumber});

  @override
  _VehicleHistoryScreenState createState() => _VehicleHistoryScreenState();
}

class _VehicleHistoryScreenState extends State<VehicleHistoryScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _vehicleHistory = [];
  double _totalSpent = 0.0;
  int _totalVisits = 0;
  String _mostFrequentVehicleType = '';

  @override
  void initState() {
    super.initState();
    _fetchVehicleHistory();
  }

  Future<void> _fetchVehicleHistory() async {
    try {
      final history = await DatabaseHelper.instance.getVehicleHistory(widget.vehicleNumber);

      // Calculate summary statistics
      double totalSpent = 0.0;
      Map<String, int> vehicleTypeCounts = {};

      for (var entry in history) {
        if (entry['totalPrice'] != null && entry['isPaid'] == 1) {
          totalSpent += entry['totalPrice'] as double;
        }

        String vehicleType = entry['vehicleType'] as String;
        vehicleTypeCounts[vehicleType] = (vehicleTypeCounts[vehicleType] ?? 0) + 1;
      }

      // Find most frequent vehicle type
      String mostFrequent = '';
      int maxCount = 0;
      vehicleTypeCounts.forEach((type, count) {
        if (count > maxCount) {
          maxCount = count;
          mostFrequent = type;
        }
      });

      setState(() {
        _vehicleHistory = history;
        _totalSpent = totalSpent;
        _totalVisits = history.length;
        _mostFrequentVehicleType = mostFrequent;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar("Error loading history: $e");
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null) return 'N/A';
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return DateFormat('MMM dd, yyyy - hh:mm a').format(dateTime);
    } catch (e) {
      return dateTimeStr;
    }
  }

  String _formatDuration(int? hours) {
    if (hours == null) return 'N/A';
    return hours > 1 ? '$hours hours' : '$hours hour';
  }

  Widget _buildSummaryCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vehicle Summary',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem(
                  'Total Visits',
                  _totalVisits.toString(),
                  Icons.history,
                ),
                _buildSummaryItem(
                  'Total Spent',
                  '₹${_totalSpent.toStringAsFixed(2)}',
                  Icons.attach_money,
                ),
                _buildSummaryItem(
                  'Vehicle Type',
                  _mostFrequentVehicleType,
                  Icons.directions_car,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String title, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(
            icon,
            color: Theme.of(context).primaryColor,
            size: 28,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> entry) {
    final bool isActive = entry['exitTime'] == null;
    final isPaid = entry['isPaid'] == 1;

    Color statusColor = isActive
        ? Colors.blue
        : (isPaid ? Colors.green : Colors.orange);

    String status = isActive
        ? 'Active'
        : (isPaid ? 'Completed' : 'Unpaid');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: statusColor.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent, // This removes the divider lines
          colorScheme: Theme.of(context).colorScheme.copyWith(
            // This removes the splash effect on the arrows
            surface: Colors.transparent,
          ),
        ),
        child: ExpansionTile(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Bill #${entry['billNumber']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          subtitle: Text(
            _formatDateTime(entry['entryTime']),
            style: const TextStyle(fontSize: 12),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${isActive ? entry['price'] : (entry['totalPrice'] ?? 0).toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              Text(
                isActive ? 'Per Hour' : 'Total',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
          childrenPadding: EdgeInsets.zero, // Removes padding
          maintainState: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildDetailRow('Vehicle Type', entry['vehicleType'] ?? 'N/A'),
                  _buildDetailRow('Entry Time', _formatDateTime(entry['entryTime'])),
                  _buildDetailRow('Exit Time', entry['exitTime'] == null
                      ? 'Still Parked'
                      : _formatDateTime(entry['exitTime'])),
                  _buildDetailRow('Duration', entry['hoursSpent'] == null
                      ? 'N/A'
                      : _formatDuration(entry['hoursSpent'])),
                  _buildDetailRow('Rate', '₹${entry['price']} / hour'),
                  if (entry['exitTime'] != null)
                    _buildDetailRow('Total Amount', '₹${(entry['totalPrice'] ?? 0).toStringAsFixed(2)}'),
                  if (entry['notes'] != null && entry['notes'].toString().isNotEmpty)
                    _buildDetailRow('Notes', entry['notes']),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Vehicle History',
          style: GoogleFonts.poppins(
            color: Colors.white,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              widget.vehicleNumber,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
              _fetchVehicleHistory();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Loading vehicle history..."),
          ],
        ),
      )
          : _vehicleHistory.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.no_crash,
              size: 72,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              "No history found",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "This vehicle has not been parked here before",
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _fetchVehicleHistory,
        child: ListView(
          children: [
            _buildSummaryCard(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Parking History',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ..._vehicleHistory.map((entry) => _buildHistoryCard(entry)),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}