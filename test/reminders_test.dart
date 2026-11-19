import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phrase_flow/reminders.dart';
import 'package:phrase_flow/reminder_notifications.dart';
import 'package:phrase_flow/reminder_settings_page.dart';
import 'package:phrase_flow/main.dart';
import 'package:phrase_flow/store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'widget_test.dart' show MemoryStore, q, tapText;

class MemoryReminderStore implements ReminderStore {
  ReminderSettings value = const ReminderSettings();
  bool fail = false;
  @override
  Future<ReminderSettings> load() async => value;
  @override
  Future<void> save(ReminderSettings settings) async {
    if (fail) throw StateError('disk full');
    value = settings;
  }
}

class FakeReminderBackend implements ReminderBackend {
  bool allowed = true;
  int requests = 0, previews = 0, cancellations = 0;
  final scheduled = <ReminderSettings>[];
  Completer<void>? blocker;
  @override
  bool get supported => true;
  @override
  Future<bool> permission({required bool request}) async {
    if (request) requests++;
    return allowed;
  }

  @override
  Future<void> schedule(ReminderSettings settings) async {
    final pending = blocker;
    blocker = null;
    if (pending != null) await pending.future;
    scheduled.add(settings);
  }

  @override
  Future<void> cancel() async {
    cancellations++;
  }

  @override
  Future<void> preview() async {
    previews++;
  }

  @override
  Future<void> openSettings() async {}
}

class FirstRunPreferences extends Fake implements SharedPreferencesAsync {
  final values = <String, Object>{};
  @override
  Future<bool?> getBool(String key) async => values[key] as bool?;
  @override
  Future<String?> getString(String key) async => values[key] as String?;
  @override
  Future<void> setBool(String key, bool value) async => values[key] = value;
  @override
  Future<void> setString(String key, String value) async => values[key] = value;
}

void main() {
  late MemoryReminderStore store;
  late FakeReminderBackend backend;
  late ReminderManager manager;
  setUp(() {
    store = MemoryReminderStore();
    backend = FakeReminderBackend();
    manager = ReminderManager(store: store, backend: backend);
  });
  testWidgets(
    'first launch opens only the purpose then reminders without prompting when no grammar is loaded',
    (tester) async {
      final preferences = FirstRunPreferences();
      final progress = LocalProgressStore(preferences: preferences);
      Future<void> open() async {
        await tester.pumpWidget(
          PhraseFlowApp(
            store: progress,
            claimFirstRun: progress.claimFirstRun,
            reminders: manager,
            loadCatalog: () async => [q],
          ),
        );
        await tester.pumpAndSettle();
      }

      await open();
      expect(find.text('1 / 6'), findsNothing);
      expect(find.text('操作を試す'), findsOneWidget);
      expect(find.textContaining('Thank you'), findsOneWidget);
      expect(find.byType(ReminderSettingsPage), findsNothing);
      await tester.tap(find.byTooltip('使い方を閉じる'));
      await tester.pumpAndSettle();
      expect(find.byType(ReminderSettingsPage), findsOneWidget);
      expect(store.value.enabled, isFalse);
      expect(backend.requests, 0);
      await tester.pumpWidget(const SizedBox());
      await open();
      expect(find.text('1 / 6'), findsNothing);
      expect(find.byType(ReminderSettingsPage), findsNothing);
      final existing = FirstRunPreferences()
        ..values[LocalProgressStore.key] = (await progress.load()).encode();
      expect(
        await LocalProgressStore(preferences: existing).claimFirstRun(),
        isFalse,
      );
    },
  );
  test('new install is opt-in and restoring never prompts', () async {
    await manager.restore();
    expect(store.value.enabled, isFalse);
    expect(backend.requests, 0);
    expect(backend.scheduled, isEmpty);
    store.value = const ReminderSettings(enabled: true, hour: 7, minute: 30);
    await manager.restore();
    expect(backend.requests, 0);
    expect(backend.scheduled.single.timeLabel, '07:30');
  });
  test('permission refusal never enables or overwrites the reminder', () async {
    backend.allowed = false;
    await expectLater(
      manager.save(const ReminderSettings(enabled: true)),
      throwsA(isA<ReminderPermissionDenied>()),
    );
    expect(store.value.enabled, isFalse);
    expect(backend.scheduled, isEmpty);
    expect(backend.cancellations, 0);
  });
  test(
    'time change replaces saved time; off cancels even when OS permission is denied',
    () async {
      await manager.save(
        const ReminderSettings(enabled: true, hour: 8, minute: 5),
      );
      await manager.save(
        const ReminderSettings(enabled: true, hour: 23, minute: 59),
      );
      expect(store.value.timeLabel, '23:59');
      backend.allowed = false;
      await manager.save(
        const ReminderSettings(enabled: false, hour: 23, minute: 59),
      );
      expect(backend.requests, 2);
      expect(backend.cancellations, 1);
      expect(store.value.enabled, isFalse);
    },
  );
  test('disk failure rolls schedule back to previously saved time', () async {
    store.value = const ReminderSettings(enabled: true, hour: 7);
    store.fail = true;
    await expectLater(
      manager.save(const ReminderSettings(enabled: true, hour: 22)),
      throwsStateError,
    );
    expect(store.value.hour, 7);
    expect(backend.scheduled.map((s) => s.hour), [22, 7]);
  });
  test(
    'preview does not opt into daily reminders or change their time',
    () async {
      final before = store.value.encode();
      await manager.preview();
      expect(backend.previews, 1);
      expect(store.value.encode(), before);
      expect(backend.scheduled, isEmpty);
    },
  );
  test('foreground restore waits for an in-flight user save', () async {
    backend.blocker = Completer<void>();
    final release = backend.blocker!;
    final save = manager.save(const ReminderSettings(enabled: true, hour: 9));
    await Future<void>.delayed(Duration.zero);
    final restore = manager.restore();
    release.complete();
    await Future.wait([save, restore]);
    expect(backend.scheduled.map((s) => s.hour), [9, 9]);
    expect(backend.requests, 1);
  });
  test(
    'invalid preference is rejected without changing the OS schedule',
    () async {
      await expectLater(
        manager.save(const ReminderSettings(enabled: true, hour: 24)),
        throwsFormatException,
      );
      expect(backend.requests, 0);
      expect(backend.scheduled, isEmpty);
      expect(
        ReminderSettings.decode(
          const ReminderSettings(hour: 0, minute: 0).encode(),
        ).timeLabel,
        '00:00',
      );
      expect(
        () => ReminderSettings.decode('{"enabled":true,"hour":5,"minute":60}'),
        throwsFormatException,
      );
    },
  );
  test(
    'GMT and UTC identifiers use UTC without losing IANA timezone offsets',
    () {
      tzdata.initializeTimeZones();
      expect(reminderLocation('GMT'), same(tz.UTC));
      expect(reminderLocation('UTC'), same(tz.UTC));
      expect(
        reminderLocation('Asia/Tokyo').currentTimeZone.offset,
      const Duration(hours: 9),
      );
      expect(
        () => reminderLocation('Invalid/Unknown'),
        throwsA(isA<tz.LocationNotFoundException>()),
      );
    },
  );
  test('next occurrence respects midnight and equal-time tomorrow', () {
    tzdata.initializeTimeZones();
    final zone = reminderLocation('Asia/Tokyo');
    expect(
      nextReminder(tz.TZDateTime(zone, 2026, 12, 31, 23, 59), 0, 0),
      tz.TZDateTime(zone, 2027, 1, 1),
    );
    expect(
      nextReminder(tz.TZDateTime(zone, 2026, 11, 3, 20), 20, 0),
      tz.TZDateTime(zone, 2026, 11, 4, 20),
    );
    expect(
      nextReminder(tz.TZDateTime(zone, 2026, 11, 3, 19), 20, 0),
      tz.TZDateTime(zone, 2026, 11, 3, 20),
    );
  });
  test('calendar scheduling across DST keeps selected wall-clock time', () {
    tzdata.initializeTimeZones();
    final zone = reminderLocation('America/New_York');
    final before = tz.TZDateTime(zone, 2026, 3, 7, 21);
    final next = nextReminder(before, 20, 0);
    expect(next.hour, 20);
    expect(next.day, 8);
    expect(next.timeZoneOffset, const Duration(hours: -4));
  });
  testWidgets('top notification entrance fits at 320px with enlarged text', (
    t,
  ) async {
    manager = ReminderManager(store: store, backend: backend);
    t.view.physicalSize = const Size(320, 568);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      t.view.resetPhysicalSize();
      t.view.resetDevicePixelRatio();
      t.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await t.pumpWidget(
      PhraseFlowApp(
        store: MemoryStore(),
        loadCatalog: () async => [q],
        reminders: manager,
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('学習リマインダー'));
    await t.pumpAndSettle();
    expect(find.text('学習リマインダー'), findsOneWidget);
    expect(t.takeException(), isNull);
    await tapText(t, 'テスト通知');
    expect(backend.previews, 1);
    expect(store.value.enabled, isFalse);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'UI saves only on button press and refusal has recovery guidance',
    (t) async {
      manager = ReminderManager(store: store, backend: backend);
      await t.pumpWidget(
        MaterialApp(home: ReminderSettingsPage(manager: manager)),
      );
      await t.pumpAndSettle();
      await t.tap(find.byType(Switch));
      await t.pumpAndSettle();
      expect(store.value.enabled, isFalse);
      backend.allowed = false;
      await tapText(t, '設定を保存');
      expect(find.textContaining('通知が許可されていません'), findsOneWidget);
      expect(store.value.enabled, isFalse);
      backend.allowed = true;
      await tapText(t, '設定を保存');
      expect(store.value.enabled, isTrue);
      expect(find.text('毎日 20:00 の通知を保存しました。'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
}
