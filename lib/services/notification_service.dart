import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/dose_history.dart';
import '../models/reminder_item.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  final List<ReminderItem> _savedReminders = <ReminderItem>[];
  final List<DoseHistory> _histories = <DoseHistory>[];
  String? _pendingAlarmPayload;
  String? _lastHandledPayload;

  List<ReminderItem> get reminders => List<ReminderItem>.unmodifiable(_savedReminders);
  List<DoseHistory> get histories => List<DoseHistory>.unmodifiable(_histories);

  static Map<String, dynamic> parsePayload(String payload) {
    final decoded = jsonDecode(payload);
    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  }

  Future<void> initialize({required void Function(String payload) onAlarmPayload}) async {
    await _configureLocalTimeZone();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null) {
          _pendingAlarmPayload = payload;
          onAlarmPayload(payload);
        }
      },
    );

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      _pendingAlarmPayload = launchDetails?.notificationResponse?.payload;
    }

    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();
    await androidPlugin?.requestFullScreenIntentPermission();
  }

  Future<void> refreshPendingAlarmPayload() async {
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      final payload = launchDetails?.notificationResponse?.payload;
      if (payload != null && payload != _lastHandledPayload) {
        _pendingAlarmPayload = payload;
      }
    }
  }

  String? takePendingAlarmPayload() {
    final payload = _pendingAlarmPayload;
    _pendingAlarmPayload = null;
    _lastHandledPayload = payload;
    return payload;
  }

  Future<void> clearActiveNotification(int? id) async {
    if (id == null) return;
    await _plugin.cancel(id);
  }

  Future<void> handleForegroundTrigger(ReminderItem item) async {
    await _plugin.cancel(item.id);
    await scheduleDailyReminder(item);
  }

  Future<void> scheduleDailyReminder(ReminderItem item) async {
    _savedReminders.removeWhere((e) => e.id == item.id);
    _savedReminders.add(item);

    final scheduledDate = _nextInstanceOfTime(item.time);
    await _plugin.zonedSchedule(
      item.id,
      '복약 시간입니다',
      '${item.medicineName} 복용할 시간이에요.',
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'medication_channel',
          '복약 알림',
          channelDescription: '정해진 시간에 복약 알림을 제공합니다.',
          importance: Importance.max,
          priority: Priority.max,
          playSound: false,
          enableVibration: false,
          silent: true,
          category: AndroidNotificationCategory.call,
          visibility: NotificationVisibility.public,
          fullScreenIntent: true,
          audioAttributesUsage: AudioAttributesUsage.alarm,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: jsonEncode({
        'type': 'alarm',
        'medicineName': item.medicineName,
        'reminderId': item.id,
        'notificationId': item.id,
      }),
    );
  }

  Future<void> scheduleSnoozeAfter3Minutes({required String medicineName, int? reminderId}) async {
    final id = DateTime.now().millisecondsSinceEpoch.remainder(1 << 31);

    await _plugin.zonedSchedule(
      id,
      '복약 재알림',
      '$medicineName 복용 알림입니다. 다시 확인해주세요.',
      tz.TZDateTime.now(tz.local).add(const Duration(minutes: 3)),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'medication_channel',
          '복약 알림',
          channelDescription: '정해진 시간에 복약 알림을 제공합니다.',
          importance: Importance.max,
          priority: Priority.max,
          playSound: false,
          enableVibration: false,
          silent: true,
          category: AndroidNotificationCategory.call,
          visibility: NotificationVisibility.public,
          fullScreenIntent: true,
          audioAttributesUsage: AudioAttributesUsage.alarm,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: jsonEncode({
        'type': 'alarm',
        'medicineName': medicineName,
        'reminderId': reminderId,
        'notificationId': id,
      }),
    );
  }

  Future<void> cancelReminder(int id) async {
    await _plugin.cancel(id);
    _savedReminders.removeWhere((e) => e.id == id);
  }

  void recordDose(String medicineName) {
    _histories.add(DoseHistory(medicineName: medicineName, completedAt: DateTime.now()));
  }

  Future<void> _configureLocalTimeZone() async {
    tz.initializeTimeZones();
    final timezoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezoneName));
  }

  tz.TZDateTime _nextInstanceOfTime(TimeOfDay timeOfDay) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, timeOfDay.hour, timeOfDay.minute);

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
