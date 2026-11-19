import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ReminderSettings {
  const ReminderSettings({
    this.enabled = false,
    this.hour = 20,
    this.minute = 0,
  });
  final bool enabled;
  final int hour, minute;
  String get timeLabel =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  String encode() =>
      jsonEncode({'enabled': enabled, 'hour': hour, 'minute': minute});
  static ReminderSettings decode(String? source) {
    if (source == null) return const ReminderSettings();
    final value = jsonDecode(source) as Map<String, dynamic>;
    final hour = value['hour'], minute = value['minute'];
    if (value['enabled'] is! bool ||
        hour is! int ||
        minute is! int ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      throw const FormatException('Invalid reminder settings');
    }
    return ReminderSettings(
      enabled: value['enabled'] as bool,
      hour: hour,
      minute: minute,
    );
  }
}

abstract class ReminderStore {
  Future<ReminderSettings> load();
  Future<void> save(ReminderSettings settings);
}

class LocalReminderStore implements ReminderStore {
  LocalReminderStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();
  static const key = 'inkuri.reminder.v1';
  final SharedPreferencesAsync _preferences;
  @override
  Future<ReminderSettings> load() async =>
      ReminderSettings.decode(await _preferences.getString(key));
  @override
  Future<void> save(ReminderSettings settings) =>
      _preferences.setString(key, settings.encode());
}

abstract class ReminderBackend {
  bool get supported;
  Future<bool> permission({required bool request});
  Future<void> schedule(ReminderSettings settings);
  Future<void> cancel();
  Future<void> preview();
  Future<void> openSettings();
}

class ReminderPermissionDenied implements Exception {}

/// Serializes startup/foreground reconciliation and explicit user changes.
/// Notification preferences are stored separately from all learning records.
class ReminderManager {
  ReminderManager({required this.store, required this.backend});
  final ReminderStore store;
  final ReminderBackend backend;
  Future<void> _pending = Future.value();
  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _pending.then((_) => action());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<ReminderSettings> load() => store.load();
  Future<void> restore() => _serial(() async {
    if (!backend.supported) return;
    final saved = await store.load();
    if (saved.enabled && await backend.permission(request: false)) {
      await backend.schedule(saved);
    }
  });
  Future<void> save(ReminderSettings next) => _serial(() async {
    // Validate before touching either the OS schedule or stored preferences.
    ReminderSettings.decode(next.encode());
    if (!backend.supported) {
      throw UnsupportedError('Notifications require Android or iOS');
    }
    final previous = await store.load();
    if (next.enabled && !await backend.permission(request: true)) {
      throw ReminderPermissionDenied();
    }
    try {
      if (next.enabled) {
        await backend.schedule(next);
      } else {
        await backend.cancel();
      }
      await store.save(next);
    } catch (_) {
      // Keep the previous preference and restore its schedule on partial failure.
      if (previous.enabled) {
        await backend.schedule(previous);
      } else {
        await backend.cancel();
      }
      rethrow;
    }
  });
  Future<void> preview() => _serial(() async {
    if (!backend.supported) {
      throw UnsupportedError('Notifications require Android or iOS');
    }
    if (!await backend.permission(request: true)) {
      throw ReminderPermissionDenied();
    }
    await backend.preview();
  });
}
