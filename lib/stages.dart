import 'domain.dart';
import 'course_levels.dart';

/// Keep question IDs and audio intact; order by original difficulty, then ID.
/// Sorting by ID makes stage assignment independent of JSON input order.
Map<String, List<Question>> categoryStages(
  List<Question> catalog,
  String category,
) {
  final ordered = selectInterestQuestions(catalog, category).toList()
    ..sort((a, b) {
      final difficulty = levels
          .indexOf(a.level)
          .compareTo(levels.indexOf(b.level));
      return difficulty == 0 ? a.id.compareTo(b.id) : difficulty;
    });
  final base = ordered.length ~/ 5, remainder = ordered.length % 5;
  return {
    for (var i = 0; i < 5; i++)
      courseLevels[i].key: List.unmodifiable(
        ordered.sublist(
          i * base + (i < remainder ? i : remainder),
          i * base +
              (i < remainder ? i : remainder) +
              base +
              (i < remainder ? 1 : 0),
        ),
      ),
  };
}

List<Question> selectStageQuestions(
  List<Question> catalog,
  String category,
  String stage,
) => categoryStages(catalog, category)[stage] ?? const [];
Map<String, String> stageLabels(
  List<Question> catalog, {
  LearningData? progress,
}) {
  final categories = catalog.map(categoryForQuestion).toSet();
  return {
    for (final category in categories)
      for (final entry in categoryStages(catalog, category).entries)
        for (final q in entry.value)
          q.id:
              progress == null ||
                  courseLevels
                      .take(courseLevel(entry.key).number - 1)
                      .every(
                        (previous) => progress.challengePasses.containsKey(
                          '$category|${previous.key}',
                        ),
                      )
              ? courseLevel(entry.key, category: category).label
              : 'レベル${courseLevel(entry.key).number} $hiddenTitle',
  };
}
