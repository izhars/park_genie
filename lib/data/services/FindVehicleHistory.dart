import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../DatabaseHelper.dart';
import 'package:intl/intl.dart'; // Add this package for date formatting

class FindVehicleHistoryScreen extends StatefulWidget {
  const FindVehicleHistoryScreen({super.key});

  @override
  _FindVehicleHistoryScreenState createState() => _FindVehicleHistoryScreenState();
}

class _FindVehicleHistoryScreenState extends State<FindVehicleHistoryScreen> {
  TextEditingController vehicleNumberController = TextEditingController();
  bool _isLoading = false;
  List<Map<String, dynamic>> _vehicleHistory = [];
  String errorMessage = '';

  // Fetch vehicle history from the database
  Future<void> _fetchVehicleHistory(String vehicleNumber) async {
    setState(() {
      _isLoading = true;
      errorMessage = '';
    });

    try {
      // Query the database for history related to the given vehicle number
      List<Map<String, dynamic>> vehicleHistory = await DatabaseHelper.instance.getVehicleHistory(vehicleNumber);

      setState(() {
        _vehicleHistory = vehicleHistory;
        _isLoading = false;
      });

      // Handle case if no records are found
      if (_vehicleHistory.isEmpty) {
        setState(() {
          errorMessage = 'No history found for this vehicle number';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        errorMessage = 'Failed to load vehicle history: ${e.toString()}';
      });
    }
  }

  // Format date string for better readability
  String _formatDateTime(String dateTimeStr) {
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return DateFormat('MMM dd, yyyy - hh:mm a').format(dateTime);
    } catch (e) {
      return dateTimeStr; // Return original if parsing fails
    }
  }

  // Display vehicle history in a list
  Widget _buildVehicleHistoryList() {
    if (_vehicleHistory.isEmpty && errorMessage.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Enter a vehicle number to search',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    if (errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 80, color: Colors.redAccent.shade200),
            const SizedBox(height: 16),
            Text(
              errorMessage,
              style: TextStyle(
                color: Colors.redAccent.shade200,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: _vehicleHistory.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final history = _vehicleHistory[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Row(
              children: [
                Icon(Icons.directions_car, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Entry Time:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Text(
                  _formatDateTime(history['entryTime']),
                  style: const TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.currency_rupee, size: 16, color: Colors.green.shade700),
                    Text(
                      ' Price: ₹${history['price']}',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.history,
                color: Theme.of(context).primaryColor,
              ),
            ),
            onTap: () {
              // Handle tap if needed (e.g., show more details)
            },
          ),
        );
      },
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
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).primaryColor.withOpacity(0.05),
              Colors.white,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: TextField(
                  controller: vehicleNumberController,
                  decoration: InputDecoration(
                    labelText: 'Vehicle Number',
                    hintText: 'e.g., KA-01-AB-1234',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).primaryColor,
                        width: 2,
                      ),
                    ),
                  ),
                  onChanged: (text) {
                    setState(() {
                      errorMessage = ''; // Clear error message when user starts typing
                    });
                  },
                  style: const TextStyle(fontSize: 16),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (value) {
                    if (value.trim().isNotEmpty) {
                      _fetchVehicleHistory(value.trim());
                    }
                  },
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  String vehicleNumber = vehicleNumberController.text.trim();
                  if (vehicleNumber.isNotEmpty) {
                    _fetchVehicleHistory(vehicleNumber);
                    FocusScope.of(context).unfocus(); // Hide keyboard
                  } else {
                    setState(() {
                      errorMessage = 'Please enter a valid vehicle number';
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white, backgroundColor: Theme.of(context).primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 3,
                ),
                child: _isLoading
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                )
                    : const Text('Search History'),
              ),
              const SizedBox(height: 24),
              Expanded(child: _buildVehicleHistoryList())
            ],
          ),
        ),
      ),
    );
  }
}