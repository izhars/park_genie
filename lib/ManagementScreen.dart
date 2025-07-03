import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'ParkingSpacesScreen.dart';
import 'VehicleScreen.dart';

class ManagementScreen extends StatefulWidget {
  const ManagementScreen({super.key});

  @override
  _ManagementScreenState createState() => _ManagementScreenState();
}

class _ManagementScreenState extends State<ManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Parking Management',
          style: GoogleFonts.poppins(
            color: Colors.white,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(
              icon: Icon(Icons.directions_car, color: Colors.white),
              child: Text(
                'Vehicle Types',
                style: TextStyle(
                  fontSize: 16, // Adjust size as needed
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2, // Optional: Adds spacing between letters
                ),
              ),
            ),
            Tab(
              icon: Icon(Icons.local_parking, color: Colors.white),
              child: Text(
                'Parking Spaces',
                style: TextStyle(
                  fontSize: 16, // Adjust size as needed
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2, // Optional: Adds spacing between letters
                ),
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          VehicleScreenTab(),
          ParkingSpacesScreenTab(),
        ],
      ),
    );
  }
}

// Wrapper for VehicleScreen to work in TabBarView
class VehicleScreenTab extends StatelessWidget {
  const VehicleScreenTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const VehicleScreen(isInTabView: true);
  }
}

// Wrapper for ParkingSpacesScreen to work in TabBarView
class ParkingSpacesScreenTab extends StatelessWidget {
  const ParkingSpacesScreenTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const ParkingSpacesScreen(isInTabView: true);
  }
}