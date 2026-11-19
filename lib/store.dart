import 'package:shared_preferences/shared_preferences.dart';
import 'domain.dart';

abstract class ProgressStore {
  Future<LearningData> load();
  Future<void> save(LearningData data);
}

class LocalProgressStore implements ProgressStore {
  LocalProgressStore({
    SharedPreferencesAsync? preferences,
    this.storageKey = key,
  }) : _preferences = preferences ?? SharedPreferencesAsync();
  static const key = 'phrase_flow.progress.v1';
  static const _firstRunKey = 'inkuri.first_run_started.v1';
  static const _storeReviewKey = 'inkuri.store_review_requested.v1';
  final String storageKey;
  final SharedPreferencesAsync _preferences;

  Future<bool> claimFirstRun() async {
    if (await _preferences.getBool(_firstRunKey) == true ||
        await _preferences.getString(storageKey) != null) {
      return false;
    }
    await _preferences.setBool(_firstRunKey, true);
    return true;
  }

  Future<bool> claimStoreReview() async {
    if (await _preferences.getBool(_storeReviewKey) == true) return false;
    await _preferences.setBool(_storeReviewKey, true);
    return true;
  }

  @override
  Future<LearningData> load() async {
    final source = await _preferences.getString(storageKey);
    return source == null ? LearningData() : LearningData.decode(source);
  }

  @override
  Future<void> save(LearningData data) =>
      _preferences.setString(storageKey, data.encode());
}
