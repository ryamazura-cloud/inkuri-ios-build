import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:phrase_flow/domain.dart';
import 'package:phrase_flow/growth.dart';
import 'package:phrase_flow/interests.dart';
import 'package:phrase_flow/achievements.dart';
import 'package:phrase_flow/stages.dart';
import 'audio_preservation_helpers.dart';

void main() {
  test('all 1111 previous audio sources retain their text and provenance', () {
    final old =
        (jsonDecode(File('test/fixtures/audio_v0_7_1.json').readAsStringSync())
                as Map)['clips']
            as List;
    final current =
        (jsonDecode(File('assets/audio/manifest.json').readAsStringSync())
                as Map)['clips']
            as List;
    final byText = {for (final clip in current) clip['text']: clip};
    expect(old.length, 1111);
    for (final clip in old) {
      expectCompressedOriginal(byText[clip['text']] as Map?, clip as Map);
    }
  });
  final catalog = Question.decode(
    File('assets/questions.json').readAsStringSync(),
  );
  test('17 categories have 100 to 115 questions with balanced levels', () {
    expect(catalog.length, 1733);
    for (final category in interestCategories) {
      final questions = selectInterestQuestions(catalog, category.id);
      final target = category.id == 'travel' || category.id == 'business'
          ? 115
          : category.id == 'lifestyle'
          ? 103
          : 100;
      expect(questions.length, target, reason: category.label);
      final counts = [
        for (final level in levels)
          questions.where((q) => q.level == level).length,
      ];
      expect(
        counts.reduce((a, b) => a > b ? a : b) -
            counts.reduce((a, b) => a < b ? a : b),
        lessThanOrEqualTo(3),
      );
      for (final level in levels) {
        expect(
          selectInterestQuestions(catalog, category.id, level: level).length,
          greaterThanOrEqualTo(33),
        );
      }
    }
    expect(catalog.map((q) => q.id).toSet().length, 1733);
    expect(catalog.map((q) => q.japanese).toSet().length, 1733);
    expect(
      catalog.expand((q) => q.answers.map((a) => a.text)).toSet().length,
      3467,
    );
  });
  test(
    'all 555 previous records including IDs, answers and notes are untouched',
    () {
      final old =
          (jsonDecode(
                    File(
                      'test/fixtures/catalog_v0_7_1.json',
                    ).readAsStringSync(),
                  )
                  as Map)['questions']
              as List;
      final current =
          (jsonDecode(File('assets/questions.json').readAsStringSync())
                  as Map)['questions']
              as List;
      final byId = {for (final q in current) q['id']: q};
      for (final q in old) {
        expect(byId[q['id']], q);
      }
    },
  );
  test(
    'old data has no interests and optional IDs survive every kind of update',
    () {
      final legacy = LearningData.decode('{"schemaVersion":1,"entries":{}}');
      expect(legacy.interests, isEmpty);
      final data = legacy
          .withInterests(['beauty', 'games'])
          .visit(DateTime(2026, 11, 2))
          .addTime({'2026-11-02': 10000})
          .rate('work-b-004', true, DateTime(2026, 11, 2));
      final restored = LearningData.decode(data.encode());
      expect(restored.interests, ['beauty', 'games']);
      expect(restored.days['2026-11-02']!.milliseconds, 10000);
      expect(restored.entries['work-b-004']!.successes, 1);
    },
  );
  test(
    'changing interests preserves EXP, ratings, badges, time and visits',
    () {
      final old = LearningData()
          .rate('work-b-004', true, DateTime(2026, 11, 2))
          .addTime({'2026-11-02': 5000})
          .withInterests(['beauty']);
      final changed = old.withInterests(['games', 'business']);
      expect(changed.entries, old.entries);
      expect(changed.days, old.days);
      expect(changed.visits, old.visits);
      expect(GrowthProgress(changed).xp, GrowthProgress(old).xp);
      expect(
        achievements(changed).where((b) => b.earned).map((b) => b.id),
        achievements(old).where((b) => b.earned).map((b) => b.id),
      );
      expect(
        interestSkills(catalog, changed)
            .where((s) => s.categoryId == 'business' && s.level == 'stage-1')
            .single
            .cleared,
        1,
      );
    },
  );
  test('tree and question selection contain only selected categories', () {
    final data = LearningData().withInterests(['beauty', 'pets']);
    final skills = interestSkills(catalog, data);
    expect(skills.length, 10);
    expect(skills.map((s) => s.categoryId).toSet(), {'beauty', 'pets'});
    expect(skills.where((s) => s.unlocked).length, 2);
    expect(
      selectInterestQuestions(
        catalog,
        'pets',
        level: '初級',
      ).every((q) => q.category == 'pets' && q.level == '初級'),
      isTrue,
    );
  });
  test(
    'short courses reach challenge at 80 percent without unlocking the next tier',
    () {
      final shortCatalog = Question.decode(
        File('test/fixtures/catalog_v0_7_1.json').readAsStringSync(),
      );
      final questions = selectStageQuestions(shortCatalog, 'beauty', 'stage-1');
      var data = LearningData().withInterests(['beauty']);
      for (var i = 0; i < questions.length; i++) {
        data = data.rate(questions[i].id, true, DateTime(2026, 11, 2));
        final tree = interestSkills(shortCatalog, data);
        expect(tree.first.rank, [1, 2, 3][i]);
        expect(tree[1].unlocked, isFalse);
        expect(tree.first.challengeUnlocked, i >= 2);
      }
      data = data.rate(questions.first.id, false, DateTime(2026, 11, 2));
      expect(interestSkills(shortCatalog, data).first.rank, 3);
    },
  );
  test('invalid, duplicate and non-string interests are rejected', () {
    for (final interests in [
      ['unknown'],
      ['beauty', 'beauty'],
      [12],
      'beauty',
    ]) {
      expect(
        () => LearningData.decode(
          jsonEncode({
            'schemaVersion': 1,
            'entries': {},
            'interests': interests,
          }),
        ),
        throwsFormatException,
      );
    }
  });
  test('question parser rejects unknown category metadata', () {
    final raw =
        jsonDecode(File('assets/questions.json').readAsStringSync())
            as Map<String, dynamic>;
    (raw['questions'] as List).first['category'] = 'not-a-category';
    expect(() => Question.decode(jsonEncode(raw)), throwsFormatException);
  });
}
