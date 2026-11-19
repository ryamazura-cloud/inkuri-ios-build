import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'reminders.dart';

/// Android can report GMT for a device with the zero-offset default zone.
/// The bundled IANA database does not include every legacy GMT/UTC alias.
tz.Location reminderLocation(String identifier) =>
    identifier == 'GMT' || identifier == 'UTC'
    ? tz.UTC
    : tz.getLocation(identifier);

/// Uses calendar dates rather than adding 24 hours, including across DST.
tz.TZDateTime nextReminder(tz.TZDateTime now, int hour, int minute) {
  var date = tz.TZDateTime(
    now.location,
    now.year,
    now.month,
    now.day,
    hour,
    minute,
  );
  if (!date.isAfter(now)) {
    date = tz.TZDateTime(
      now.location,
      now.year,
      now.month,
      now.day + 1,
      hour,
      minute,
    );
  }
  return date;
}

class LocalReminderBackend implements ReminderBackend {
  LocalReminderBackend({FlutterLocalNotificationsPlugin? plugin})
    : plugin = plugin ?? FlutterLocalNotificationsPlugin();
  final FlutterLocalNotificationsPlugin plugin;
  static const dailyId = 71001, previewId = 71002;
  Future<void>? _initializing;
  @override
  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  Future<void> _init() async {
    try {
      await (_initializing ??= _initialize());
    } catch (_) {
      _initializing = null;
      rethrow;
    }
  }

  Future<void> _initialize() async {
    tzdata.initializeTimeZones();
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_inkuri'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
  }

  @override
  Future<bool> permission({required bool request}) async {
    if (!supported) return false;
    await _init();
    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      if (request) await android.requestNotificationsPermission();
      return await android.areNotificationsEnabled() ?? false;
    }
    final ios = plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (request) {
      await ios?.requestPermissions(alert: true, sound: true, badge: false);
    }
    return (await ios?.checkPermissions())?.isEnabled ?? false;
  }

  static const details = NotificationDetails(
    android: AndroidNotificationDetails(
      'inkuri_study_v1',
      '学習リマインダー',
      channelDescription: '設定した時刻に英語学習をお知らせします',
      icon: 'ic_stat_inkuri',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      presentBadge: false,
    ),
  );
  @override
  Future<void> schedule(ReminderSettings settings) async {
    await _init();
    final zone = await FlutterTimezone.getLocalTimezone();
    final location = reminderLocation(zone.identifier);
    await plugin.zonedSchedule(
      id: dailyId,
      title: 'インクリ｜英語の冒険を続けよう',
      body: '今日も少しだけ、英語を声に出してみませんか？',
      scheduledDate: nextReminder(
        tz.TZDateTime.now(location),
        settings.hour,
        settings.minute,
      ),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'study_reminder',
    );
  }

  @override
  Future<void> cancel() async {
    await _init();
    await plugin.cancel(id: dailyId);
    await plugin.cancel(id: previewId);
  }

  @override
  Future<void> preview() async {
    await _init();
    await plugin.show(
      id: previewId,
      title: 'インクリ｜テスト通知',
      body: 'このように学習の時間をお知らせします。',
      notificationDetails: details,
      payload: 'study_reminder',
    );
  }

  @override
  Future<void> openSettings() async {
    await _init();
    await plugin.openAppNotificationSettings();
  }
}
