import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    _initialized = true;
  }

  void _onNotificationTap(NotificationResponse response) {
    print('Notification tapped: ${response.payload}');
  }

  // Request permission (Android 13+)
  Future<bool> requestPermission() async {
    if (!Platform.isAndroid) return true;

    final androidPlugin =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return false;

    // QUAN TRỌNG: Phải xin cả 2 quyền này mới chạy được trên Android 13/14
    final bool? notificationsGranted = await androidPlugin.requestNotificationsPermission();
    final bool? exactAlarmGranted = await androidPlugin.requestExactAlarmsPermission();

    print("Notification permission: $notificationsGranted");
    print("Exact alarm permission: $exactAlarmGranted");

    return (notificationsGranted ?? false);
  }

  Future<void> scheduleCheckInReminder() async {
    await _notifications.zonedSchedule(
      0,
      '⏰ Đến giờ chấm công!',
      'Nhớ check in để ghi nhận giờ vào làm việc nhé! 👋',
      _nextInstanceOf(8, 0),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'check_in_reminder',
          'Check In Reminder',
          channelDescription: 'Nhắc nhở check in hàng ngày',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          sound: RawResourceAndroidNotificationSound('notification'),
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, // BẮT BUỘC
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> scheduleCheckOutReminder() async {
    await _notifications.zonedSchedule(
      1,
      '🏃 Đến giờ tan làm!',
      'Đừng quên check out trước khi về nhé! 👋',
      _nextInstanceOf(17, 0),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'check_out_reminder',
          'Check Out Reminder',
          channelDescription: 'Nhắc nhở check out hàng ngày',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          sound: RawResourceAndroidNotificationSound('notification'),
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, // BẮT BUỘC
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  Future<void> enableAllReminders() async {
    await initialize();
    await requestPermission();

    await scheduleCheckInReminder();
    await scheduleCheckOutReminder();
  }

  Future<void> disableAllReminders() async {
    await _notifications.cancel(0);
    await _notifications.cancel(1);
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  Future<void> showTestNotification() async {
    await _notifications.show(
      999,
      '✅ Test Notification',
      'Thông báo đang hoạt động tốt!',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'test_channel',
          'Test Notifications',
          channelDescription: 'Test notification channel',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}
