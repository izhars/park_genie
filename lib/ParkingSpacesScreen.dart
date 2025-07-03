import 'package:flutter/material.dart';
import 'DatabaseHelper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ParkingSpacesScreen extends StatefulWidget {
  final bool isInTabView;

  const ParkingSpacesScreen({super.key, this.isInTabView = false});

  @override
  _ParkingSpacesScreenState createState() => _ParkingSpacesScreenState();
}

class _ParkingSpacesScreenState extends State<ParkingSpacesScreen> with SingleTickerProviderStateMixin {
  final _spacesController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _useSpacesTracking = true;
  Map<String, dynamic> _spacesInfo = {
    'totalSpaces': 0,
    'occupiedSpaces': 0,
    'availableSpaces': 0,
    'gateNumber': null,
    'gateName': null,
    'gateLocation': null,
  };
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadSpacesInfo();
    _loadSpacesTrackingPreference();
  }

  @override
  void dispose() {
    _spacesController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadSpacesInfo() async {
    setState(() => _isLoading = true);
    try {
      final spacesInfo = await DatabaseHelper.instance.getParkingSpaceInfo();
      setState(() {
        _spacesInfo = spacesInfo;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to load spaces information');
    }
  }

  Future<void> _loadSpacesTrackingPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _useSpacesTracking = prefs.getBool('useSpacesTracking') ?? true;
    });
  }

  Future<void> _saveSpacesTrackingPreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('useSpacesTracking', value);
  }

  Future<void> _updateTotalSpaces() async {
    if (!_formKey.currentState!.validate()) return;

    final totalSpaces = int.parse(_spacesController.text.trim());

    setState(() => _isLoading = true);
    try {
      await DatabaseHelper.instance.updateTotalSpaces(totalSpaces);
      _showSuccessSnackBar('Total spaces updated successfully');
      _spacesController.clear();
      await _loadSpacesInfo();
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Operation failed. Please try again.');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _toggleSpacesTracking(bool value) async {
    setState(() {
      _useSpacesTracking = value;
    });
    await _saveSpacesTrackingPreference(value);

    if (value) {
      _showSuccessSnackBar('Spaces tracking enabled');
    } else {
      _showSuccessSnackBar('Spaces tracking disabled');
    }
  }

  void _showUpdateForm() {
    _spacesController.text = _spacesInfo['totalSpaces'].toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 16,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, -5),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                  const Text(
                    'Update Total Parking Spaces',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _spacesController,
                    decoration: InputDecoration(
                      labelText: 'Spaces',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.local_parking),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter total spaces';
                      }
                      if (int.tryParse(value) == null) {
                        return 'Please enter a valid number';
                      }
                      if (int.parse(value) < _spacesInfo['occupiedSpaces']!) {
                        return 'Total spaces cannot be less than occupied spaces';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            _updateTotalSpaces();
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Update'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Space Tracking Switch
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Space Tracking Settings',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Enable Space Tracking',
                                  style: TextStyle(
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Track available and occupied parking spaces',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _useSpacesTracking,
                            onChanged: _toggleSpacesTracking,
                            activeColor: Theme.of(context).primaryColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
              // Spaces Information
              AnimatedOpacity(
                opacity: _useSpacesTracking ? 1.0 : 0.5,
                duration: const Duration(milliseconds: 300),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current Parking Status',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatusCard(
                            'Spaces',
                            _spacesInfo['totalSpaces'].toString(),
                            Icons.crop_square,
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatusCard(
                            'Occupied',
                            _spacesInfo['occupiedSpaces'].toString(),
                            Icons.directions_car,
                            Colors.red,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatusCard(
                            'Available',
                            _spacesInfo['availableSpaces'].toString(),
                            Icons.check_circle,
                            Colors.green,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    if (_useSpacesTracking)
                      ElevatedButton.icon(
                        onPressed: _showUpdateForm,
                        icon: const Icon(Icons.edit),
                        label: const Text('Update Total Spaces'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          minimumSize: const Size(double.infinity, 50),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Space Utilization Visualization
              if (_useSpacesTracking && _spacesInfo['totalSpaces']! > 0)
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Space Utilization',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        LinearProgressIndicator(
                          value: _spacesInfo['occupiedSpaces']! / _spacesInfo['totalSpaces']!,
                          minHeight: 10,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _getUtilizationColor(_spacesInfo['occupiedSpaces']! / _spacesInfo['totalSpaces']!),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${((_spacesInfo['occupiedSpaces']! / _spacesInfo['totalSpaces']!) * 100).toStringAsFixed(1)}% Occupied',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _getUtilizationColor(_spacesInfo['occupiedSpaces']! / _spacesInfo['totalSpaces']!),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(
              icon,
              color: color,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Color _getUtilizationColor(double utilization) {
    if (utilization < 0.5) return Colors.green;
    if (utilization < 0.8) return Colors.orange;
    return Colors.red;
  }
}