import 'activity.dart';
import 'domain.dart';

class Achievement {
  const Achievement(
    this.id,
    this.title,
    this.description,
    this.goal,
    this.value, {
    required this.isVisit,
    this.earnedDay,
  });
  final String id, title, description;
  final int goal, value;
  final bool isVisit;
  final String? earnedDay;
  bool get earned => value >= goal;
}

List<Achievement> achievements(LearningData data) {
  final visits = data.visits.toList()..sort();
  final streakDays = <String>[];
  var run = 0;
  DateTime? previous;
  for (final key in visits) {
    final date = parseDay(key);
    run =
        previous != null &&
            date == DateTime(previous.year, previous.month, previous.day + 1)
        ? run + 1
        : 1;
    if (run > streakDays.length) streakDays.add(key);
    previous = date;
  }
  final clears = data.entries.values
      .where((entry) => entry.successes > 0)
      .toList();
  final clearDays =
      clears.map((e) => e.firstClearDay).whereType<String>().toList()..sort();
  final undatedClears = clears.length - clearDays.length;
  final studyDays =
      data.days.entries.where((e) => e.value.questions > 0).toList()
        ..sort((a, b) => a.key.compareTo(b.key));
  final attempts = studyDays.fold(0, (sum, e) => sum + e.value.questions);
  final challengeDays =
      data.challengePasses.values.map((pass) => dayKey(pass.passedAt)).toList()
        ..sort();
  String? nthDay(List<String> days, int goal) =>
      goal > 0 && goal <= days.length ? days[goal - 1] : null;
  String? attemptDay(int goal) {
    var total = 0;
    for (final day in studyDays) {
      total += day.value.questions;
      if (total >= goal) return day.key;
    }
    return null;
  }

  final activeDays = studyDays.map((entry) => entry.key).toList();
  return [
    for (final goal in [1, 3, 7, 14, 21, 30, 45, 60, 90, 100, 180, 365])
      Achievement(
        'visit-$goal',
        '$goal日継続',
        '$goal日連続でアプリを開く',
        goal,
        streakDays.length,
        isVisit: true,
        earnedDay: nthDay(streakDays, goal),
      ),
    for (final goal in [
      1,
      10,
      25,
      50,
      100,
      200,
      300,
      500,
      750,
      1000,
      1500,
      2000,
    ])
      Achievement(
        'clear-$goal',
        '$goal問クリア',
        '異なる$goal問を一度以上「できた」にする',
        goal,
        clears.length,
        isVisit: false,
        earnedDay: nthDay(clearDays, goal - undatedClears),
      ),
    for (final goal in [10, 30, 100, 250, 500, 1000, 2000, 5000, 10000, 20000])
      Achievement(
        'attempt-$goal',
        '累計$goal問に挑戦',
        '自己評価まで累計$goal問取り組む',
        goal,
        attempts,
        isVisit: false,
        earnedDay: attemptDay(goal),
      ),
    for (final goal in [3, 7, 14, 30, 60, 100, 180, 365])
      Achievement(
        'study-day-$goal',
        '$goal日学習',
        '1問以上学習した日を累計$goal日にする',
        goal,
        activeDays.length,
        isVisit: false,
        earnedDay: nthDay(activeDays, goal),
      ),
    for (final goal in [1, 3, 5, 10, 20, 30, 50, 85])
      Achievement(
        'challenge-$goal',
        '挑戦$goal回合格',
        '異なる挑戦に$goal回合格する',
        goal,
        challengeDays.length,
        isVisit: false,
        earnedDay: nthDay(challengeDays, goal),
      ),
  ];
}
