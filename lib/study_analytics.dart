import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'activity.dart';

class StudyAnalytics {
  StudyAnalytics({
    required this.preferences,
    required this.logEvent,
    required this.setCollectionEnabled,
    this.enabled = false,
    this.needsSetup = false,
  });

  static const _enabledKey = 'inkuri.analytics.enabled.v1';
  static const _dayStateKey = 'inkuri.analytics.day.v1';
  static const threshold = 30;

  final SharedPreferencesAsync preferences;
  final Future<void> Function(String name, Map<String, Object> parameters)
  logEvent;
  final Future<void> Function(bool value) setCollectionEnabled;
  bool enabled;
  bool needsSetup;
  Future<void> _pending = Future.value();

  static Future<StudyAnalytics?> connect() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return null;
    }
    try {
      await Firebase.initializeApp();
      final analytics = FirebaseAnalytics.instance;
      await analytics.setConsent(
        adStorageConsentGranted: false,
        adUserDataConsentGranted: false,
        adPersonalizationSignalsConsentGranted: false,
      );
      final preferences = SharedPreferencesAsync();
      final savedChoice = await preferences.getBool(_enabledKey);
      final enabled = savedChoice ?? false;
      await analytics.setAnalyticsCollectionEnabled(enabled);
      return StudyAnalytics(
        preferences: preferences,
        logEvent: (name, parameters) =>
            analytics.logEvent(name: name, parameters: parameters),
        setCollectionEnabled: analytics.setAnalyticsCollectionEnabled,
        enabled: enabled,
        needsSetup: savedChoice == null,
      );
    } catch (_) {
      // Unconfigured builds can still be used for offline learning.
      return null;
    }
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final next = _pending.then((_) => action());
    _pending = next.catchError((Object _) {});
    return next;
  }

  Future<void> changeEnabled(bool value) => _enqueue(() async {
    await setCollectionEnabled(value);
    enabled = value;
    try {
      await preferences.setBool(_enabledKey, value);
      needsSetup = false;
    } catch (_) {
      await setCollectionEnabled(false);
      enabled = false;
      rethrow;
    }
  });

  Future<void> answered(DateTime now) => _record(now, answering: true);

  Future<void> startedSet(DateTime now) => _record(now, answering: false);

  Future<void> _record(DateTime now, {required bool answering}) =>
      _enqueue(() async {
        if (!enabled) return;
        final date = dayKey(now);
        final stored = (await preferences.getString(_dayStateKey))?.split('|');
        final count = stored?.length == 2 && stored!.first == date
            ? int.tryParse(stored.last) ?? 0
            : 0;
        final String event;
        final int nextCount;
        if (answering && count < threshold) {
          nextCount = count + 1;
          event = switch (nextCount) {
            1 => 'normal_study_day',
            threshold => 'normal_30_reached',
            _ => '',
          };
        } else if (!answering && count == threshold) {
          nextCount = threshold + 1;
          event = 'normal_after_30_start';
        } else {
          return;
        }
        await preferences.setString(_dayStateKey, '$date|$nextCount');
        if (event.isNotEmpty) {
          await logEvent(event, {'study_day': date});
        }
      }).catchError((Object _) {
        // A telemetry failure must never interrupt a training session.
      });
}
