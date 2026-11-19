import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:phrase_flow/domain.dart';
import 'audio_preservation_helpers.dart';

Map<String, dynamic> read(String filename) =>
    jsonDecode(File(filename).readAsStringSync()) as Map<String, dynamic>;

void main() {
  test('all original 36 question records are unchanged', () {
    final old = read('test/fixtures/catalog_v0_2_0.json')['questions'] as List;
    final current = read('assets/questions.json')['questions'] as List;
    final byId = {for (final q in current) q['id']: q};
    expect(old.length, 36);
    for (final question in old) {
      expect(byId[question['id']], question);
    }
  });
  test('60 new daily questions cover three topics and three levels', () {
    final oldIds =
        (read('test/fixtures/catalog_v0_2_0.json')['questions'] as List)
            .map((q) => q['id'])
            .toSet();
    final questions = Question.decode(
      File('assets/questions.json').readAsStringSync(),
    );
    final previousIds =
        (read('test/fixtures/catalog_v0_3_0.json')['questions'] as List)
            .map((q) => q['id'])
            .toSet();
    final added = questions
        .where((q) => !oldIds.contains(q.id) && previousIds.contains(q.id))
        .toList();
    expect(added.length, 60);
    expect(added.every((q) => q.scene == '日常'), isTrue);
    for (final level in levels) {
      expect(added.where((q) => q.level == level).length, 20);
    }
    for (final topic in ['買い物', '家族・家事', '友人・予定']) {
      expect(added.where((q) => q.topic == topic).length, 20);
    }
    expect(questions.map((q) => q.japanese).toSet().length, questions.length);
    expect(
      questions.expand((q) => q.answers.map((a) => a.text)).toSet().length,
      3467,
    );
    expect(questions.singleWhere((q) => q.id == 'daily-b-001').topic, isEmpty);
  });
  test(
    'real catalog upgrade retains old ratings and leaves added IDs unstudied',
    () {
      final questions = Question.decode(
        File('assets/questions.json').readAsStringSync(),
      );
      final oldData = LearningData()
          .rate('daily-b-001', false, DateTime(2026, 11, 2))
          .rate('work-b-004', true, DateTime(2026, 11, 2));
      final restored = LearningData.decode(oldData.encode());
      expect(
        selectQuestions(questions, restored, reviewOnly: true).single.id,
        'daily-b-001',
      );
      expect(restored.entries['work-b-004']!.successes, 1);
      expect(restored.entries['daily-b-005'], isNull);
      expect(
        selectQuestions(questions, restored, level: '初級', scene: '日常').length,
        509,
      );
    },
  );
  test('all original 73 audio sources retain their text and provenance', () {
    final old = read('test/fixtures/audio_v0_2_0.json')['clips'] as List;
    final current = read('assets/audio/manifest.json')['clips'] as List;
    final byText = {for (final clip in current) clip['text']: clip};
    expect(old.length, 73);
    for (final clip in old) {
      expectCompressedOriginal(byText[clip['text']] as Map?, clip as Map);
    }
  });
}
