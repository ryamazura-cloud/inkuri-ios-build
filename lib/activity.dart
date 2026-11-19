String dayKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

DateTime calendarDay(DateTime date) =>
    DateTime(date.year, date.month, date.day);

DateTime parseDay(String key) {
  final date = DateTime.tryParse(key);
  if (date == null || dayKey(date) != key) {
    throw const FormatException('Invalid activity date');
  }
  return calendarDay(date);
}

class DailyActivity {
  const DailyActivity({this.questions = 0, this.milliseconds = 0});
  final int questions, milliseconds;
  DailyActivity plus({int questions = 0, int milliseconds = 0}) =>
      DailyActivity(
        questions: this.questions + questions,
        milliseconds: this.milliseconds + milliseconds,
      );
  Map<String, int> toJson() => {
    'questions': questions,
    'milliseconds': milliseconds,
  };
  static DailyActivity decode(Map<String, dynamic> raw) {
    final questions = raw['questions'];
    final milliseconds = raw['milliseconds'];
    if (questions is! int ||
        milliseconds is! int ||
        questions < 0 ||
        milliseconds < 0) {
      throw const FormatException('Invalid daily activity');
    }
    return DailyActivity(questions: questions, milliseconds: milliseconds);
  }
}

/// Keeps foreground intervals separate and splits them at local midnight.
/// The caller retains checkpoints until persistence succeeds.
class StudyClock {
  DateTime? _since;
  final Map<String, int> pending = {};
  void resume(DateTime now) => _since ??= now;
  void checkpoint(DateTime now) {
    var cursor = _since;
    if (cursor == null) return;
    while (cursor!.isBefore(now)) {
      final midnight = DateTime(cursor.year, cursor.month, cursor.day + 1);
      final end = now.isBefore(midnight) ? now : midnight;
      final key = dayKey(cursor);
      pending[key] =
          (pending[key] ?? 0) + end.difference(cursor).inMilliseconds;
      cursor = end;
    }
    _since = now;
  }

  void pause(DateTime now) {
    checkpoint(now);
    _since = null;
  }

  Map<String, int> snapshot() => Map.of(pending);
  void acknowledge(Map<String, int> saved) {
    for (final entry in saved.entries) {
      final remaining = (pending[entry.key] ?? 0) - entry.value;
      if (remaining <= 0) {
        pending.remove(entry.key);
      } else {
        pending[entry.key] = remaining;
      }
    }
  }
}

class PeriodTotal {
  const PeriodTotal(
    this.label,
    this.start,
    this.end,
    this.questions,
    this.milliseconds,
  );
  final String label;
  final DateTime start, end; // end is exclusive
  final int questions, milliseconds;
}

PeriodTotal sumPeriod(
  Map<String, DailyActivity> days,
  String label,
  DateTime start,
  DateTime end,
) {
  var questions = 0, milliseconds = 0;
  for (final entry in days.entries) {
    final date = parseDay(entry.key);
    if (!date.isBefore(start) && date.isBefore(end)) {
      questions += entry.value.questions;
      milliseconds += entry.value.milliseconds;
    }
  }
  return PeriodTotal(label, start, end, questions, milliseconds);
}

List<PeriodTotal> recentTotals(Map<String, DailyActivity> days, DateTime now) {
  final today = calendarDay(now);
  final week = DateTime(today.year, today.month, today.day - today.weekday + 1);
  return [
    sumPeriod(
      days,
      '今日',
      today,
      DateTime(today.year, today.month, today.day + 1),
    ),
    sumPeriod(days, '今週', week, DateTime(week.year, week.month, week.day + 7)),
    sumPeriod(
      days,
      '今月',
      DateTime(today.year, today.month),
      DateTime(today.year, today.month + 1),
    ),
  ];
}

List<PeriodTotal> chartPeriods(
  Map<String, DailyActivity> days,
  DateTime anchor, {
  required bool monthly,
}) {
  final count = monthly ? 12 : 14;
  return List.generate(count, (i) {
    final start = monthly
        ? DateTime(anchor.year, anchor.month - count + i + 1)
        : DateTime(anchor.year, anchor.month, anchor.day - count + i + 1);
    final end = monthly
        ? DateTime(start.year, start.month + 1)
        : DateTime(start.year, start.month, start.day + 1);
    return sumPeriod(
      days,
      monthly ? '${start.month}月' : '${start.month}/${start.day}',
      start,
      end,
    );
  });
}

int bestStreak(Set<String> visits) {
  final sorted = visits.map(parseDay).toList()..sort();
  var best = 0, run = 0;
  DateTime? previous;
  for (final date in sorted) {
    run =
        previous != null &&
            date == DateTime(previous.year, previous.month, previous.day + 1)
        ? run + 1
        : 1;
    if (run > best) best = run;
    previous = date;
  }
  return best;
}

int currentStreak(Set<String> visits, DateTime now) {
  var date = calendarDay(now), result = 0;
  if (!visits.contains(dayKey(date))) {
    date = DateTime(date.year, date.month, date.day - 1);
  }
  while (visits.contains(dayKey(date))) {
    result++;
    date = DateTime(date.year, date.month, date.day - 1);
  }
  return result;
}

String studyDuration(int milliseconds) {
  final seconds = milliseconds ~/ 1000;
  final hours = seconds ~/ 3600,
      minutes = seconds % 3600 ~/ 60,
      rest = seconds % 60;
  if (hours > 0) return '$hours時間 $minutes分';
  if (minutes > 0) return '$minutes分 $rest秒';
  return '$rest秒';
}

String shareSummary(List<PeriodTotal> totals) =>
    'インクリで英語をクリエイト！\n\n'
    '${totals.map((total) => '${total.label}（${dayKey(total.start)}〜${dayKey(DateTime(total.end.year, total.end.month, total.end.day - 1))}）\n学習問題数：${total.questions}問\n学習時間：${studyDuration(total.milliseconds)}').join('\n\n')}\n\n'
    '#インクリ #瞬間英作文 #英語学習';
