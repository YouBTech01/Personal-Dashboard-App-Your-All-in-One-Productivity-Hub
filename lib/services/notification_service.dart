import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:convert';

/// Singleton service for managing notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  // Add static getter for the instance
  static NotificationService get instance => _instance;

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _notificationsEnabled = true;
  static const String _pendingNotificationsKey = 'pending_notifications';

  /// Restores pending notifications after app restart
  Future<void> restorePendingNotifications() async {
    if (!_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    final pendingNotifications =
        prefs.getStringList(_pendingNotificationsKey) ?? [];

    for (final notificationJson in pendingNotifications) {
      try {
        final notification =
            jsonDecode(notificationJson) as Map<String, dynamic>;
        final scheduledDate = DateTime.parse(notification['scheduledDate']);

        if (scheduledDate.isAfter(DateTime.now())) {
          await scheduleNotification(
            id: notification['id'],
            title: notification['title'],
            body: notification['body'],
            scheduledDate: scheduledDate,
            type: notification['type'],
            uniqueId: notification['uniqueId'],
          );
        }
      } catch (e) {
        debugPrint('Error restoring notification: $e');
      }
    }

    // Clear restored notifications
    await prefs.setStringList(_pendingNotificationsKey, []);
  }

  Future<bool> initialize() async {
    if (_initialized) {
      debugPrint('NotificationService already initialized');
      return true;
    }

    try {
      debugPrint('Starting NotificationService initialization...');

      // Initialize timezone data first
      try {
        tz.initializeTimeZones();
        debugPrint('Timezones initialized successfully');
      } catch (e) {
        debugPrint('Failed to initialize timezones: $e');
        return false;
      }

      // Request permissions early
      final permissionGranted = await _requestPermissions();
      if (!permissionGranted) {
        debugPrint('Failed to get required permissions');
        return false;
      }

      // Create notification channels for Android
      if (Platform.isAndroid) {
        await _notifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(
              const AndroidNotificationChannel(
                'default_channel',
                'Default Notifications',
                description: 'For all app notifications',
                importance: Importance.high,
                playSound: true,
                sound:
                    RawResourceAndroidNotificationSound('notification_sound'),
                enableVibration: true,
              ),
            );
      }

      // Platform-specific initialization settings
      final initSettings = InitializationSettings(
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: Platform.isIOS
            ? const DarwinInitializationSettings(
                requestAlertPermission: true,
                requestBadgePermission: true,
                requestSoundPermission: true,
              )
            : null,
      );

      // Load notification preferences
      try {
        final prefs = await SharedPreferences.getInstance();
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
        debugPrint('Notifications enabled: $_notificationsEnabled');
      } catch (e) {
        debugPrint('Failed to load notification preferences: $e');
        _notificationsEnabled = true; // Default to enabled on error
      }

      // Initialize notification plugin
      bool? initResult = await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _handleNotificationResponse,
      );

      if (initResult == null || !initResult) {
        debugPrint('Notification plugin initialization returned false or null');
        return false;
      }

      _initialized = true;
      debugPrint('NotificationService initialization completed successfully');

      // Restore any pending notifications
      await restorePendingNotifications();
      return true;
    } catch (e, stackTrace) {
      debugPrint(
          'Critical error during NotificationService initialization: $e');
      debugPrint('Stack trace: $stackTrace');
      _initialized = false;
      return false;
    }
  }

  /// Handles notification tap response
  void _handleNotificationResponse(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    // Handle notification tap based on payload
    if (response.payload != null) {
      // You can add specific handling based on payload type
      if (response.payload!.startsWith('todo_')) {
        // Handle todo notification
      } else if (response.payload!.startsWith('note_')) {
        // Handle note notification
      } else if (response.payload!.startsWith('youtube_')) {
        // Handle YouTube notification
      }
    }
  }

  /// Requests necessary permissions for notifications
  Future<bool> _requestPermissions() async {
    debugPrint('Requesting notification permissions...');
    try {
      // Request notification permission
      final notificationStatus = await Permission.notification.request();
      if (!notificationStatus.isGranted) {
        debugPrint('Notification permission denied by user');
        return false;
      }
      debugPrint(
          'Notification permission granted: ${notificationStatus.isGranted}');

      // Request exact alarms permission for Android 12 and above
      final alarmStatus = await Permission.scheduleExactAlarm.request();
      if (!alarmStatus.isGranted) {
        debugPrint('Exact alarm permission denied by user');
        return false;
      }
      debugPrint('Exact alarm permission granted: ${alarmStatus.isGranted}');

      // Verify permissions after requesting
      final notificationGranted = await Permission.notification.isGranted;
      final alarmGranted = await Permission.scheduleExactAlarm.isGranted;

      if (!notificationGranted || !alarmGranted) {
        debugPrint('Permissions verification failed after requesting');
        debugPrint('Notification: $notificationGranted, Alarm: $alarmGranted');
        return false;
      }

      return true;
    } catch (e, stackTrace) {
      debugPrint('Error requesting permissions: $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Schedules a notification with retry support
  Future<void> scheduleNotification({
    required String id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? type,
    required String uniqueId,
  }) async {
    if (!_initialized || !_notificationsEnabled) {
      debugPrint(
          'NotificationService not initialized or notifications disabled');
      return;
    }

    // Check permissions before scheduling
    if (!await Permission.notification.isGranted ||
        !await Permission.scheduleExactAlarm.isGranted) {
      debugPrint('Notification or Exact Alarm permission not granted');
      final granted = await _requestPermissions();
      if (!granted) return;
    }

    final now = DateTime.now();
    if (scheduledDate.isBefore(now)) {
      debugPrint('Cannot schedule notification for past date: $scheduledDate');
      return;
    }

    try {
      debugPrint('Scheduling notification for ID: $id at $scheduledDate');

      final androidDetails = AndroidNotificationDetails(
        'default_channel',
        'Default Notifications',
        channelDescription: 'For all app notifications',
        importance: Importance.high,
        priority: Priority.high,
        enableLights: true,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_notification',
        sound: const RawResourceAndroidNotificationSound('notification_sound'),
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      await _notifications.zonedSchedule(
        uniqueId.hashCode,
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        notificationDetails,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: '${type ?? 'default'}_$uniqueId',
      );
      debugPrint('Notification scheduled successfully');

      // Remove from pending after successful scheduling
      final prefs = await SharedPreferences.getInstance();
      final pendingNotifications =
          prefs.getStringList(_pendingNotificationsKey) ?? [];
      pendingNotifications.removeWhere((item) {
        final notification = jsonDecode(item);
        return notification['id'] == id;
      });
      await prefs.setStringList(_pendingNotificationsKey, pendingNotifications);
    } catch (e) {
      debugPrint('Error scheduling notification: $e');
      // Notification remains in pending list for later retry
    }
  }

  /// Cancels a specific notification with retry mechanism
  Future<void> cancelNotification(String id) async {
    if (!_initialized) {
      debugPrint('NotificationService not initialized');
      return;
    }
    try {
      debugPrint('Starting cancellation process for notification ID: $id');
      final beforeCancel = await _notifications.pendingNotificationRequests();
      debugPrint('Notifications before cancellation: ${beforeCancel.length}');

      // Check if notification exists before attempting to cancel
      final exists =
          beforeCancel.any((notification) => notification.id == id.hashCode);
      if (!exists) {
        debugPrint(
            'Notification ID: $id does not exist in pending notifications');
        return;
      }

      await _notifications.cancel(id.hashCode);
      debugPrint('Cancellation command executed for ID: $id');

      // Verify cancellation with retry
      for (int i = 0; i < 3; i++) {
        final afterCancel = await _notifications.pendingNotificationRequests();
        final stillExists =
            afterCancel.any((notification) => notification.id == id.hashCode);

        if (!stillExists) {
          debugPrint('Successfully cancelled notification with ID: $id');
          return;
        }

        if (i < 2) {
          debugPrint('Notification still exists, retrying cancellation...');
          await Future.delayed(const Duration(milliseconds: 100));
          await _notifications.cancel(id.hashCode);
        }
      }

      debugPrint(
          'Warning: Failed to cancel notification $id after multiple attempts');
    } catch (e) {
      debugPrint('Error cancelling notification $id: $e');
    }
  }

  /// Cancels all pending notifications
  Future<void> cancelAllNotifications() async {
    if (!_initialized) {
      debugPrint('NotificationService not initialized');
      return;
    }
    try {
      final pendingBefore = await _notifications.pendingNotificationRequests();
      debugPrint(
          'Cancelling all notifications. Current count: ${pendingBefore.length}');

      await _notifications.cancelAll();

      final pendingAfter = await _notifications.pendingNotificationRequests();
      if (pendingAfter.isEmpty) {
        debugPrint('Successfully cancelled all notifications');
      } else {
        debugPrint(
            'Warning: ${pendingAfter.length} notifications still pending after cancelAll');
      }
    } catch (e) {
      debugPrint('Error cancelling all notifications: $e');
    }
  }

  /// Gets a list of all pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    if (!_initialized) {
      debugPrint('NotificationService not initialized');
      return [];
    }
    return await _notifications.pendingNotificationRequests();
  }

  /// Enables or disables notifications globally
  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', enabled);
    _notificationsEnabled = enabled;

    if (!enabled) {
      await cancelAllNotifications();
    }
  }
}
