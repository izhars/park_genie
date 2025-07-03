import 'package:flutter/material.dart';
import 'DatabaseHelper.dart';
import 'package:intl/intl.dart';

class VehicleScreen extends StatefulWidget {
  final bool isInTabView;

  const VehicleScreen({super.key, this.isInTabView = false});

  @override
  _VehicleScreenState createState() => _VehicleScreenState();
}

class _VehicleScreenState extends State<VehicleScreen> with SingleTickerProviderStateMixin {
  final _typeController = TextEditingController();
  final _priceController = TextEditingController();
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _vehicleTypes = [];
  List<Map<String, dynamic>> _filteredVehicleTypes = [];
  bool _isLoading = true;
  late AnimationController _animationController;
  final _formKey = GlobalKey<FormState>();
  final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadVehicleTypes();
    _searchController.addListener(_filterVehicleTypes);
  }

  @override
  void dispose() {
    _typeController.dispose();
    _priceController.dispose();
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _filterVehicleTypes() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredVehicleTypes = _vehicleTypes.where((vehicle) {
        return vehicle['type'].toString().toLowerCase().contains(query);
      }).toList();
    });
  }

  Future<void> _loadVehicleTypes() async {
    setState(() => _isLoading = true);
    try {
      final vehicleTypes = await DatabaseHelper.instance.getVehicleTypes();
      setState(() {
        _vehicleTypes = vehicleTypes;
        _filteredVehicleTypes = vehicleTypes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to load vehicle types');
    }
  }

  Future<void> _addOrUpdateVehicleType({int? id}) async {
    if (!_formKey.currentState!.validate()) return;

    final type = _typeController.text.trim();
    final price = _priceController.text.trim();

    setState(() => _isLoading = true);
    try {
      final vehicleType = {'type': type, 'price': price};

      if (id == null) {
        await DatabaseHelper.instance.insertVehicleType(vehicleType);
        _showSuccessSnackBar('Vehicle type added successfully');
      } else {
        await DatabaseHelper.instance.updateVehicleType(id, vehicleType);
        _showSuccessSnackBar('Vehicle type updated successfully');
      }

      _typeController.clear();
      _priceController.clear();
      await _loadVehicleTypes();
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Operation failed. Please try again.');
    }
  }

  Future<void> _deleteVehicleType(int id) async {
    try {
      await DatabaseHelper.instance.deleteVehicleType(id);
      _showSuccessSnackBar('Vehicle type deleted successfully');
      final types = await DatabaseHelper.instance.getVehicleTypes();
      print("Vehicle types after deletion: $types");
      await _loadVehicleTypes();
    } catch (e) {
      _showErrorSnackBar('Failed to delete vehicle type: $e');
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

  void _confirmDelete(int id, String vehicleType) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete "$vehicleType"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteVehicleType(id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatPrice(String price) {
    try {
      return currencyFormat.format(int.parse(price));
    } catch (e) {
      return '₹$price';
    }
  }

  void _showForm({int? id}) {
    if (id != null) {
      final vehicleType = _vehicleTypes.firstWhere((v) => v['id'] == id);
      _typeController.text = vehicleType['type'];
      _priceController.text = vehicleType['price'];
    } else {
      _typeController.clear();
      _priceController.clear();
    }

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
                  Text(
                    id == null ? 'Add New Vehicle Type' : 'Update Vehicle Type',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _typeController,
                    decoration: InputDecoration(
                      labelText: 'Vehicle Type',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.directions_car),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a vehicle type';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _priceController,
                    decoration: InputDecoration(
                      labelText: 'Price',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.currency_rupee),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a price';
                      }
                      if (int.tryParse(value) == null) {
                        return 'Please enter a valid number';
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
                            _addOrUpdateVehicleType(id: id);
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(id == null ? 'Add' : 'Update'),
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
      appBar: widget.isInTabView
          ? null // No AppBar when in tab view
          : AppBar(
        title: const Text('Manage Vehicle Types'),
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadVehicleTypes,
          ),
        ],
      ),
      body: Column(
        children: [
          if (!widget.isInTabView)
            const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            color: widget.isInTabView
                ? Theme.of(context).primaryColor.withOpacity(0.1)
                : null,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search vehicle types...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredVehicleTypes.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.no_transfer, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    _searchController.text.isNotEmpty
                        ? 'No vehicle types match your search'
                        : 'No vehicle types found',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: _filteredVehicleTypes.length,
              itemBuilder: (context, index) {
                final vehicleType = _filteredVehicleTypes[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).primaryColor,
                      child: const Icon(
                        Icons.directions_car,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      vehicleType['type'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        _formatPrice(vehicleType['price']),
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          tooltip: 'Edit',
                          onPressed: () => _showForm(id: vehicleType['id']),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: 'Delete',
                          onPressed: () => _confirmDelete(vehicleType['id'], vehicleType['type']),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add Vehicle'),
        elevation: 4,
      ),
    );
  }
}