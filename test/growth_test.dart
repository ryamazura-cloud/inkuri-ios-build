import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:phrase_flow/domain.dart';
import 'package:phrase_flow/growth.dart';

void main() {
  LearningData xpData(int successes, int retries) {
    var data = LearningData();
    for (var i = 0; i < successes; i++) {
      data = data.rate('same', true, DateTime(2026, 11, 2));
    }
    for (var i = 0; i < retries; i++) {
      data = data.rate('same', false, DateTime(2026, 11, 2));
    }
    return data;
  }

  final catalog = Question.decode(
    File('test/fixtures/catalog_v0_6_1.json').readAsStringSync(),
  );
  LearningData clear(
    List<Question> questions,
    int count, [
    LearningData? start,
  ]) {
    var data = start ?? LearningData();
    for (final q in questions.take(count)) {
      data = data.rate(q.id, true, DateTime(2026, 11, 2));
    }
    return data;
  }

  test('legacy attempts derive EXP and persistence needs no new schema', () {
    final data = LearningData.decode(
      '{"schemaVersion":1,"entries":{"old":{"attempts":8,"successes":3,"needsReview":true,"lastStudied":"2026-11-01T12:00:00"}}}',
    );
    expect(GrowthProgress(data).xp, 55);
    expect(GrowthProgress(data).level, 2);
    expect(GrowthProgress(LearningData.decode(data.encode())).xp, 55);
  });
  test('success gives 10, retry gives 5, time and visits give no EXP', () {
    final data = xpData(
      2,
      3,
    ).visit(DateTime(2026, 11, 3)).addTime({'2026-11-03': 3600000});
    expect(GrowthProgress(data).xp, 35);
    expect(
      GrowthProgress(data.rate('same', false, DateTime(2026, 11, 3))).xp,
      40,
    );
    expect(GrowthProgress(LearningData()).xp, 0);
    expect(GrowthProgress(LearningData()).level, 1);
  });
  test('level boundaries and high-level thresholds stay exact', () {
    for (final level in [1, 2, 3, 10, 40, 99, 1000]) {
      final threshold = GrowthProgress.threshold(level);
      for (final delta in [0, 5]) {
        final data = LearningData({
          'q': ProgressEntry(
            attempts: (threshold + delta) ~/ 5,
            successes: 0,
            needsReview: true,
            lastStudied: DateTime(2026, 11, 2),
          ),
        });
        expect(GrowthProgress(data).level, level);
        expect(GrowthProgress(data).current, delta);
        expect(GrowthProgress(data).remaining, greaterThan(0));
      }
      if (level > 1) {
        final before = LearningData({
          'q': ProgressEntry(
            attempts: (threshold - 5) ~/ 5,
            successes: 0,
            needsReview: true,
            lastStudied: DateTime(2026, 11, 2),
          ),
        });
        expect(GrowthProgress(before).level, level - 1);
      }
    }
    expect(GrowthProgress.threshold(2), 150);
    expect(GrowthProgress.threshold(3), 340);
    expect(GrowthProgress.threshold(4), 570);
    expect(GrowthProgress.threshold(5), 840);
    expect(GrowthProgress(xpData(5, 0)).level, 1);
    expect(GrowthProgress(xpData(15, 0)).level, 2);
    expect(GrowthProgress(xpData(37, 1)).level, 3);
    expect(() => GrowthProgress.threshold(0), throwsArgumentError);
  });
  test(
    'new curve recalculates old levels without mutating earned progress',
    () {
      final data = xpData(35, 0).withQuestClaim('2026-11-02|first-step');
      final before = data.encode();
      final restored = LearningData.decode(before);
      final growth = GrowthProgress(restored);
      expect(growth.xp, 360);
      expect(growth.level, 3);
      expect(growth.title, 'ことばの旅人');
      expect(growth.remaining, 210);
      expect(restored.encode(), before);
    },
  );
  test(
    'new learner sees three initial branches and later nodes are locked',
    () {
      final skills = learningSkills(catalog, LearningData());
      expect(skills.length, 9);
      expect(skills.where((s) => s.unlocked).length, 3);
      expect(
        skills.where((s) => s.unlocked).every((s) => s.level == '初級'),
        isTrue,
      );
      expect(skills.every((s) => s.rank == 0), isTrue);
    },
  );
  test('unique clears unlock next tier; repeats and retries do not', () {
    final initial = catalog
        .where((q) => q.scene == '日常' && q.level == '初級')
        .toList();
    var data = clear(initial, 4);
    for (var i = 0; i < 10; i++) {
      data = data.rate(initial.first.id, true, DateTime(2026, 11, 2));
    }
    data = data.rate(initial[4].id, false, DateTime(2026, 11, 2));
    expect(
      learningSkills(
        catalog,
        data,
      ).singleWhere((s) => s.scene == '日常' && s.level == '中級').unlocked,
      isFalse,
    );
    data = data.rate(initial[4].id, true, DateTime(2026, 11, 2));
    final skills = learningSkills(catalog, data);
    expect(
      skills.singleWhere((s) => s.scene == '日常' && s.level == '初級').cleared,
      5,
    );
    expect(
      skills.singleWhere((s) => s.scene == '日常' && s.level == '中級').unlocked,
      isTrue,
    );
    expect(
      skills.singleWhere((s) => s.scene == '旅行' && s.level == '中級').unlocked,
      isFalse,
    );
  });
  test('ranks follow 5, 15, all questions and never revoke after a retry', () {
    final questions = catalog
        .where((q) => q.scene == '旅行' && q.level == '初級')
        .toList();
    for (final entry in {4: 0, 5: 1, 14: 1, 15: 2, 34: 3}.entries) {
      var data = clear(questions, entry.key);
      if (entry.key > 0) {
        data = data.rate(questions.first.id, false, DateTime(2026, 11, 2));
      }
      final skill = learningSkills(
        catalog,
        data,
      ).singleWhere((s) => s.scene == '旅行' && s.level == '初級');
      expect(skill.rank, entry.value);
      expect(skill.cleared, entry.key);
    }
  });
  test(
    'previously cleared advanced skills remain accessible without lower-tier clears',
    () {
      final question = catalog.firstWhere(
        (q) => q.scene == '仕事' && q.level == '上級',
      );
      final data = LearningData().rate(
        question.id,
        true,
        DateTime(2026, 11, 2),
      );
      final skill = learningSkills(
        catalog,
        data,
      ).singleWhere((s) => s.scene == '仕事' && s.level == '上級');
      expect(skill.unlocked, isTrue);
      expect(skill.cleared, 1);
    },
  );
  test(
    'small and empty catalogs have attainable goals without phantom skills',
    () {
      final q = catalog.first;
      final skills = learningSkills([
        q,
      ], LearningData().rate(q.id, true, DateTime(2026, 11, 2)));
      expect(
        skills
            .singleWhere((s) => s.scene == q.scene && s.level == q.level)
            .rank,
        3,
      );
      expect(
        skills
            .where((s) => s.total == 0)
            .every((s) => !s.unlocked && s.rank == 0),
        isTrue,
      );
      expect(
        learningSkills(catalog, LearningData()).every((s) => s.rank == 0),
        isTrue,
      );
    },
  );
}
