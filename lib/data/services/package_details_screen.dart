import 'package:flutter/material.dart';
import 'package:park_genie/DatabaseHelper.dart';
import 'package:intl/intl.dart';
import 'PackageData.dart';

class PackageDetailsScreen extends StatefulWidget {
  final DatabaseHelper dbHelper;

  const PackageDetailsScreen({Key? key, required this.dbHelper}) : super(key: key);

  @override
  _PackageDetailsScreenState createState() => _PackageDetailsScreenState();
}

class _PackageDetailsScreenState extends State<PackageDetailsScreen> {
  List<PackageData> _packages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPackageData();
  }

  Future<void> _loadPackageData() async {
    final packages = await widget.dbHelper.retrieveUserData();
    setState(() {
      _packages = packages;
      _isLoading = false;
    });
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return dateString; // Return original if parsing fails
    }
  }

  Widget _buildPackageTile(PackageData data) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.grey.shade50,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.card_membership, color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      data.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // User Information Section
              _buildSectionHeader("User Information", Icons.person),
              const SizedBox(height: 8),
              _buildInfoRow("User ID", data.userId, Icons.badge),
              _buildInfoRow("Name", data.name, Icons.person_outline),
              _buildInfoRow("Email", data.email, Icons.email_outlined),

              const SizedBox(height: 16),

              // Package Information Section
              _buildSectionHeader("Package Information", Icons.inventory_2),
              const SizedBox(height: 8),
              _buildInfoRow("Price", "₹${data.price.toStringAsFixed(2)}", Icons.currency_rupee),
              _buildInfoRow("Duration", data.duration, Icons.schedule),
              _buildInfoRow("Valid Till", _formatDate(data.packageValidTill), Icons.calendar_today),
              _buildInfoRow("Duration (Days)", "${data.durationInDays} days", Icons.date_range),
              _buildInfoRow("Max Entries/Day", "${data.maxEntriesPerDay} entries", Icons.login),

              const SizedBox(height: 16),

              // Status Section
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: data.isActive ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: data.isActive ? Colors.green.shade200 : Colors.red.shade200,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      data.isActive ? Icons.check_circle : Icons.cancel,
                      color: data.isActive ? Colors.green.shade700 : Colors.red.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      data.isActive ? "Active" : "Inactive",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: data.isActive ? Colors.green.shade700 : Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.black87,
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
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          "Package Details",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.grey.shade300,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Loading packages...", style: TextStyle(fontSize: 16)),
          ],
        ),
      )
          : _packages.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              "No package data found",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Check back later for available packages",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadPackageData,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: _packages.length,
          itemBuilder: (context, index) => _buildPackageTile(_packages[index]),
        ),
      ),
    );
  }
}