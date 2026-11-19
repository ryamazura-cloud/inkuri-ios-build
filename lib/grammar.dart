import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'domain.dart';

class GrammarUnit {
  const GrammarUnit({
    required this.id,
    required this.title,
    required this.group,
    required this.pattern,
    required this.hint,
    required this.questions,
  });
  final String id, title, group, pattern, hint;
  final List<Question> questions;
}

class GrammarCatalog {
  const GrammarCatalog.empty() : units = const [], questions = const [];
  const GrammarCatalog._(this.units, this.questions);
  final List<GrammarUnit> units;
  final List<Question> questions;
  static GrammarCatalog decode(String source) {
    final root = jsonDecode(source) as Map<String, dynamic>;
    final questions = Question.decode(source);
    final byId = {for (final q in questions) q.id: q};
    final units = <GrammarUnit>[];
    final usedQuestions = <String>{}, usedUnits = <String>{};
    for (final raw in root['units'] as List) {
      final u = raw as Map<String, dynamic>;
      for (final key in ['id', 'title', 'group', 'pattern', 'hint']) {
        if (u[key] is! String || (u[key] as String).trim().isEmpty) {
          throw const FormatException('Invalid grammar description');
        }
      }
      if (!usedUnits.add(u['id'] as String)) {
        throw const FormatException('Repeated grammar unit');
      }
      final ids = List<String>.from(u['questionIds'] as List);
      if (ids.length != 10) {
        throw const FormatException('Each grammar unit requires ten questions');
      }
      final selected = <Question>[];
      for (final id in ids) {
        final q = byId[id];
        if (q == null ||
            !usedQuestions.add(id) ||
            q.grammarUnit != u['id'] ||
            q.topic != u['title'] ||
            !q.id.startsWith('grammar-') ||
            q.note.trim().isEmpty) {
          throw const FormatException('Invalid grammar question reference');
        }
        selected.add(q);
      }
      units.add(
        GrammarUnit(
          id: u['id'] as String,
          title: u['title'] as String,
          group: u['group'] as String,
          pattern: u['pattern'] as String,
          hint: u['hint'] as String,
          questions: List.unmodifiable(selected),
        ),
      );
    }
    if (units.isEmpty || usedQuestions.length != questions.length) {
      throw const FormatException('Incomplete grammar catalog');
    }
    return GrammarCatalog._(List.unmodifiable(units), questions);
  }
}

enum TrainingMode { adventure, grammar }

abstract class TrainingModeStore {
  Future<TrainingMode> load();
  Future<void> save(TrainingMode mode);
}

class LocalTrainingModeStore implements TrainingModeStore {
  LocalTrainingModeStore({
    SharedPreferencesAsync? preferences,
    this.storageKey = key,
  }) : _preferences = preferences ?? SharedPreferencesAsync();
  static const key = 'inkuri.training_mode.v1';
  final String storageKey;
  final SharedPreferencesAsync _preferences;
  @override
  Future<TrainingMode> load() async =>
      await _preferences.getString(storageKey) == 'grammar'
      ? TrainingMode.grammar
      : TrainingMode.adventure;
  @override
  Future<void> save(TrainingMode mode) =>
      _preferences.setString(storageKey, mode.name);
}
