import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:phrase_flow/domain.dart';
import 'audio_preservation_helpers.dart';

Map<String, dynamic> read(String file) =>
    jsonDecode(File(file).readAsStringSync()) as Map<String, dynamic>;

void main() {
  test(
    'all 96 previous questions and 193 original audio sources are retained',
    () {
      final old =
          read('test/fixtures/catalog_v0_3_0.json')['questions'] as List;
      final current = read('assets/questions.json')['questions'] as List;
      final byId = {for (final q in current) q['id']: q};
      expect(old.length, 96);
      for (final q in old) {
        expect(byId[q['id']], q, reason: q['id'] as String);
      }
      final oldAudio = read('test/fixtures/audio_v0_3_0.json')['clips'] as List;
      final audio = read('assets/audio/manifest.json')['clips'] as List;
      final byText = {for (final clip in audio) clip['text']: clip};
      expect(oldAudio.length, 193);
      for (final clip in oldAudio) {
        expectCompressedOriginal(byText[clip['text']] as Map?, clip as Map);
      }
    },
  );

  test(
    '204 added questions produce exactly 100 per scene and balanced levels',
    () {
      final questions = Question.decode(
        File('test/fixtures/catalog_v0_6_1.json').readAsStringSync(),
      );
      final oldIds =
          (read('test/fixtures/catalog_v0_3_0.json')['questions'] as List)
              .map((q) => q['id'])
              .toSet();
      final added = questions.where((q) => !oldIds.contains(q.id)).toList();
      expect(added.length, 204);
      for (final scene in scenes) {
        expect(questions.where((q) => q.scene == scene).length, 100);
        expect(
          added.where((q) => q.scene == scene).length,
          scene == '日常' ? 28 : 88,
        );
        for (final level in levels) {
          expect(
            selectQuestions(
              questions,
              LearningData(),
              scene: scene,
              level: level,
            ).length,
            level == '初級' ? 34 : 33,
          );
        }
      }
      expect(
        added.every(
          (q) =>
              q.topic.isNotEmpty &&
              q.answers.length == 2 &&
              q.answers.every((a) => a.explanation.isNotEmpty),
        ),
        isTrue,
      );
      expect(questions.map((q) => q.japanese).toSet().length, 300);
      expect(
        questions.expand((q) => q.answers.map((a) => a.text)).toSet().length,
        601,
      );
    },
  );

  test(
    'previous expansion progress survives and new questions start unstudied',
    () {
      final questions = Question.decode(
        File('assets/questions.json').readAsStringSync(),
      );
      final data = LearningData()
          .rate('daily-a-024', false, DateTime(2026, 11, 2))
          .rate('travel-b-004', true, DateTime(2026, 11, 2));
      final restored = LearningData.decode(data.encode());
      expect(
        selectQuestions(questions, restored, reviewOnly: true).single.id,
        'daily-a-024',
      );
      expect(restored.entries['travel-b-004']!.successes, 1);
      for (final id in ['daily-b-025', 'travel-b-005', 'work-b-005']) {
        expect(restored.entries[id], isNull);
      }
    },
  );
}
