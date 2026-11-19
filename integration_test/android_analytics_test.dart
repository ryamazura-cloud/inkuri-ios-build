import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:phrase_flow/study_analytics.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestPreferences extends Fake implements SharedPreferencesAsync {
  final values = <String, Object>{};

  @override
  Future<String?> getString(String key) async => values[key] as String?;

  @override
  Future<void> setString(String key, String value) async => values[key] = value;

  @override
  Future<void> setBool(String key, bool value) async => values[key] = value;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android: Firebase accepts the three normal-study events', (
    tester,
  ) async {
    await Firebase.initializeApp();
    final analytics = FirebaseAnalytics.instance;
    final recorded = <String>[];
    final tracker = StudyAnalytics(
      preferences: _TestPreferences(),
      setCollectionEnabled: analytics.setAnalyticsCollectionEnabled,
      logEvent: (name, parameters) async {
        await analytics.logEvent(name: name, parameters: parameters);
        recorded.add(name);
      },
    );
    final today = DateTime.now();
    try {
      await analytics.setConsent(
        adStorageConsentGranted: false,
        adUserDataConsentGranted: false,
        adPersonalizationSignalsConsentGranted: false,
      );
      await tracker.changeEnabled(true);
      for (var i = 0; i < 30; i++) {
        await tracker.answered(today);
      }
      await tracker.startedSet(today);
      expect(recorded, [
        'normal_study_day',
        'normal_30_reached',
        'normal_after_30_start',
      ]);
    } finally {
      await tracker.changeEnabled(false);
    }
  });
}
