import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:phrase_flow/challenge.dart';
import 'package:phrase_flow/domain.dart';
import 'package:phrase_flow/growth.dart';
import 'package:phrase_flow/stages.dart';
import 'package:phrase_flow/course_levels.dart';

void main() {
  final now = DateTime(2026, 11, 3);
  final catalog = Question.decode(
    File('assets/questions.json').readAsStringSync(),
  );
  final basic = selectStageQuestions(catalog, 'beauty', 'stage-1');
  LearningData cleared(int count) {
    var data = LearningData().withInterests(['beauty']);
    for (final q in basic.take(count)) {
      data = data.rate(q.id, true, now);
    }
    return data;
  }

  test('80 percent always rounds up and zero courses never enable exams', () {
    expect([1, 5, 33, 34, 36, 38, 39].map(eightyPercent), [
      1,
      4,
      27,
      28,
      29,
      31,
      32,
    ]);
    expect(
      interestSkills(
        [],
        LearningData().withInterests(['beauty']),
      ).every((s) => !s.unlocked && !s.challengeUnlocked),
      isTrue,
    );
  });
  test(
    '15 of 20 cannot enter challenge; 16 can but intermediate still locked',
    () {
      final before = interestSkills(catalog, cleared(15));
      expect(before.first.challengeUnlocked, isFalse);
      var data = cleared(16);
      for (var i = 0; i < 20; i++) {
        data = data.rate(basic.first.id, true, now);
      }
      final after = interestSkills(catalog, data);
      expect(after.first.cleared, 16);
      expect(after.first.challengeUnlocked, isTrue);
      expect(after[1].unlocked, isFalse);
    },
  );
  test('failures from separate attempts do not combine into a pass', () {
    var data = cleared(16).finishChallenge('beauty', 'stage-1', 3, 5, now);
    data = data.finishChallenge('beauty', 'stage-1', 3, 5, now);
    expect(data.challengePasses, isEmpty);
    expect(interestSkills(catalog, data)[1].unlocked, isFalse);
    data = data.finishChallenge('beauty', 'stage-1', 4, 5, now);
    final tree = interestSkills(catalog, data);
    expect(tree.first.challengePassed, isTrue);
    expect(tree[1].unlocked, isTrue);
    expect(tree[2].unlocked, isFalse);
  });
  test(
    'full sequential progression ends with advanced challenge completion',
    () {
      var data = cleared(16);
      for (final stage in courseLevels) {
        final level = stage.key;
        final qs = selectStageQuestions(catalog, 'beauty', level);
        for (final q in qs.take(eightyPercent(qs.length))) {
          data = data.rate(q.id, true, now);
        }
        expect(
          interestSkills(
            catalog,
            data,
          ).singleWhere((s) => s.level == level).challengeUnlocked,
          isTrue,
        );
        data = data.finishChallenge('beauty', level, 4, 5, now);
      }
      expect(
        interestSkills(
          catalog,
          data,
        ).every((s) => s.unlocked && s.challengePassed),
        isTrue,
      );
    },
  );
  test('legacy upper-tier ratings survive but do not bypass the new gates', () {
    final q = selectStageQuestions(catalog, 'beauty', 'stage-5').first;
    final data = LearningData().withInterests(['beauty']).rate(q.id, true, now);
    final skill = interestSkills(catalog, data).last;
    expect(skill.cleared, 1);
    expect(skill.unlocked, isFalse);
    expect(GrowthProgress(data).xp, 10);
  });
  test('passes survive every mutation, reload, and failed retake', () {
    var data = cleared(16).finishChallenge('beauty', 'stage-1', 4, 5, now);
    final pass = data.challengePasses['beauty|stage-1'];
    data = data
        .rate(basic.first.id, false, now)
        .addTime({'2026-11-03': 5000})
        .visit(now)
        .withInterests(['beauty', 'games']);
    data = LearningData.decode(
      data.encode(),
    ).finishChallenge('beauty', 'stage-1', 0, 5, now);
    expect(data.challengePasses['beauty|stage-1']!.toJson(), pass!.toJson());
    expect(interestSkills(catalog, data).first.challengePassed, isTrue);
  });
  test(
    'old storage migrates without passes; invalid course/score rejects load',
    () {
      expect(
        LearningData.decode('{"schemaVersion":1,"entries":{}}').challengePasses,
        isEmpty,
      );
      final good = cleared(16).finishChallenge('beauty', 'stage-1', 4, 5, now);
      for (final key in ['missing|初級', 'beauty|超級', 'beauty|初級|extra']) {
        final raw = jsonDecode(good.encode()) as Map<String, dynamic>;
        raw['challengePasses'] = {
          key: {'score': 4, 'total': 5, 'passedAt': now.toIso8601String()},
        };
        expect(
          () => LearningData.decode(jsonEncode(raw)),
          throwsFormatException,
        );
      }
      for (final score in [-1, 3, 6]) {
        final raw = jsonDecode(good.encode()) as Map<String, dynamic>;
        raw['challengePasses']['beauty|stage-1']['score'] = score;
        expect(
          () => LearningData.decode(jsonEncode(raw)),
          throwsFormatException,
        );
      }
    },
  );
}
