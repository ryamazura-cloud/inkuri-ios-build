import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:phrase_flow/activity.dart';
import 'package:phrase_flow/achievements.dart';
import 'package:phrase_flow/domain.dart';

void main() {
  test(
    'old progress keeps counters without inventing dated history or time',
    () {
      final old = jsonEncode({
        'schemaVersion': 1,
        'entries': {
          'old': {
            'attempts': 10,
            'successes': 3,
            'needsReview': true,
            'lastStudied': '2026-10-31T12:00:00',
          },
        },
      });
      final data = LearningData.decode(old);
      expect(data.entries['old']!.attempts, 10);
      expect(data.days, isEmpty);
      expect(data.visits, isEmpty);
      expect(
        achievements(data).singleWhere((a) => a.id == 'clear-1').earned,
        isTrue,
      );
      expect(LearningData.decode(data.encode()).entries['old']!.successes, 3);
    },
  );
  test(
    'ratings count retries, clear badges count distinct successful questions',
    () {
      var data = LearningData().rate('a', true, DateTime(2026, 11, 2));
      for (var i = 0; i < 9; i++) {
        data = data.rate('a', false, DateTime(2026, 11, 2));
      }
      expect(data.days['2026-11-02']!.questions, 10);
      expect(data.entries['a']!.needsReview, isTrue);
      expect(
        achievements(data).singleWhere((a) => a.id == 'clear-1').earned,
        isTrue,
      );
      expect(
        achievements(data).singleWhere((a) => a.id == 'clear-10').earned,
        isFalse,
      );
    },
  );
  test(
    'local midnight splits active time, pauses and clock reversal add no time',
    () {
      final clock = StudyClock();
      clock.resume(DateTime(2026, 12, 31, 23, 59, 58));
      clock.pause(DateTime(2027, 1, 1, 0, 0, 3));
      expect(clock.pending, {'2026-12-31': 2000, '2027-01-01': 3000});
      clock.checkpoint(DateTime(2027, 1, 1, 2));
      expect(clock.pending.values.reduce((a, b) => a + b), 5000);
      clock.resume(DateTime(2027, 1, 1, 2));
      clock.pause(DateTime(2027, 1, 1, 1));
      expect(clock.pending.values.reduce((a, b) => a + b), 5000);
    },
  );
  test(
    'acknowledging an in-flight checkpoint preserves newer time and retries',
    () {
      final clock = StudyClock()..resume(DateTime(2026, 11, 2, 12));
      clock.checkpoint(DateTime(2026, 11, 2, 12, 0, 15));
      final saved = clock.snapshot();
      clock.checkpoint(DateTime(2026, 11, 2, 12, 0, 20));
      expect(clock.pending.values.single, 20000);
      clock.acknowledge(saved);
      expect(clock.pending.values.single, 5000);
      clock.acknowledge(clock.snapshot());
      expect(clock.pending, isEmpty);
    },
  );
  test(
    'Monday week boundaries and month boundaries exclude future records',
    () {
      final days = {
        '2026-11-01': const DailyActivity(questions: 4, milliseconds: 1000),
        '2026-11-02': const DailyActivity(questions: 2, milliseconds: 60000),
        '2026-11-08': const DailyActivity(questions: 3, milliseconds: 90000),
        '2026-11-09': const DailyActivity(questions: 8, milliseconds: 1000),
        '2026-12-01': const DailyActivity(questions: 10),
      };
      final totals = recentTotals(days, DateTime(2026, 11, 8, 12));
      expect(totals[0].questions, 3);
      expect(totals[1].questions, 5);
      expect(totals[1].milliseconds, 150000);
      expect(totals[2].questions, 17);
    },
  );
  test(
    'calendar charts include leap day, zero days, year transitions and prior pages',
    () {
      final days = {
        '2024-02-29': const DailyActivity(questions: 3),
        '2025-01-01': const DailyActivity(questions: 2),
      };
      final daily = chartPeriods(days, DateTime(2024, 3, 1), monthly: false);
      expect(daily.length, 14);
      expect(daily[daily.length - 2].questions, 3);
      expect(daily.last.questions, 0);
      final monthly = chartPeriods(days, DateTime(2025, 1), monthly: true);
      expect(monthly.length, 12);
      expect(monthly.first.start, DateTime(2024, 2));
      expect(monthly.first.questions, 3);
      expect(monthly.last.questions, 2);
    },
  );
  test(
    '50 badges retain stable milestone dates across retries and reloads',
    () {
      final first = DateTime(2026, 11, 1);
      final second = DateTime(2026, 11, 2);
      final third = DateTime(2026, 11, 3);
      final data = LearningData()
          .rate('q', true, first)
          .rate('q', false, second)
          .visit(third)
          .finishChallenge('travel', 'stage-1', 4, 5, third);
      final badges = achievements(LearningData.decode(data.encode()));
      expect(badges.length, 50);
      expect(badges.map((badge) => badge.id).toSet().length, 50);
      String? earnedDay(String id) =>
          badges.singleWhere((badge) => badge.id == id).earnedDay;
      expect(earnedDay('clear-1'), '2026-11-01');
      expect(earnedDay('visit-3'), '2026-11-03');
      expect(earnedDay('challenge-1'), '2026-11-03');
      final raw = jsonDecode(data.encode()) as Map<String, dynamic>;
      (raw['entries']['q'] as Map<String, dynamic>).remove('firstClearDay');
      final legacy = achievements(
        LearningData.decode(jsonEncode(raw)),
      ).singleWhere((badge) => badge.id == 'clear-1');
      expect(legacy.earned, isTrue);
      expect(legacy.earnedDay, isNull);
    },
  );

  test('same-day visits are unique; earned streak persists after a gap', () {
    var data = LearningData();
    for (final day in [28, 29, 30]) {
      data = data.visit(DateTime(2026, 10, day));
    }
    data = data.visit(DateTime(2026, 10, 30, 23));
    expect(data.visits.length, 3);
    expect(currentStreak(data.visits, DateTime(2026, 10, 31)), 3);
    expect(currentStreak(data.visits, DateTime(2026, 11, 2)), 0);
    final restored = LearningData.decode(
      data.encode(),
    ).visit(DateTime(2026, 11, 2));
    expect(currentStreak(restored.visits, DateTime(2026, 11, 2)), 1);
    expect(
      achievements(restored).singleWhere((a) => a.id == 'visit-3').earned,
      isTrue,
    );
  });
  test('dated counts and time survive encoding and reset clears badges', () {
    final data = LearningData().rate('a', true, DateTime(2026, 11, 2)).addTime({
      '2026-11-02': 62000,
    });
    final restored = LearningData.decode(data.encode());
    expect(restored.days['2026-11-02']!.milliseconds, 62000);
    expect(
      recentTotals(restored.days, DateTime(2026, 11, 2)).first.questions,
      1,
    );
    expect(achievements(LearningData()).where((a) => a.earned), isEmpty);
  });
  test(
    'invalid days and negative activity are rejected without losing data',
    () {
      for (final day in ['2026-02-30', '2026-2-2', 'garbage']) {
        expect(
          () => LearningData.decode(
            jsonEncode({
              'schemaVersion': 1,
              'entries': {},
              'days': {
                day: {'questions': 0, 'milliseconds': 0},
              },
            }),
          ),
          throwsFormatException,
        );
      }
      expect(
        () => DailyActivity.decode({'questions': -1, 'milliseconds': 0}),
        throwsFormatException,
      );
      expect(
        () => DailyActivity.decode({'questions': 0, 'milliseconds': 1.5}),
        throwsFormatException,
      );
    },
  );
  test(
    'share text includes today, week and month metrics with their dates',
    () {
      final total = PeriodTotal(
        '今日',
        DateTime(2026, 11, 2),
        DateTime(2026, 11, 3),
        12,
        125000,
      );
      final text = shareSummary([
        total,
        PeriodTotal(
          '今週',
          DateTime(2026, 10, 27),
          DateTime(2026, 11, 3),
          35,
          600000,
        ),
        PeriodTotal(
          '今月',
          DateTime(2026, 11, 1),
          DateTime(2026, 12, 1),
          99,
          3600000,
        ),
      ]);
      expect(text, contains('今日（2026-11-02〜2026-11-02）'));
      expect(text, contains('今週（2026-10-27〜2026-11-02）'));
      expect(text, contains('今月（2026-11-01〜2026-11-30）'));
      expect(text, contains('35問'));
      expect(text, contains('99問'));
      expect(text, contains('10分 0秒'));
      expect(text, contains('1時間 0分'));
      expect(text, contains('12問'));
      expect(text, contains('2分 5秒'));
      expect(text, contains('#インクリ'));
      expect(text, contains('2026-11-02〜2026-11-02'));
      expect(studyDuration(3660000), '1時間 1分');
    },
  );
}
