import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:phrase_flow/domain.dart';
import 'package:phrase_flow/growth.dart';
import 'package:phrase_flow/stages.dart';

void main() {
  final catalog = Question.decode(
    File('assets/questions.json').readAsStringSync(),
  );
  final now = DateTime(2026, 11, 3);
  test(
    'unearned titles remain hidden even for previously studied upper questions',
    () {
      final advanced = selectStageQuestions(catalog, 'beauty', 'stage-5').first;
      final data = LearningData()
          .withInterests(['beauty'])
          .rate(advanced.id, true, now);
      expect(interestSkills(catalog, data).last.displayLabel, 'レベル5 ？？？');
      expect(stageLabels(catalog, progress: data)[advanced.id], 'レベル5 ？？？');
      expect(GrowthProgress(data).xp, 10);
      expect(interestSkills(catalog, data).first.displayLabel, 'レベル1 美容初心者');
    },
  );
  test('challenge pass reveals only the next title and survives reload', () {
    var data = LearningData().withInterests(['beauty']);
    expect(interestSkills(catalog, data)[1].displayLabel, 'レベル2 ？？？');
    data = LearningData.decode(
      data.finishChallenge('beauty', 'stage-1', 4, 5, now).encode(),
    );
    expect(interestSkills(catalog, data)[1].displayLabel, 'レベル2 彩りの使い手');
    expect(interestSkills(catalog, data)[2].displayLabel, 'レベル3 ？？？');
    final question = selectStageQuestions(catalog, 'beauty', 'stage-2').first;
    expect(stageLabels(catalog, progress: data)[question.id], 'レベル2 彩りの使い手');
  });
}
