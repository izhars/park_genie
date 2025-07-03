import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'DatabaseHelper.dart';

class DailyStats extends StatefulWidget {
  const DailyStats({super.key});

  @override
  State<DailyStats> createState() => _DailyStatsState();
}

class _DailyStatsState extends State<DailyStats> {
  Map<String, dynamic>? dailyStats;
  List<Map<String, dynamic>> weeklyRevenue = [];
  List<Map<String, dynamic>> monthlyRevenue = [];
  bool isLoading = true;
  int _currentTabIndex = 0;
  int _selectedWeekIndex = 0;
  final List<Color> _chartColors = [
    const Color(0xFF3366FF),
    const Color(0xFF00C853),
    const Color(0xFFFF9800),
    const Color(0xFFE91E63),
    const Color(0xFF9C27B0),
  ];
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() {
      isLoading = true;
    });

    final daily = await DatabaseHelper.instance.getDailyStats(_selectedDate);
    final weekly = await DatabaseHelper.instance.getWeeklyRevenue();
    final monthly = await DatabaseHelper.instance.getMonthlyRevenue();

    setState(() {
      dailyStats = daily;
      weeklyRevenue = weekly;
      monthlyRevenue = monthly;
      isLoading = false;
    });
  }

  void _navigateToPreviousDay() {
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
      _loadAllData();
    });
  }

  void _navigateToNextDay() {
    setState(() {
      _selectedDate = _selectedDate.add(const Duration(days: 1));
      _loadAllData();
    });
  }

  Future<void> _selectCustomDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF3366FF),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF424242),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _loadAllData();
      });
    }
  }

  Widget _buildRevenueChart(List<Map<String, dynamic>> data, String timePeriod) {
    if (data.isEmpty) {
      return _buildEmptyState('No revenue data available');
    }

    // Calculate average revenue
    final totalRevenue = data.fold(0.0, (sum, item) => sum + (item['revenue']?.toDouble() ?? 0));
    final averageRevenue = data.isNotEmpty ? totalRevenue / data.length : 0.0;

    // Get min and max values for better scaling
    final maxRevenue = data.map((e) => e['revenue']?.toDouble() ?? 0).reduce((a, b) => a > b ? a : b);
    final minRevenue = data.map((e) => e['revenue']?.toDouble() ?? 0).reduce((a, b) => a < b ? a : b);

    // Calculate growth if possible
    double? growthPercentage;
    if (data.length >= 2) {
      final firstValue = data.first['revenue']?.toDouble() ?? 0;
      final lastValue = data.last['revenue']?.toDouble() ?? 0;
      if (firstValue > 0) {
        growthPercentage = ((lastValue - firstValue) / firstValue) * 100;
      }
    }

    // Period title based on time period
    String periodTitle = _getPeriodTitle(timePeriod, data);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                periodTitle,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (growthPercentage != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: growthPercentage >= 0 ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        growthPercentage >= 0 ? Icons.trending_up : Icons.trending_down,
                        size: 16,
                        color: growthPercentage >= 0 ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${growthPercentage.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: growthPercentage >= 0 ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    tooltipBgColor: Colors.blueGrey.shade800,
                    tooltipPadding: const EdgeInsets.all(8),
                    tooltipMargin: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final item = data[group.x.toInt()];
                      final revenue = rod.toY.toInt();
                      String label = _getTooltipLabel(item, timePeriod);
                      final percentOfAvg = averageRevenue > 0
                          ? '${((revenue / averageRevenue) * 100).toStringAsFixed(1)}%'
                          : 'N/A';

                      return BarTooltipItem(
                        '$label\n',
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 12),
                        children: [
                          TextSpan(
                            text: '₹$revenue\n',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          TextSpan(
                            text: '$percentOfAvg of average',
                            style: TextStyle(
                              color: revenue >= averageRevenue ? Colors.greenAccent : Colors.redAccent,
                              fontSize: 12,
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
                        return _getBottomTitle(value, meta, timePeriod, data);
                      },
                      reservedSize: 40,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    axisNameWidget: Text(
                      'Revenue (₹)',
                      style: TextStyle(
                        color: Colors.blueGrey.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    axisNameSize: 25,
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      getTitlesWidget: (value, meta) {
                        // Format large numbers with K/M suffixes
                        String formattedValue = _formatCurrency(value.toInt());
                        return Text(
                          '₹$formattedValue',
                          style: TextStyle(
                            color: Colors.blueGrey.shade600,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawHorizontalLine: true,
                  horizontalInterval: _calculateInterval(maxRevenue),
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.shade200,
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                    left: BorderSide(color: Colors.grey.shade300, width: 1),
                  ),
                ),
                maxY: maxRevenue * 1.1, // Add 10% padding to the top
                minY: 0, // Always start from zero for revenue charts
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: averageRevenue,
                      color: Colors.orange,
                      strokeWidth: 1,
                      dashArray: [5, 5],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.topRight,
                        padding: const EdgeInsets.only(right: 5, bottom: 5),
                        style: const TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                        labelResolver: (line) => 'Avg: ₹${_formatCurrency(averageRevenue.toInt())}',
                      ),
                    ),
                  ],
                ),
                barGroups: data.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final revenue = item['revenue']?.toDouble() ?? 0;

                  // Determine color based on performance compared to average
                  Color barColor;
                  if (revenue >= averageRevenue * 1.2) {
                    barColor = Colors.green.shade500; // Significantly above average
                  } else if (revenue >= averageRevenue) {
                    barColor = Colors.green.shade300; // Above average
                  } else if (revenue >= averageRevenue * 0.8) {
                    barColor = Colors.orange.shade300; // Slightly below average
                  } else {
                    barColor = Colors.red.shade400; // Well below average
                  }

                  // Adjust width based on data length
                  final barWidth = data.length > 10 ? 10.0 : (data.length > 5 ? 14.0 : 18.0);

                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: revenue,
                        color: barColor,
                        width: barWidth,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxRevenue * 1.1,
                          color: Colors.grey.shade100,
                        ),
                      )
                    ],
                  );
                }).toList(),
              ),
              swapAnimationDuration: const Duration(milliseconds: 300),
              swapAnimationCurve: Curves.easeInOut,
            ),
          ),
        ),

        // Summary section
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem(
                'Total',
                '₹${_formatCurrency(totalRevenue.toInt())}',
                Icons.payments_outlined,
                Colors.blue.shade700,
              ),
              _buildSummaryItem(
                'Average',
                '₹${_formatCurrency(averageRevenue.toInt())}',
                Icons.show_chart,
                Colors.orange.shade700,
              ),
              _buildSummaryItem(
                'Highest',
                '₹${_formatCurrency(maxRevenue.toInt())}',
                Icons.trending_up,
                Colors.green.shade700,
              ),
            ],
          ),
        ),
      ],
    );
  }

// Helper method for summary items
  Widget _buildSummaryItem(String label, String value, IconData icon, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.blueGrey.shade600,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

// Helper method to format currency with K/M suffixes
  String _formatCurrency(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toString();
  }

// Calculate appropriate interval for grid lines
  double _calculateInterval(double maxValue) {
    if (maxValue <= 1000) return 200;
    if (maxValue <= 5000) return 500;
    if (maxValue <= 10000) return 1000;
    if (maxValue <= 50000) return 5000;
    if (maxValue <= 100000) return 10000;
    if (maxValue <= 500000) return 50000;
    if (maxValue <= 1000000) return 100000;
    return 500000;
  }

// Get appropriate period title based on time period and data
  String _getPeriodTitle(String timePeriod, List<Map<String, dynamic>> data) {
    if (data.isEmpty) return 'Revenue Chart';

    switch (timePeriod) {
      case 'daily':
        final startDate = DateTime.parse(data.first['date'].toString());
        final endDate = DateTime.parse(data.last['date'].toString());
        return 'Daily Revenue: ${DateFormat('MMM d').format(startDate)} - ${DateFormat('MMM d, yyyy').format(endDate)}';
      case 'weekly':
        return 'Weekly Revenue (${DateFormat('yyyy').format(DateTime.now())})';
      case 'monthly':
        return 'Monthly Revenue (${DateFormat('yyyy').format(DateTime.now())})';
      case 'yearly':
        final firstYear = data.first['year'] ?? DateTime.now().year - data.length + 1;
        final lastYear = data.last['year'] ?? DateTime.now().year;
        return 'Yearly Revenue: $firstYear - $lastYear';
      default:
        return 'Revenue Chart';
    }
  }

// Get tooltip label based on time period
  String _getTooltipLabel(Map<String, dynamic> item, String timePeriod) {
    switch (timePeriod) {
      case 'daily':
        final date = DateTime.parse(item['date'].toString());
        return DateFormat('EEE, MMM d, yyyy').format(date);
      case 'weekly':
        final weekStart = DateTime.parse(item['startDate'].toString());
        final weekEnd = DateTime.parse(item['endDate'].toString());
        return '${DateFormat('MMM d').format(weekStart)} - ${DateFormat('MMM d').format(weekEnd)}';
      case 'monthly':
        if (item.containsKey('month') && item.containsKey('year')) {
          return '${_getMonthName(item['month'])} ${item['year']}';
        } else if (item.containsKey('date')) {
          final date = DateTime.parse(item['date'].toString());
          return DateFormat('MMMM yyyy').format(date);
        }
        return 'Unknown';
      case 'yearly':
        return item['year']?.toString() ?? 'Unknown';
      default:
        return 'Unknown';
    }
  }

// Helper to get month name
  String _getMonthName(int month) {
    const monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    if (month >= 1 && month <= 12) {
      return monthNames[month - 1];
    }
    return 'Unknown';
  }

// Improved empty state
  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bar_chart,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for more data',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _getBottomTitle(double value, TitleMeta meta, String timePeriod, List<Map<String, dynamic>> data) {
    final index = value.toInt();
    final style = TextStyle(
      color: Colors.blueGrey.shade700,
      fontSize: 12,
      fontWeight: FontWeight.w500,
    );

    if (index >= 0 && index < data.length) {
      switch (timePeriod) {
        case 'day':
          return SideTitleWidget(
            axisSide: meta.axisSide,
            child: Text(
              DateFormat('dd MMM').format(DateTime.parse(data[index]['date'])),
              style: style,
            ),
          );
        case 'week':
          final startDate = data[index]['startDate'];
          final endDate = data[index]['endDate'];
          final start = DateFormat('dd MMM').format(startDate is String ? DateTime.parse(startDate) : startDate);
          final end = DateFormat('dd MMM').format(endDate is String ? DateTime.parse(endDate) : endDate);

          return SideTitleWidget(
            axisSide: meta.axisSide,
            child: Text(
              'W${index + 1}\n$start-$end',
              style: style,
              textAlign: TextAlign.center,
            ),
          );
        case 'month':
          final monthData = data[index]['month'];
          return SideTitleWidget(
            axisSide: meta.axisSide,
            child: Text(
              DateFormat('MMM y').format(monthData is String ? DateTime.parse(monthData) : monthData),
              style: style,
            ),
          );
        default:
          return const SizedBox.shrink();
      }
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: Text(
            'Parking Revenue Analytics',
            style: GoogleFonts.poppins(
              color: Colors.white,
            ),
          ),
          bottom: TabBar(
            onTap: (index) => setState(() => _currentTabIndex = index),
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            unselectedLabelStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w400,
              fontSize: 14,
            ),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: const [
              Tab(text: 'Daily'),
              Tab(text: 'Weekly'),
              Tab(text: 'Monthly'),
            ],
          ),
        ),
        body: isLoading
            ? const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF3366FF),
          ),
        )
            : Container(
          color: Colors.grey.shade50,
          child: TabBarView(
            children: [
              _buildDailyTab(),
              _buildRevenueTab(weeklyRevenue, 'week'),
              _buildRevenueTab(monthlyRevenue, 'month'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDailyTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDateSelector(),
            const SizedBox(height: 24),
            _buildSummaryCards(),
            const SizedBox(height: 24),
            _buildVehicleBreakdown(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              color: const Color(0xFF3366FF),
              onPressed: _navigateToPreviousDay,
            ),
            TextButton.icon(
              onPressed: () => _selectCustomDate(context),
              icon: const Icon(Icons.calendar_today, color: Color(0xFF3366FF)),
              label: Text(
                DateFormat('dd MMMM, yyyy').format(_selectedDate),
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.blueGrey.shade800,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios, size: 18),
              color: const Color(0xFF3366FF),
              onPressed: _navigateToNextDay,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 12.0),
          child: Text(
            "Today's Summary",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.blueGrey.shade800,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                "Total Entries",
                dailyStats?['summary']['totalEntries'] ?? 0,
                Icons.directions_car,
                const Color(0xFF3366FF),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                "Completed",
                dailyStats?['summary']['completedEntries'] ?? 0,
                Icons.check_circle,
                const Color(0xFF00C853),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildRevenueCard(
          "Total Revenue",
          "₹${dailyStats?['summary']['totalRevenue'] ?? 0}",
          Icons.account_balance_wallet,
          const Color(0xFFFF9800),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, int value, IconData icon, Color color) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.blueGrey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value.toString(),
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.blueGrey.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.blueGrey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.blueGrey.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }

// Modify the _buildRevenueTab function
  Widget _buildRevenueTab(List<Map<String, dynamic>> data, String timePeriod) {
    return Column(
      children: [
        const SizedBox(height: 16),
        Card(
          elevation: 1,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  timePeriod == 'week'
                      ? 'Weekly Revenue Trend'
                      : 'Monthly Revenue Trend',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.blueGrey.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  timePeriod == 'week'
                      ? 'Daily revenue breakdown by week'
                      : 'Revenue summary for recent months',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.blueGrey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Card(
            elevation: 1,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: timePeriod == 'week'
                ? _buildDailyBreakdownChart()
                : _buildRevenueChart(data, timePeriod),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

// Add this new method for the daily breakdown chart
  Widget _buildDailyBreakdownChart() {
    if (weeklyRevenue.isEmpty) {
      return _buildEmptyState('No weekly revenue data available');
    }

    // Safety check for index
    _selectedWeekIndex = _selectedWeekIndex.clamp(0, weeklyRevenue.length - 1);

    final selectedWeek = weeklyRevenue[_selectedWeekIndex];
    final dailyData = selectedWeek['dailyData'] as List<Map<String, dynamic>>? ?? [];

    if (dailyData.isEmpty) {
      return Column(
        children: [
          _buildWeekSelector(),
          Expanded(child: _buildEmptyState('No daily data available for this week')),
        ],
      );
    }

    // Calculate average revenue
    final totalRevenue = dailyData.fold(0.0, (sum, item) => sum + (item['revenue']?.toDouble() ?? 0));
    final averageRevenue = dailyData.isNotEmpty ? totalRevenue / dailyData.length : 0.0;

    // Get week start and end dates for title
    final weekStart = dailyData.isNotEmpty ? DateTime.parse(dailyData.first['date'].toString()) : DateTime.now();
    final weekEnd = dailyData.isNotEmpty ? DateTime.parse(dailyData.last['date'].toString()) : DateTime.now();

    return Column(
      children: [
        _buildWeekSelector(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Daily Revenue: ${DateFormat('MMM d').format(weekStart)} - ${DateFormat('MMM d, yyyy').format(weekEnd)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    tooltipBgColor: Colors.blueGrey.shade800,
                    tooltipPadding: const EdgeInsets.all(8),
                    tooltipMargin: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final date = DateTime.parse(dailyData[group.x.toInt()]['date'].toString());
                      final revenue = rod.toY.toInt();
                      final percentOfAvg = averageRevenue > 0
                          ? '${((revenue / averageRevenue) * 100).toStringAsFixed(1)}%'
                          : 'N/A';

                      return BarTooltipItem(
                        '${DateFormat('EEE, MMM d').format(date)}\n',
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 12),
                        children: [
                          TextSpan(
                            text: '₹$revenue\n',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          TextSpan(
                            text: '$percentOfAvg of average',
                            style: TextStyle(
                              color: revenue >= averageRevenue ? Colors.greenAccent : Colors.redAccent,
                              fontSize: 12,
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
                        if (index >= 0 && index < dailyData.length) {
                          final date = DateTime.parse(dailyData[index]['date'].toString());
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text(
                              DateFormat('EEE\ndd').format(date),
                              style: TextStyle(
                                color: Colors.blueGrey.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                      reservedSize: 40,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    axisNameWidget: Text(
                      'Revenue (₹)',
                      style: TextStyle(
                        color: Colors.blueGrey.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    axisNameSize: 25,
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '₹${value.toInt()}',
                          style: TextStyle(
                            color: Colors.blueGrey.shade600,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawHorizontalLine: true,
                  horizontalInterval: 200,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.shade200,
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                    left: BorderSide(color: Colors.grey.shade300, width: 1),
                  ),
                ),
                maxY: dailyData
                    .map((e) => e['revenue']?.toDouble() ?? 0)
                    .fold(0.0, (max, value) => value > max ? value : max) * 1.1,
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: averageRevenue,
                      color: Colors.orange,
                      strokeWidth: 1,
                      dashArray: [5, 5],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.topRight,
                        padding: const EdgeInsets.only(right: 5, bottom: 5),
                        style: const TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                        labelResolver: (line) => 'Avg: ₹${averageRevenue.toInt()}',
                      ),
                    ),
                  ],
                ),
                barGroups: dailyData.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final revenue = item['revenue']?.toDouble() ?? 0;

                  // Determine color based on performance compared to average
                  final barColor = revenue >= averageRevenue
                      ? const Color(0xFF26A69A) // Green for above average
                      : const Color(0xFFEF5350); // Red for below average

                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: revenue,
                        color: barColor,
                        width: 16,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: dailyData
                              .map((e) => e['revenue']?.toDouble() ?? 0)
                              .fold(0.0, (max, value) => value > max ? value : max) * 1.1,
                          color: Colors.grey.shade100,
                        ),
                      )
                    ],
                  );
                }).toList(),
              ),
              swapAnimationDuration: const Duration(milliseconds: 300), // Add animation
              swapAnimationCurve: Curves.easeInOut,
            ),
          ),
        ),
      ],
    );
  }

// Add a week selector widget
  Widget _buildWeekSelector() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 18),
            color: const Color(0xFF3366FF),
            onPressed: _selectedWeekIndex < weeklyRevenue.length - 1
                ? () => setState(() => _selectedWeekIndex++)
                : null,
          ),
          Expanded(
            child: TextButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Select Week', style: GoogleFonts.poppins()),
                    content: SizedBox(
                      width: double.maxFinite,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: weeklyRevenue.length,
                        itemBuilder: (context, index) {
                          final week = weeklyRevenue[index];
                          final startDate = DateFormat('dd MMM').format(week['startDate']);
                          final endDate = DateFormat('dd MMM').format(week['endDate']);
                          return ListTile(
                            title: Text('$startDate - $endDate'),
                            subtitle: Text('₹${week['revenue'].toStringAsFixed(2)}'),
                            onTap: () {
                              setState(() => _selectedWeekIndex = index);
                              Navigator.pop(context);
                            },
                            selected: index == _selectedWeekIndex,
                            selectedTileColor: const Color(0xFF3366FF).withOpacity(0.1),
                          );
                        },
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Close', style: GoogleFonts.poppins()),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.calendar_today, color: Color(0xFF3366FF)),
              label: Text(
                weeklyRevenue.isNotEmpty
                    ? '${DateFormat('dd MMM').format(weeklyRevenue[_selectedWeekIndex]['startDate'])} - '
                    '${DateFormat('dd MMM').format(weeklyRevenue[_selectedWeekIndex]['endDate'])}'
                    : 'No data',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.blueGrey.shade800,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, size: 18),
            color: const Color(0xFF3366FF),
            onPressed: _selectedWeekIndex > 0
                ? () => setState(() => _selectedWeekIndex--)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleBreakdown() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.pie_chart, color: Color(0xFF9C27B0), size: 20),
                const SizedBox(width: 8),
                Text(
                  "Vehicle Type Breakdown",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.blueGrey.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            dailyStats!['typeBreakdown'].isEmpty ||
                dailyStats!['typeBreakdown'].every((item) => item['count'] == 0)
                ? _buildEmptyState('No vehicle data available')
                : SizedBox(
              height: 220,
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: PieChart(
                      PieChartData(
                        sections: _buildPieSections(dailyStats!['typeBreakdown']),
                        sectionsSpace: 0,
                        centerSpaceRadius: 40,
                        startDegreeOffset: -90,
                        pieTouchData: PieTouchData(
                          touchCallback: (FlTouchEvent event, pieTouchResponse) {
                            // Handle touch events if needed
                          },
                          enabled: true,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...dailyStats!['typeBreakdown'].asMap().entries.map((entry) {
                            final index = entry.key;
                            final data = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                children: [
                                  Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: _chartColors[index % _chartColors.length],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "${data['vehicleType']}",
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.blueGrey.shade800,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "${data['count']}",
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blueGrey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              "Details",
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.blueGrey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            ...dailyStats!['typeBreakdown'].map((typeData) {
              return Card(
                elevation: 0,
                color: Colors.grey.shade100,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3366FF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.directions_car, color: Color(0xFF3366FF)),
                  ),
                  title: Text(
                    "${typeData['vehicleType']}",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.blueGrey.shade800,
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3366FF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      "${typeData['count']}",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections(List<dynamic> breakdown) {
    final filtered = breakdown.where((item) => (item['count'] as int) > 0).toList();
    final total = filtered.fold<double>(0, (sum, item) => sum + (item['count'] as int).toDouble());

    return filtered.asMap().entries.map((entry) {
      final index = entry.key;
      final data = entry.value;
      final value = (data['count'] as int).toDouble();
      final percentage = total > 0 ? (value / total * 100) : 0;

      return PieChartSectionData(
        color: _chartColors[index % _chartColors.length],
        value: value,
        title: '${percentage.toStringAsFixed(0)}%',
        radius: 80,
        titleStyle: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        badgeWidget: percentage < 5 ? null : const Icon(
          Icons.circle,
          size: 0, // Hidden but kept for future expansion
          color: Colors.transparent,
        ),
        badgePositionPercentageOffset: 1.1,
      );
    }).toList();
  }
}