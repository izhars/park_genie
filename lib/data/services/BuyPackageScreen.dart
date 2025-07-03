import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import '../../DatabaseHelper.dart';
import 'ApiConfig.dart';
import 'Package.dart';
import 'PackageData.dart';
import 'PurchaseSuccessScreen.dart';

class BuyPackageScreen extends StatefulWidget {
  final DatabaseHelper dbHelper;

  const BuyPackageScreen({super.key, required this.dbHelper});

  @override
  State<BuyPackageScreen> createState() => _BuyPackageScreenState();
}

class _BuyPackageScreenState extends State<BuyPackageScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int selectedIndex = 0;
  List<Package> packages = [];
  bool isLoading = true;
  bool isPurchasing = false;
  PackageData? userData;
  bool hasActiveSubscription = false;
  String? activePackageId;
  String? validTill;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _loadUserData().then((_) => _fetchPackages());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final data = await widget.dbHelper.retrieveUserData();
      if (!mounted) return;

      setState(() {
        userData = data.isNotEmpty ? data.first : null;
        if (userData != null &&
            userData!.title != "No Package" &&
            userData!.packageValidTill != "N/A") {
          hasActiveSubscription = true;
          validTill = userData!.packageValidTill;
        } else {
          hasActiveSubscription = false;
        }
      });
    } catch (e) {
      print("Error loading user data: $e");
      if (!mounted) return;
      setState(() {
        hasActiveSubscription = false;
      });
    }
  }

  Future<void> _fetchPackages() async {
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/packages'));
      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        if (!mounted) return;

        setState(() {
          packages = jsonData.map((json) => Package.fromJson(json)).toList();
          if (hasActiveSubscription && userData != null) {
            final activeIndex = packages.indexWhere((pkg) => pkg.title == userData!.title);
            if (activeIndex != -1) {
              selectedIndex = activeIndex;
              activePackageId = packages[activeIndex].id;
            }
          }
          isLoading = false;
        });
        _controller.forward();
      } else {
        throw Exception('Failed to load packages');
      }
    } catch (e) {
      print("Error fetching packages: $e");
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      _showErrorDialog('Failed to load packages. Please check your connection and try again.');
    }
  }

  Future<void> _purchasePackage(String userId, String packageId) async {
    if (!mounted) return;
    setState(() => isPurchasing = true);

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString("token");

      if (token == null || token.isEmpty) {
        throw Exception("Token not found. Please log in again.");
      }

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/packages/buy'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          "userId": userId,
          "packageId": packageId,
        }),
      );

      if (!mounted) return;
      setState(() => isPurchasing = false);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final packageList = responseData['packageList'];

        if (packageList != null && packageList.isNotEmpty) {
          final purchasedPackage = packageList[0];
          final package = packages.firstWhere((pkg) => pkg.title == purchasedPackage['title']);

          final packageDataObj = PackageData(
            userId: userId,
            name: purchasedPackage['name'] ?? prefs.getString("userName") ?? "Guest",
            email: purchasedPackage['email'] ?? userData?.email ?? "",
            title: purchasedPackage['title'] ?? package.title,
            price: purchasedPackage['price']?.toDouble() ?? package.price,
            duration: purchasedPackage['duration'] ?? package.duration,
            packageValidTill: DateTime.now()
                .add(Duration(days: purchasedPackage['durationInDays'] ?? package.durationInDays))
                .toIso8601String(),
            durationInDays: purchasedPackage['durationInDays'] ?? package.durationInDays,
            maxEntriesPerDay: purchasedPackage['maxEntriesPerDay'] ?? package.maxEntriesPerDay ?? 0,
            isActive: purchasedPackage['isActive'] ?? true,
          );

          await widget.dbHelper.saveUserData([packageDataObj]);

          if (!mounted) return;
          setState(() {
            userData = packageDataObj;
            hasActiveSubscription = true;
            activePackageId = packageId;
            validTill = packageDataObj.packageValidTill;
          });

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => PurchaseSuccessScreen(
                    packageTitle: packageDataObj.title,
                    validTill: packageDataObj.packageValidTill,
                    color: package.getColor(),
                    dbHelper: widget.dbHelper),
              ),
            );
          }
        } else {
          throw Exception('No package data returned from server');
        }
      } else {
        throw Exception('Failed to purchase package: ${response.body}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isPurchasing = false);
      _showErrorDialog('Failed to purchase package. Please try again later.');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text("Error", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(message, style: GoogleFonts.roboto(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK", style: GoogleFonts.poppins(color: Theme.of(context).primaryColor)),
          ),
        ],
      ),
    );
  }

  int _calculateDaysRemaining() {
    if (validTill == null) return 0;
    try {
      final validDate = DateTime.parse(validTill!);
      final now = DateTime.now();
      return validDate.difference(now).inDays;
    } catch (e) {
      return 0;
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return "N/A";
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  Widget _buildActiveSubscriptionUI() {
    final activePackage = packages.firstWhere(
          (pkg) => pkg.title == userData?.title,
      orElse: () => packages[0],
    );
    final daysRemaining = _calculateDaysRemaining();
    final color = activePackage.getColor();

    return FadeTransition(
      opacity: _animation,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, color: color, size: 32, semanticLabel: 'Active'),
                        const SizedBox(width: 8),
                        Text(
                          'Active Subscription',
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      userData!.title,
                      style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '₹${userData!.price.toStringAsFixed(2)}',
                      style: GoogleFonts.roboto(fontSize: 18, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 8, spreadRadius: 2),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildInfoRow('Valid Till:', _formatDate(validTill), color),
                          const SizedBox(height: 12),
                          _buildInfoRow('Days Remaining:', '$daysRemaining days', color),
                          const SizedBox(height: 12),
                          _buildInfoRow('Max Entries/Day:', '${userData!.maxEntriesPerDay}', color),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(thickness: 1, height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Upgrade Your Package',
              style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: packages.length,
              itemBuilder: (context, index) {
                final package = packages[index];
                final isActive = activePackageId == package.id;
                final isUpgrade = !isActive && package.price > userData!.price;

                return _buildPackageCard(index, package, isActive, isUpgrade);
              },
            ),
          ),
          _buildActionButton(),
        ],
      ),
    );
  }

  Widget _buildPackageSelectionUI() {
    return FadeTransition(
      opacity: _animation,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Select a Package',
              style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: packages.length,
              itemBuilder: (context, index) {
                final package = packages[index];
                return _buildPackageCard(index, package, false, false);
              },
            ),
          ),
          _buildActionButton(),
        ],
      ),
    );
  }

  Widget _buildPackageCard(int index, Package package, bool isActive, bool isUpgrade) {
    final isSelected = selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => selectedIndex = index),
      child: Card(
        elevation: isSelected ? 8 : 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
        color: isActive
            ? Colors.green.shade50
            : isUpgrade
            ? Colors.blue.shade50
            : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          package.title,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? package.getColor() : null,
                          ),
                        ),
                        if (isActive) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.check_circle, color: Colors.green, size: 20),
                        ] else if (isUpgrade) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.upgrade, color: Colors.blue, size: 20),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "₹${package.price} for ${package.duration}",
                      style: GoogleFonts.roboto(fontSize: 16, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Max Entries/Day: ${package.maxEntriesPerDay}",
                      style: GoogleFonts.roboto(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              if (isSelected && !isActive)
                Icon(Icons.radio_button_checked, color: package.getColor(), size: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.roboto(fontSize: 16, color: Colors.grey[700]),
        ),
        Text(
          value,
          style: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.w600, color: color),
        ),
      ],
    );
  }

  Widget _buildActionButton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ElevatedButton(
        onPressed: isPurchasing || (hasActiveSubscription && activePackageId == packages[selectedIndex].id)
            ? null
            : () {
          if (userData != null) {
            _purchasePackage(userData!.userId, packages[selectedIndex].id);
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 16),
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 5,
          shadowColor: Theme.of(context).primaryColor.withOpacity(0.4),
        ),
        child: isPurchasing
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
          hasActiveSubscription && activePackageId == packages[selectedIndex].id
              ? "Current Package"
              : hasActiveSubscription
              ? "Upgrade Package"
              : "Buy Now",
          style: GoogleFonts.poppins(fontSize: 16, color: Colors.white),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Theme.of(context).primaryColor.withOpacity(0.1), Colors.white],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          hasActiveSubscription ? "Your Subscription" : "Buy a Package",
          style: GoogleFonts.poppins(color: Colors.white),
        ),
      ),
      body: packages.isEmpty
          ? Center(
        child: Text(
          "No packages available at the moment.",
          style: GoogleFonts.roboto(fontSize: 16, color: Colors.grey[600]),
        ),
      )
          : hasActiveSubscription
          ? _buildActiveSubscriptionUI()
          : _buildPackageSelectionUI(),
    );
  }
}