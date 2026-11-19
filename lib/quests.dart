import 'dart:math' as math;
import 'activity.dart';
import 'domain.dart';
import 'quest_rules.dart';
import 'practice_allowance.dart';

class LearningQuest {
  const LearningQuest(
    this.id,
    this.key,
    this.title,
    this.description,
    this.goal,
    this.value,
    this.claimed, {
    this.weekly = false,
  });
  final String id, key, title, description;
  final int goal, value;
  final bool claimed, weekly;
  int get reward => questRewardXp[id]!;
  bool get awardsTicket => ticketQuestIds.contains(id);
  bool get complete => value >= goal;
  bool get claimable => complete && !claimed;
  bool ticketBalanceFull(LearningData data, {required bool ticketsEnabled}) =>
      ticketsEnabled &&
      awardsTicket &&
      data.allowance.tickets >= PracticeAllowance.ticketLimit;
  double get fraction => math.min(value / goal, 1);
}

DateTime questWeekStart(DateTime now) =>
    DateTime(now.year, now.month, now.day - now.weekday + 1);

Set<String> studiedDays(LearningData data, DateTime now) => data.days.entries
    .where(
      (e) =>
          e.value.questions > 0 && !parseDay(e.key).isAfter(calendarDay(now)),
    )
    .map((e) => e.key)
    .toSet();

List<LearningQuest> learningQuests(
  LearningData data,
  DateTime now, {
  bool ticketsEnabled = false,
}) {
  final today = dayKey(now), week = questWeekStart(now);
  final weekDays = studiedDays(
    data,
    now,
  ).where((key) => !parseDay(key).isBefore(week)).length;
  LearningQuest quest(
    String id,
    String title,
    String description,
    int goal,
    int value, {
    bool weekly = false,
  }) {
    final key = '${weekly ? dayKey(week) : today}|$id';
    return LearningQuest(
      id,
      key,
      title,
      description,
      goal,
      value,
      data.questClaims.contains(key),
      weekly: weekly,
    );
  }

  final daily = [
    quest(
      'first-step',
      'はじめの一歩',
      '今日、1問に取り組もう',
      1,
      data.days[today]?.questions ?? 0,
    ),
    quest(
      'practice-ten',
      'ことばの鍛錬',
      '今日、10問に取り組もう。復習も対象です',
      10,
      data.days[today]?.questions ?? 0,
    ),
    quest(
      'review-one',
      '苦手を味方に',
      '今日、苦手問題を1問復習しよう。「まだ難しい」でも進みます',
      1,
      data.reviewDays[today] ?? 0,
    ),
    quest(
      'practice-thirty',
      'ことばの大特訓',
      '今日、30問に取り組もう。復習も対象です',
      30,
      data.days[today]?.questions ?? 0,
    ),
  ];
  return [
    ...daily,
    if (ticketsEnabled)
      quest(
        'daily-all',
        '今日のクエスト全達成',
        '今日のクエストをすべて達成すると、追加練習チケットを受け取れます',
        daily.length,
        daily.where((q) => q.complete).length,
      ),
    quest(
      'weekly-three',
      '今週の冒険',
      '今週、3日学習しよう。1問でも学べば1日分',
      3,
      weekDays,
      weekly: true,
    ),
    quest(
      'weekly-five',
      '今週の大冒険',
      '今週、5日学習しよう。1問でも学べば1日分',
      5,
      weekDays,
      weekly: true,
    ),
  ];
}

LearningData claimQuestReward(
  LearningData data,
  String key,
  DateTime now, {
  bool ticketsEnabled = false,
}) {
  final matches = learningQuests(
    data,
    now,
    ticketsEnabled: ticketsEnabled,
  ).where((q) => q.key == key);
  if (matches.isEmpty) throw StateError('Quest period changed');
  final quest = matches.single;
  if (quest.claimed) return data;
  if (!quest.complete) throw StateError('Quest is not complete');
  if (!ticketsEnabled || !quest.awardsTicket) return data.withQuestClaim(key);
  if (quest.ticketBalanceFull(data, ticketsEnabled: ticketsEnabled)) {
    throw StateError('Ticket balance is full');
  }
  return data.withQuestClaim(key).withAllowance(data.allowance.grantTickets(1));
}
