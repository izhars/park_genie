import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart'; // Add this dependency to pubspec.yaml
import '../DatabaseHelper.dart';

class GateManagementScreen extends StatefulWidget {
  const GateManagementScreen({super.key});

  @override
  State<GateManagementScreen> createState() => _GateManagementScreenState();
}

class _GateManagementScreenState extends State<GateManagementScreen> with SingleTickerProviderStateMixin {
  final List<Map<String, dynamic>> _gates = [];
  bool _isLoading = true;
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();

  // For gate usage statistics
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  List<Map<String, dynamic>> _gateUsageStats = [];
  bool _isLoadingStats = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Rebuild when tab changes
    });
    _refreshGates();
    _loadGateUsageStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshGates() async {
    setState(() {
      _isLoading = true;
    });
    final gates = await DatabaseHelper.instance.getAllGates();
    setState(() {
      _gates.clear();
      _gates.addAll(gates);
      _isLoading = false;
    });
  }

  Future<void> _loadGateUsageStats() async {
    setState(() {
      _isLoadingStats = true;
    });
    final stats = await DatabaseHelper.instance.getGateUsageStats(
        _startDate, _endDate);
    setState(() {
      _gateUsageStats = stats;
      _isLoadingStats = false;
    });
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme
                  .of(context)
                  .primaryColor,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Theme
                    .of(context)
                    .primaryColor,
              ),
            ), dialogTheme: const DialogThemeData(backgroundColor: Colors.white),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadGateUsageStats();
    }
  }

  void _showGateDialog({Map<String, dynamic>? gate}) {
    final isEditing = gate != null;
    final titleController = TextEditingController(
        text: isEditing ? gate['name'] : '');
    final locationController = TextEditingController(
        text: isEditing ? gate['location'] : '');
    final notesController = TextEditingController(
        text: isEditing ? gate['notes'] : '');

    String selectedType = isEditing ? gate['type'] : 'both';
    bool isActive = isEditing ? gate['isActive'] == 1 : true;

    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: Text(
              isEditing ? 'Edit Gate' : 'Add New Gate',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Gate Name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.door_front_door),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: locationController,
                      decoration: InputDecoration(
                        labelText: 'Location',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.location_on),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: InputDecoration(
                        labelText: 'Gate Type',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.swap_horiz),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'entry', child: Text('Entry Only')),
                        DropdownMenuItem(
                            value: 'exit', child: Text('Exit Only')),
                        DropdownMenuItem(
                            value: 'both', child: Text('Both Entry and Exit')),
                      ],
                      onChanged: (value) {
                        selectedType = value!;
                      },
                    ),
                    const SizedBox(height: 16),
                    StatefulBuilder(
                      builder: (context, setState) {
                        return Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey.shade400,
                            ),
                          ),
                          child: SwitchListTile(
                            title: const Text('Active'),
                            subtitle: Text(isActive
                                ? 'Gate is operational'
                                : 'Gate is disabled'),
                            value: isActive,
                            onChanged: (value) {
                              setState(() {
                                isActive = value;
                              });
                            },
                            secondary: Icon(
                              isActive ? Icons.check_circle : Icons.cancel,
                              color: isActive ? Colors.green : Colors.red,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: notesController,
                      decoration: InputDecoration(
                        labelText: 'Notes',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.note),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey,
                ),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  // Validate
                  if (titleController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Gate name cannot be empty'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }

                  final gateData = {
                    'name': titleController.text,
                    'location': locationController.text,
                    'isActive': isActive ? 1 : 0,
                    'type': selectedType,
                    'notes': notesController.text,
                  };

                  if (isEditing) {
                    await DatabaseHelper.instance.updateGate(
                        gate['id'], gateData);
                  } else {
                    await DatabaseHelper.instance.insertGate(gateData);
                  }

                  Navigator.of(context).pop();
                  _refreshGates();
                  _loadGateUsageStats(); // Refresh stats too

                  // Show success message
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isEditing
                          ? 'Gate updated successfully'
                          : 'Gate added successfully'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme
                      .of(context)
                      .primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(isEditing ? 'Update' : 'Add'),
              ),
            ],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            actionsPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
          ),
    );
  }


  Future<void> _confirmDeleteGate(int id, String name) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text(
            'Are you sure you want to delete the gate "$name"? This action cannot be undone.'
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            onPressed: () async {
              final result = await DatabaseHelper.instance.deleteGate(id);
              Navigator.of(context).pop();

              if (result > 0) {
                _refreshGates();
                _loadGateUsageStats(); // Refresh stats too

                // Show success message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Gate "$name" deleted'),
                    backgroundColor: Colors.red[700],
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } else {
                // Show error message - couldn't delete the last gate
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Cannot delete the last gate. At least one gate must remain in the system.'),
                    backgroundColor: Colors.orange,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

// Add a method to toggle gate status (active/inactive)
  Future<void> _toggleGateActiveStatus(int id, String name, bool currentStatus) async {
    final newStatus = !currentStatus;

    await DatabaseHelper.instance.toggleGateActiveStatus(id, newStatus);
    _refreshGates();

    // Show status change message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Gate "$name" is now ${newStatus ? 'active' : 'inactive'}'),
        backgroundColor: newStatus ? Colors.green : Colors.orange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Gate Management',
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
              icon: Icon(Icons.door_back_door_outlined, color: Colors.white),
              child: Text(
                'Gates List',
                style: TextStyle(
                  fontSize: 16, // Adjust size as needed
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2, // Optional: Adds spacing between letters
                ),
              ),
            ),
            Tab(
              icon: Icon(Icons.data_usage, color: Colors.white),
              child: Text(
                'Gate Usage',
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
        children: [
          // Gates List Tab
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _gates.isEmpty
              ? _buildEmptyState(
              'No gates found', 'Add a new gate to get started')
              : AnimatedList(
            key: GlobalKey<AnimatedListState>(),
            initialItemCount: _gates.length,
            itemBuilder: (context, index, animation) {
              return _buildGateCard(context, index, animation);
            },
          ),

          // Gate Usage Statistics Tab
          _buildStatsTab(),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
        onPressed: () => _showGateDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Gate'),
        elevation: 4,
      )
          : null,
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.door_sliding_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          //const SizedBox(height: 24),
          // ElevatedButton.icon(
          //   onPressed: () => _showGateDialog(),
          //   icon: const Icon(Icons.add),
          //   label: const Text('Add New Gate'),
          //   style: ElevatedButton.styleFrom(
          //     padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          //     shape: RoundedRectangleBorder(
          //       borderRadius: BorderRadius.circular(8),
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget _buildGateCard(BuildContext context, int index, Animation<double> animation) {
    final gate = _gates[index];
    final isActive = gate['isActive'] == 1;

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
      )),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isActive
                  ? _getGateTypeColor(gate['type']).withOpacity(0.3)
                  : Colors.grey.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              children: [
                // Gate type color strip at the top
                Container(
                  height: 8,
                  color: isActive
                      ? _getGateTypeColor(gate['type'])
                      : Colors.grey,
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? _getGateTypeColor(gate['type']).withOpacity(
                                  0.1)
                                  : Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getGateTypeIcon(gate['type']),
                                  color: isActive
                                      ? _getGateTypeColor(gate['type'])
                                      : Colors.grey,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _getGateTypeText(gate['type']),
                                  style: TextStyle(
                                    color: isActive
                                        ? _getGateTypeColor(gate['type'])
                                        : Colors.grey,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => _toggleGateActiveStatus(gate['id'], gate['name'], isActive),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isActive
                                        ? Icons.check_circle_outline
                                        : Icons.cancel_outlined,
                                    color: isActive
                                        ? Colors.green
                                        : Colors.red,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isActive ? 'Active' : 'Inactive',
                                    style: TextStyle(
                                      color: isActive
                                          ? Colors.green
                                          : Colors.red,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Rest of the gate card remains the same...
                      const SizedBox(height: 12),
                      Text(
                        gate['name'],
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isActive ? Colors.black87 : Colors.grey,
                        ),
                      ),
                      if (gate['location'] != null && gate['location'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  gate['location'],
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (gate['notes'] != null && gate['notes'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.note_outlined,
                                  size: 16,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    gate['notes'],
                                    style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Edit'),
                            onPressed: () => _showGateDialog(gate: gate),
                            style: TextButton.styleFrom(
                              foregroundColor: Theme.of(context).primaryColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Delete'),
                            onPressed: () => _confirmDeleteGate(gate['id'], gate['name']),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsTab() {
    return _isLoadingStats
        ? const Center(child: CircularProgressIndicator())
        : _gateUsageStats.isEmpty
        ? _buildEmptyState(
      'No usage data available',
      'No gate activity recorded in the selected period',
    )
    : SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Date Range',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme
                              .of(context)
                              .primaryColor,
                        ),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.date_range),
                        label: const Text('Change'),
                        onPressed: _selectDateRange,
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '${DateFormat('MMM d, yyyy').format(
                              _startDate)} - ${DateFormat('MMM d, yyyy').format(
                              _endDate)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildSummaryCards(),
          const SizedBox(height: 16),
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
                  Text(
                    'Gate Usage Chart',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme
                          .of(context)
                          .primaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 300,
                    child: _buildBarChart(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
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
                  Text(
                    'Detailed Statistics',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme
                          .of(context)
                          .primaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        Colors.grey[100],
                      ),
                      dataRowHeight: 56,
                      headingRowHeight: 56,
                      horizontalMargin: 16,
                      columnSpacing: 24,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      columns: const [
                        DataColumn(
                          label: Text(
                            'Gate Name',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Type',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Entries',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          numeric: true,
                        ),
                        DataColumn(
                          label: Text(
                            'Exits',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          numeric: true,
                        ),
                        DataColumn(
                          label: Text(
                            'Total Usage',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          numeric: true,
                        ),
                      ],
                      rows: _gateUsageStats.map((stat) {
                        return DataRow(
                          cells: [
                            DataCell(Text(stat['gateName'] ?? 'Unknown')),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getGateTypeColor(
                                      stat['gateType'] ?? 'both').withOpacity(
                                      0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _getGateTypeIcon(
                                          stat['gateType'] ?? 'both'),
                                      color: _getGateTypeColor(
                                          stat['gateType'] ?? 'both'),
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _getGateTypeText(
                                          stat['gateType'] ?? 'both'),
                                      style: TextStyle(
                                        color: _getGateTypeColor(
                                            stat['gateType'] ?? 'both'),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            DataCell(Text(
                              (stat['entryCount'] ?? 0).toString(),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500),
                            )),
                            DataCell(Text(
                              (stat['exitCount'] ?? 0).toString(),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500),
                            )),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Theme
                                      .of(context)
                                      .primaryColor
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  (stat['totalCount'] ?? 0).toString(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Theme
                                        .of(context)
                                        .primaryColor,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    // Calculate total entries, exits, and total usage
    int totalEntries = 0;
    int totalExits = 0;
    int totalUsage = 0;

    for (var stat in _gateUsageStats) {
      totalEntries += ((stat['entryCount'] ?? 0) as num).toInt();
      totalExits += ((stat['exitCount'] ?? 0) as num).toInt();
      totalUsage += ((stat['totalCount'] ?? 0) as num).toInt();
    }

    // Find most active gate
    Map<String, dynamic>? mostActiveGate;
    int maxUsage = 0;

    for (var stat in _gateUsageStats) {
      if ((stat['totalCount'] ?? 0) > maxUsage) {
        maxUsage = (stat['totalCount'] ?? 0);
        mostActiveGate = stat;
      }
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Total Usage',
                totalUsage.toString(),
                Icons.analytics_outlined,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSummaryCard(
                'Total Entries',
                totalEntries.toString(),
                Icons.input,
                Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Total Exits',
                totalExits.toString(),
                Icons.output,
                Colors.red,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSummaryCard(
                'Most Active Gate',
                mostActiveGate != null
                    ? (mostActiveGate['gateName'] ?? 'None')
                    : 'None',
                Icons.star_outline,
                Colors.amber,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon,
      Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart() {
    if (_gateUsageStats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              'No data available',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    // Calculate max value and nice interval
    int maxValue = _gateUsageStats.fold<int>(
        0, (max, stat) => (stat['totalCount'] ?? 0) > max ? (stat['totalCount'] ?? 0) : max);
    maxValue = maxValue > 0 ? maxValue : 1;
    double interval = _calculateNiceInterval(maxValue, 5);

    return ClipRect(
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: (maxValue * 1.1).toDouble(), // Reduced padding
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              tooltipBgColor: Colors.white,
              tooltipPadding: const EdgeInsets.all(8),
              tooltipMargin: 4,
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final stat = _gateUsageStats[groupIndex];
                return BarTooltipItem(
                  '${stat['gateName']}\n',
                  const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                  children: [
                    TextSpan(
                      text: 'Entries: ${stat['entryCount']}\n',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontSize: 14,
                      ),
                    ),
                    TextSpan(
                      text: 'Exits: ${stat['exitCount']}\n',
                      style: TextStyle(
                        color: Colors.red[700],
                        fontSize: 14,
                      ),
                    ),
                    TextSpan(
                      text: 'Total: ${stat['totalCount']}',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= _gateUsageStats.length) {
                    return const SizedBox();
                  }
                  final name = _gateUsageStats[index]['gateName'] ?? 'Unknown';
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      _truncateWithEllipsis(name, 8),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  );
                },
                reservedSize: 50,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value == 0) {
                    return const SizedBox();
                  }
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      value.toInt().toString(),
                      style: const TextStyle(
                        fontSize: 10,
                      ),
                    ),
                  );
                },
                reservedSize: 50,
                interval: interval,
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(
            show: true,
            horizontalInterval: interval,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey[300] ?? Colors.grey,
                strokeWidth: 1,
              );
            },
            drawVerticalLine: false,
          ),
          borderData: FlBorderData(
            show: true,
            border: Border(
              bottom: BorderSide(color: Colors.grey[300]!, width: 1),
              left: BorderSide(color: Colors.grey[300]!, width: 1),
            ),
          ),
          barGroups: _gateUsageStats.asMap().entries.map((entry) {
            final index = entry.key;
            final stat = entry.value;
            final entryCount = (stat['entryCount'] ?? 0).toDouble();
            final exitCount = (stat['exitCount'] ?? 0).toDouble();

            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: entryCount + exitCount,
                  width: _gateUsageStats.length > 10 ? 10 : 20,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    topRight: Radius.circular(6),
                  ),
                  rodStackItems: [
                    BarChartRodStackItem(0, entryCount, Colors.green),
                    BarChartRodStackItem(entryCount, entryCount + exitCount, Colors.red),
                  ],
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

// Helper function to calculate nice intervals for axis labels
  double _calculateNiceInterval(int maxValue, int targetCount) {
    // Handle edge case
    if (maxValue <= 0) return 1.0;

    // Calculate raw interval
    double rawInterval = maxValue / targetCount;

    // Ensure minimum interval is 1
    if (rawInterval < 1) return 1.0;

    // Rest of your calculation...
    double magnitude = pow(10, (log(rawInterval) / log(10)).floor()).toDouble();
    double normalized = rawInterval / magnitude;

    double niceInterval;
    if (normalized < 1.5) {
      niceInterval = 1 * magnitude;
    } else if (normalized < 3) {
      niceInterval = 2 * magnitude;
    } else if (normalized < 7) {
      niceInterval = 5 * magnitude;
    } else {
      niceInterval = 10 * magnitude;
    }

    return niceInterval;
  }

// Helper function for truncating text with ellipsis
  String _truncateWithEllipsis(String text, int maxLength) {
    return (text.length <= maxLength) ? text : '${text.substring(
        0, maxLength)}...';
  }

  IconData _getGateTypeIcon(String type) {
    switch (type) {
      case 'entry':
        return Icons.input;
      case 'exit':
        return Icons.output;
      case 'both':
        return Icons.swap_horiz;
      default:
        return Icons.door_sliding;
    }
  }

  String _getGateTypeText(String type) {
    switch (type) {
      case 'entry':
        return 'Entry Only';
      case 'exit':
        return 'Exit Only';
      case 'both':
        return 'Entry & Exit';
      default:
        return 'Unknown';
    }
  }

  Color _getGateTypeColor(String type) {
    switch (type) {
      case 'entry':
        return Colors.green;
      case 'exit':
        return Colors.red;
      case 'both':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}


// Add this theme customization to your main.dart
ThemeData appTheme() {
  return ThemeData(
    primarySwatch: Colors.blue,
    scaffoldBackgroundColor: Colors.grey[50],
    cardTheme: CardTheme(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      backgroundColor: Colors.white,
      iconTheme: IconThemeData(color: Colors.black87),
      titleTextStyle: TextStyle(
        color: Colors.black87,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    tabBarTheme: const TabBarTheme(
      labelStyle: TextStyle(fontWeight: FontWeight.bold),
      unselectedLabelStyle: TextStyle(fontWeight: FontWeight.normal),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Colors.blue,
      foregroundColor: Colors.white,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.blue,
        side: const BorderSide(color: Colors.blue),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Colors.blue,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.blue, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
    textTheme: const TextTheme(
      titleLarge: TextStyle(fontWeight: FontWeight.bold),
      titleMedium: TextStyle(fontWeight: FontWeight.bold),
    ),
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      primary: Colors.blue,
      secondary: Colors.teal,
    ),
    dividerTheme: const DividerThemeData(
      thickness: 1,
      space: 24,
    ),
  );
}