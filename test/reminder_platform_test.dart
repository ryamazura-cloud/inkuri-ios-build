import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:phrase_flow/reminders.dart';
import 'package:phrase_flow/reminder_notifications.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  const timezone = MethodChannel('flutter_timezone');
  final calls = <MethodCall>[];
  setUp(() {
    calls.clear();
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if ([
            'initialize',
            'requestNotificationsPermission',
            'areNotificationsEnabled',
          ].contains(call.method)) {
            return true;
          }
          return null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          timezone,
          (_) async => {'identifier': 'Asia/Tokyo'},
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(timezone, null);
  });
  test(
    'daily schedule uses one stable ID, local time and inexact daily repeat',
    () async {
      final backend = LocalReminderBackend();
      expect(await backend.permission(request: false), isTrue);
      expect(
        calls.any((c) => c.method == 'requestNotificationsPermission'),
        isFalse,
      );
      await backend.schedule(
        const ReminderSettings(enabled: true, hour: 7, minute: 15),
      );
      await backend.schedule(
        const ReminderSettings(enabled: true, hour: 22, minute: 45),
      );
      final scheduled = calls
          .where((c) => c.method == 'zonedSchedule')
          .toList();
      expect(scheduled.length, 2);
      for (final call in scheduled) {
        final args = call.arguments as Map;
        expect(args['id'], LocalReminderBackend.dailyId);
        expect(args['timeZoneName'], 'Asia/Tokyo');
        expect(args['matchDateTimeComponents'], DateTimeComponents.time.index);
        expect(
          (args['platformSpecifics'] as Map)['scheduleMode'],
          'inexactAllowWhileIdle',
        );
      }
      expect(
        scheduled.last.arguments['scheduledDateTime'],
        contains('22:45:00'),
      );
      expect(calls.where((c) => c.method == 'initialize').length, 1);
    },
  );
  test(
    'preview is separate from daily alarm and disable cancels both IDs',
    () async {
      final backend = LocalReminderBackend();
      expect(await backend.permission(request: true), isTrue);
      await backend.preview();
      expect(
        calls.singleWhere((c) => c.method == 'show').arguments['id'],
        LocalReminderBackend.previewId,
      );
      expect(calls.any((c) => c.method == 'zonedSchedule'), isFalse);
      await backend.cancel();
      expect(
        calls.where((c) => c.method == 'cancel').map((c) => c.arguments['id']),
        [LocalReminderBackend.dailyId, LocalReminderBackend.previewId],
      );
    },
  );
}
