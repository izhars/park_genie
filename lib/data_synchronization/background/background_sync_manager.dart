import 'package:flutter/foundation.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../DatabaseHelper.dart';
import '../../data/services/ApiConfig.dart';
import '../DatabaseSyncService.dart';

// Define constants for alarm IDs
const int PERIODIC_SYNC_ID = 1001;
const int RETRY_SYNC_ID = 1002;
const int IMMEDIATE_SYNC_ID = 1003;

// Define notification channel for sync status
const String SYNC_NOTIFICATION_CHANNEL_ID = 'database_sync_channel';
const String SYNC_NOTIFICATION_CHANNEL_NAME = 'Database Synchronization';

class BackgroundSyncManager {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
  FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // Initialize Android Alarm Manager
    await AndroidAlarmManager.initialize();

    // Initialize notifications
    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('app_icon');

    const InitializationSettings initSettings =
    InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(initSettings);

    // Create notification channel (Android 8.0+)
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      SYNC_NOTIFICATION_CHANNEL_ID,
      SYNC_NOTIFICATION_CHANNEL_NAME,
      importance: Importance.low,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Check if we need to resume any sync operations after app restart
    await _checkPendingSyncs();
  }

  static Future<void> _checkPendingSyncs() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSyncAttempt = prefs.getString('last_sync_attempt');
    final syncPending = prefs.getBool('sync_pending') ?? false;

    if (syncPending && lastSyncAttempt != null) {
      final lastAttemptTime = DateTime.parse(lastSyncAttempt);
      final now = DateTime.now();

      // If last attempt was more than 1 hour ago, retry sync
      if (now.difference(lastAttemptTime).inHours >= 1) {
        await scheduleImmediateSync();
      }
    }
  }

  static Future<void> performManualSync() async {
    await _backgroundSyncCallback();
  }

  // Main sync callback - static method that can be called from isolate
  @pragma('vm:entry-point')
  static Future<void> _backgroundSyncCallback() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_sync_attempt', DateTime.now().toIso8601String());
      await prefs.setBool('sync_pending', true);

      final dbHelper = DatabaseHelper.instance;
      final baseUrl = ApiConfig.baseUrl; // 👈 Use centralized base URL

      final syncService = DatabaseSyncService(
        baseUrl: baseUrl,
        dbHelper: dbHelper,
      );

      await syncService.processSyncQueue();

      // Push only (upload to server)
      bool pushSuccess = await syncService.pushAllToServer();
      // final syncResult = await syncService.syncDatabase();

      await prefs.setBool('sync_pending', false);
      await prefs.setString('last_successful_sync', DateTime.now().toIso8601String());

      if (pushSuccess) {
        await _showSyncNotification(
          'Data Sync Complete',
          'All data has been synchronized with the server',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Background sync error: $e');
      }

      await AndroidAlarmManager.oneShotAt(
        DateTime.now().add(const Duration(minutes: 15)),
        RETRY_SYNC_ID,
        _backgroundSyncCallback,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
      );

      await _showSyncNotification(
        'Sync Failed',
        'Will retry in 15 minutes',
      );
    }
  }

  // Display a notification about sync status
  static Future<void> _showSyncNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      SYNC_NOTIFICATION_CHANNEL_ID,
      SYNC_NOTIFICATION_CHANNEL_NAME,
      importance: Importance.low,
      priority: Priority.low,
      showWhen: false,
    );

    const NotificationDetails details = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      0,  // Notification ID
      title,
      body,
      details,
    );
  }

  // Schedule periodic sync operation
  static Future<void> schedulePeriodicSync({Duration interval = const Duration(hours: 1)}) async {
    await AndroidAlarmManager.periodic(
      interval,
      PERIODIC_SYNC_ID,
      _backgroundSyncCallback,
      wakeup: true,
      exact: false,  // Exact timing not needed for periodic sync
      rescheduleOnReboot: true,
    );

    // Save sync schedule details
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sync_schedule', interval.inMinutes.toString());
    await prefs.setBool('sync_enabled', true);
  }

  // Schedule an immediate one-time sync
  static Future<void> scheduleImmediateSync() async {
    await AndroidAlarmManager.oneShot(
      const Duration(seconds: 5),  // Start after 5 seconds
      IMMEDIATE_SYNC_ID,
      _backgroundSyncCallback,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: false,  // No need to reschedule one-time immediate syncs
    );
  }

  // Cancel all scheduled sync operations
  static Future<void> cancelAllSyncTasks() async {
    await AndroidAlarmManager.cancel(PERIODIC_SYNC_ID);
    await AndroidAlarmManager.cancel(RETRY_SYNC_ID);
    await AndroidAlarmManager.cancel(IMMEDIATE_SYNC_ID);

    // Update preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sync_enabled', false);
  }

  // Get the current sync status
  static Future<Map<String, dynamic>> getSyncStatus() async {
    final prefs = await SharedPreferences.getInstance();

    return {
      'enabled': prefs.getBool('sync_enabled') ?? false,
      'lastSyncAttempt': prefs.getString('last_sync_attempt'),
      'lastSuccessfulSync': prefs.getString('last_successful_sync'),
      'syncPending': prefs.getBool('sync_pending') ?? false,
      'syncInterval': prefs.getString('sync_schedule') ?? '60',
    };
  }
}