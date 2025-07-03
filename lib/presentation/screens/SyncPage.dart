import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../DatabaseHelper.dart';
import '../../data/services/PackageData.dart';
import '../../data_synchronization/DatabaseSyncService.dart';
import '../../data_synchronization/background/background_sync_manager.dart';
import 'LockScreenPage.dart';
import 'LoginPage.dart';

class SyncPage extends StatefulWidget {
  final String baseUrl;
  final bool allowSkip;
  final bool isInitialSync;
  final bool isLoggedIn;
  final VoidCallback? onSyncComplete;

  const SyncPage({
    Key? key,
    required this.baseUrl,
    this.allowSkip = false,
    this.isInitialSync = false,
    this.isLoggedIn = false,
    this.onSyncComplete,
  }) : super(key: key);

  @override
  _SyncPageState createState() => _SyncPageState();
}

class _SyncPageState extends State<SyncPage> with TickerProviderStateMixin {
  late DatabaseSyncService _syncService;
  late DatabaseHelper _dbHelper;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  bool _isSyncing = false;
  bool _isInitialized = false;
  String _syncMessage = 'Initializing...';
  double _syncProgress = 0.0;
  SyncStatus _syncStatus = SyncStatus.preparing;
  int _retryCount = 0;
  static const int maxRetries = 3;
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeApp();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _animationController.forward();
  }

  Future<void> _initializeApp() async {
    try {
      setState(() {
        _syncMessage = 'Initializing database...';
        _syncProgress = 0.1;
      });

      // Initialize DatabaseHelper and other services
      _dbHelper = DatabaseHelper.instance;
      await _dbHelper.addModifiedTimestampColumn(); // Make sure the new column is added if not exists

      setState(() {
        _syncMessage = 'Setting up background sync...';
        _syncProgress = 0.2;
      });

      await BackgroundSyncManager.initialize(); // Initialize background sync manager

      setState(() {
        _syncMessage = 'Initializing sync service...';
        _syncProgress = 0.4;
      });

      _syncService = DatabaseSyncService(
        baseUrl: widget.baseUrl,
        dbHelper: _dbHelper,
      );

      _isInitialized = true;

      setState(() {
        _syncMessage = 'Initialization complete!';
        _syncProgress = 0.5;
      });

      // Small delay to show initialization complete message
      await Future.delayed(const Duration(milliseconds: 500));

      // Start sync process
      await _startSync();

    } catch (e) {
      print('Initialization error: $e');
      setState(() {
        _syncStatus = SyncStatus.failed;
        _syncMessage = 'Initialization failed: ${e.toString()}';
      });
    }
  }

  Future<void> _startSync() async {
    if (_isSyncing || !_isInitialized) return;

    setState(() {
      _isSyncing = true;
      _syncStatus = SyncStatus.checking;
      _syncMessage = 'Checking internet connection...';
      _syncProgress = 0.6;
    });

    _startProgressTimer();

    try {
      await _performSyncSequence();
    } catch (e) {
      await _handleSyncError(e);
    } finally {
      _stopProgressTimer();
      setState(() {
        _isSyncing = false;
      });
    }
  }

  Future<void> _performSyncSequence() async {
    // Step 1: Check internet connection
    if (!await _checkInternetConnection()) return;

    try {
      await _syncMainDatabase();
    } catch (e) {
      print("❌ Error syncing main database: $e");
    }

    try {
      print("Logined, added");
      await _syncUserPackageData();
    } catch (e) {
      print("❌ Error syncing user package: $e");
    }

    try {
      await _processSyncQueue();
    } catch (e) {
      print("❌ Error processing sync queue: $e");
    }

    try {
      await _completeSyncProcess();
    } catch (e) {
      print("❌ Error completing sync process: $e");
    }

    print("✅ Sync sequence executed.");
  }


  Future<bool> _checkInternetConnection() async {
    _updateSyncState(
      SyncStatus.checking,
      'Checking internet connection...',
      0.65,
    );

    bool hasInternet = await _syncService.hasInternetConnection();

    if (!hasInternet) {
      await _handleNoInternet();
      return false;
    }

    return true;
  }

  Future<void> _syncMainDatabase() async {
    _updateSyncState(
      SyncStatus.syncing,
      'Syncing database with server...',
      0.75,
    );

    // Pull only (download from server)
    bool pullSuccess = await _syncService.pullAllFromServer();

    if (!pullSuccess) {
      throw SyncException('Database sync failed');
    }
  }

  Future<void> _syncUserPackageData() async {
    _updateSyncState(
      SyncStatus.syncing,
      'Syncing user package data...',
      0.85,
    );

    await _syncUserPackage();
  }

  Future<void> _processSyncQueue() async {
    _updateSyncState(
      SyncStatus.syncing,
      'Processing pending operations...',
      0.95,
    );

    await _syncService.processSyncQueue();
  }

  Future<void> _completeSyncProcess() async {
    _updateSyncState(
      SyncStatus.completed,
      'Sync completed successfully!',
      1.0,
    );

    await Future.delayed(const Duration(seconds: 2));

    if (widget.onSyncComplete != null) {
      widget.onSyncComplete!();
    }

    _navigateToNextScreen();
  }

  Future<void> _handleNoInternet() async {
    _updateSyncState(
      SyncStatus.failed,
      'No internet connection available',
      0.6,
    );

    await Future.delayed(const Duration(seconds: 2));

    if (widget.allowSkip) {
      await _showOfflineModeDialog();
    } else {
      _navigateToNextScreen();
    }
  }

  Future<void> _handleSyncError(dynamic error) async {
    print('Sync error: $error');

    if (_retryCount < maxRetries) {
      _retryCount++;
      _updateSyncState(
        SyncStatus.retrying,
        'Sync failed. Retrying... (${_retryCount}/$maxRetries)',
        0.7,
      );

      await Future.delayed(Duration(seconds: _retryCount * 2));
      await _startSync();
      return;
    }

    _updateSyncState(
      SyncStatus.failed,
      'Sync failed after $maxRetries attempts',
      0.6,
    );

    await Future.delayed(const Duration(seconds: 3));

    if (widget.allowSkip) {
      await _showSyncFailedDialog();
    } else {
      _navigateToNextScreen();
    }
  }

  Future<void> _syncUserPackage() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString("token");

      if (token == null || token.isEmpty) {
        throw SyncException('Authentication token not found');
      }

      final url = Uri.parse('${widget.baseUrl}/users/package');
      print('Fetching user package from: $url');

      final response = await http.get(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('Request timed out'),
      );

      if (response.statusCode == 200) {
        await _processUserPackageResponse(response.body);
      } else if (response.statusCode == 401) {
        throw SyncException('Authentication failed. Please login again.');
      } else {
        throw SyncException(
            'Failed to fetch user package: ${response.statusCode} - ${response.reasonPhrase}'
        );
      }
    } catch (e) {
      print('Error syncing user package: $e');
      rethrow;
    }
  }

  Future<void> _processUserPackageResponse(String responseBody) async {
    final responseData = json.decode(responseBody) as Map<String, dynamic>;
    print("Received response data: $responseData");

    // Extract user data from the nested structure
    final user = responseData["user"] as Map<String, dynamic>;
    print("Received user data: $user");

    final packageList = user["packageList"] as List<dynamic>? ?? [];
    print("Package data: $packageList");

    final packageData = _buildPackageData(user, packageList);
    final package = PackageData.fromMap(packageData);

    await _dbHelper.saveUserData([package]);
    print("User package data saved to local DB: ${package.toMap()}");
  }

  Map<String, dynamic> _buildPackageData(
      Map<String, dynamic> user,
      List<dynamic> packageList,
      ) {
    if (packageList.isEmpty) {
      return _getDefaultPackageData(user);
    }

    final firstPackage = packageList[0] as Map<String, dynamic>;

    return {
      'userId': user["id"] ?? "",
      'name': user["name"] ?? "Guest",
      'email': user["email"] ?? "",
      'title': firstPackage["title"] ?? "No Package",
      'price': (firstPackage["price"] as num?)?.toDouble() ?? 0.0,
      'duration': firstPackage["duration"] ?? "N/A",
      'packageValidTill': user["packageValidTill"]?.toString() ?? "N/A",
      'durationInDays': firstPackage["durationInDays"] ?? 0,
      'maxEntriesPerDay': firstPackage["maxEntriesPerDay"] ?? 0,
      'isActive': firstPackage["isActive"] ?? false,
    };
  }

  Map<String, dynamic> _getDefaultPackageData(Map<String, dynamic> user) {
    return {
      'userId': user["id"] ?? "",
      'name': user["name"] ?? "Guest",
      'email': user["email"] ?? "",
      'title': "No Package",
      'price': 0.0,
      'duration': "N/A",
      'packageValidTill': "N/A",
      'durationInDays': 0,
      'maxEntriesPerDay': 0,
      'isActive': false,
    };
  }

  void _updateSyncState(SyncStatus status, String message, double progress) {
    if (mounted) {
      setState(() {
        _syncStatus = status;
        _syncMessage = message;
        _syncProgress = progress;
      });
    }
  }

  void _startProgressTimer() {
    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_syncProgress < 0.98 && _syncStatus == SyncStatus.syncing) {
        setState(() {
          _syncProgress += 0.001;
        });
      }
    });
  }

  void _stopProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  Future<void> _showOfflineModeDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Offline Mode'),
          content: const Text(
            'No internet connection available. You can continue in offline mode, but some features may be limited.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Retry'),
              onPressed: () {
                Navigator.of(context).pop();
                _retryCount = 0;
                _startSync();
              },
            ),
            TextButton(
              child: const Text('Continue Offline'),
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToNextScreen();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showSyncFailedDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sync Failed'),
          content: const Text(
            'Unable to sync data after multiple attempts. You can continue with locally stored data or try again.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Retry'),
              onPressed: () {
                Navigator.of(context).pop();
                _retryCount = 0;
                _startSync();
              },
            ),
            TextButton(
              child: const Text('Continue'),
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToNextScreen();
              },
            ),
          ],
        );
      },
    );
  }

  void _navigateToNextScreen() {
    if (mounted) {
      if (widget.isLoggedIn) {
        // User is logged in, go to lock screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => LockScreenPage(),
          ),
        );
      } else {
        // User is not logged in, go to login page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => LockScreenPage(),
          ),
        );
      }
    }
  }

  Widget _buildSyncStatusIcon() {
    switch (_syncStatus) {
      case SyncStatus.completed:
        return const Icon(
          Icons.check_circle,
          color: Colors.green,
          size: 48,
        );
      case SyncStatus.failed:
        return const Icon(
          Icons.error,
          color: Colors.red,
          size: 48,
        );
      case SyncStatus.retrying:
        return const Icon(
          Icons.refresh,
          color: Colors.orange,
          size: 48,
        );
      default:
        return const CircularProgressIndicator(
          strokeWidth: 3,
        );
    }
  }

  Color _getProgressColor() {
    switch (_syncStatus) {
      case SyncStatus.completed:
        return Colors.green;
      case SyncStatus.failed:
        return Colors.red;
      case SyncStatus.retrying:
        return Colors.orange;
      default:
        return Theme.of(context).primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // App Logo or Icon
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            widget.isInitialSync ? Icons.system_update : Icons.sync,
                            size: 48,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),

                        const SizedBox(height: 40),

                        // Sync Status Icon
                        _buildSyncStatusIcon(),

                        const SizedBox(height: 30),

                        // Progress Bar
                        Container(
                          width: double.infinity,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: _syncProgress,
                            child: Container(
                              decoration: BoxDecoration(
                                color: _getProgressColor(),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Progress Percentage
                        Text(
                          '${(_syncProgress * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600],
                          ),
                        ),

                        const SizedBox(height: 30),

                        // Sync Message
                        Text(
                          _syncMessage,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 50),

                        // Skip button (if allowed)
                        if (widget.allowSkip && _isInitialized)
                          TextButton(
                            onPressed: _isSyncing ? null : _navigateToNextScreen,
                            child: Text(
                              'Skip Sync',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _progressTimer?.cancel();
    super.dispose();
  }
}

// Enums and Custom Exception Classes
enum SyncStatus {
  preparing,
  checking,
  syncing,
  retrying,
  completed,
  failed,
}

class SyncException implements Exception {
  final String message;
  const SyncException(this.message);

  @override
  String toString() => 'SyncException: $message';
}