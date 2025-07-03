import 'package:flutter/material.dart';
import 'package:park_genie/presentation/screens/SettingsScreen.dart';
import 'BuyPackageScreen.dart';

class PurchaseSuccessScreen extends StatefulWidget {
  final String packageTitle;
  final String validTill;
  final Color color;
  final dynamic dbHelper;

  const PurchaseSuccessScreen({
    super.key,
    required this.packageTitle,
    required this.validTill,
    required this.color,
    required this.dbHelper,
  });

  @override
  _PurchaseSuccessScreenState createState() => _PurchaseSuccessScreenState();
}

class _PurchaseSuccessScreenState extends State<PurchaseSuccessScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return WillPopScope(
      onWillPop: () async {
        _navigateToBuyPackageScreen(context);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [widget.color.withOpacity(0.8), widget.color],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          title: const Text(
            'Purchase Successful',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 20),
            onPressed: () => _navigateToBuyPackageScreen(context),
          ),
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.scaffoldBackgroundColor,
                widget.color.withOpacity(0.1),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: Icon(
                          Icons.check_circle,
                          color: widget.color,
                          size: 80,
                          semanticLabel: 'Success',
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Congratulations!',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: widget.color,
                          fontFamily: 'Poppins',
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'You have successfully subscribed to:',
                        style: TextStyle(
                          fontSize: 16,
                          color: theme.textTheme.bodyLarge?.color,
                          fontFamily: 'Roboto',
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.packageTitle,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: widget.color,
                          fontFamily: 'Poppins',
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Valid until: ${_formatDate(widget.validTill)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontFamily: 'Roboto',
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      _buildGoToSettingsButton(context, theme),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoToSettingsButton(BuildContext context, ThemeData theme) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(from: 0.8),
      onTapUp: (_) => _controller.reverse(from: 1.0),
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 0.95).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
        ),
        child: ElevatedButton(
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => SettingsScreen(dbHelper: widget.dbHelper),
                settings: const RouteSettings(name: 'SettingsScreen'),
              ),
                  (route) => false,
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.color,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            elevation: 5,
            shadowColor: widget.color.withOpacity(0.4),
          ),
          child: const Text(
            'Go to Settings',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'Poppins',
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToBuyPackageScreen(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => BuyPackageScreen(dbHelper: widget.dbHelper),
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return isoDate;
    }
  }
}