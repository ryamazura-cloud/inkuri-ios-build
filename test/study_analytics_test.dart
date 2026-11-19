import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phrase_flow/main.dart';
import 'package:phrase_flow/study_analytics.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'widget_test.dart' show MemoryStore, q, tapText;

class _Preferences extends Fake implements SharedPreferencesAsync {
  final values = <String, Object>{};

  @override
  Future<String?> getString(String key) async => values[key] as String?;

  @override
  Future<void> setString(String key, String value) async => values[key] = value;

  @override
  Future<void> setBool(String key, bool value) async => values[key] = value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final allow in [true, false]) {
    testWidgets('initial analytics choice saves $allow only on confirmation', (
      tester,
    ) async {
      final preferences = _Preferences();
      final changes = <bool>[];
      final analytics = StudyAnalytics(
        preferences: preferences,
        needsSetup: true,
        logEvent: (_, _) async {},
        setCollectionEnabled: (value) async => changes.add(value),
      );
      await tester.pumpWidget(
        PhraseFlowApp(
          store: MemoryStore(),
          loadCatalog: () async => [q],
          analytics: analytics,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue,
      );
      expect(analytics.enabled, isFalse);
      expect(changes, isEmpty);

      await tapText(tester, allow ? '協力して続ける' : '協力しない');
      expect(changes, [allow]);
      expect(analytics.enabled, allow);
      expect(analytics.needsSetup, isFalse);
      expect(preferences.values['inkuri.analytics.enabled.v1'], allow);
    });
  }

  testWidgets('analytics is configured directly from app info', (tester) async {
    final analytics = StudyAnalytics(
      preferences: _Preferences(),
      logEvent: (_, _) async {},
      setCollectionEnabled: (_) async {},
    );
    await tester.pumpWidget(
      PhraseFlowApp(
        store: MemoryStore(),
        loadCatalog: () async => [q],
        analytics: analytics,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SwitchListTile), findsNothing);
    await tester.tap(find.byTooltip('このアプリについて'));
    await tester.pumpAndSettle();
    expect(find.text('詳細'), findsNothing);
    expect(find.textContaining('いつでもオフにできます'), findsOneWidget);
    await tapText(tester, '学習状況の計測に協力する');
    expect(analytics.enabled, isTrue);
    await tapText(tester, '学習状況の計測に協力する');
    expect(analytics.enabled, isFalse);
  });

  test(
    'opt-in, daily thresholds, persistence, and next-set ordering',
    () async {
      final preferences = _Preferences();
      final events = <String>[];
      StudyAnalytics tracker({bool enabled = false}) => StudyAnalytics(
        preferences: preferences,
        enabled: enabled,
        logEvent: (name, parameters) async =>
            events.add('$name ${parameters['study_day']}'),
        setCollectionEnabled: (_) async {},
      );
      final first = tracker();
      final day = DateTime(2026, 11, 4, 23);
      await first.answered(day);
      expect(events, isEmpty);
      await first.changeEnabled(true);
      await Future.wait(List.generate(29, (_) => first.answered(day)));
      await first.startedSet(day);
      expect(events, ['normal_study_day 2026-11-04']);

      final restarted = tracker(enabled: true);
      await restarted.answered(day);
      await restarted.answered(day);
      expect(events.last, 'normal_30_reached 2026-11-04');
      await restarted.startedSet(day);
      await restarted.startedSet(day);
      final tomorrow = DateTime(2026, 11, 5);
      await restarted.startedSet(tomorrow);
      await restarted.answered(tomorrow);
      await restarted.changeEnabled(false);
      await restarted.answered(DateTime(2026, 11, 6));
      expect(events, [
        'normal_study_day 2026-11-04',
        'normal_30_reached 2026-11-04',
        'normal_after_30_start 2026-11-04',
        'normal_study_day 2026-11-05',
      ]);
    },
  );
}
