import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:phrase_flow/domain.dart';

void main() {
  test('legacy string answers and optional explanation remain supported', () {
    final source = jsonEncode({
      'schemaVersion': 1,
      'questions': [
        {
          'id': 'legacy',
          'level': '初級',
          'scene': '日常',
          'japanese': 'こんにちは。',
          'answers': [
            'Hello.',
            {'text': 'Hi.'},
          ],
        },
      ],
    });
    final answers = Question.decode(source).single.answers;
    expect(answers.map((a) => a.text), ['Hello.', 'Hi.']);
    expect(answers.every((a) => a.explanation.isEmpty), isTrue);
  });
  test('malformed structured answers and duplicate texts are rejected', () {
    for (final answers in [
      [
        {'explanation': 'missing text'},
      ],
      [
        {'text': 'Hello.', 'explanation': 42},
      ],
      [
        {'text': '  '},
      ],
      [
        'Hello.',
        {'text': 'Hello.'},
      ],
    ]) {
      final source = jsonEncode({
        'schemaVersion': 1,
        'questions': [
          {
            'id': 'invalid',
            'level': '初級',
            'scene': '日常',
            'japanese': 'こんにちは。',
            'answers': answers,
          },
        ],
      });
      expect(() => Question.decode(source), throwsFormatException);
    }
  });
  test(
    'every bundled question has alternatives and per-answer explanations',
    () {
      final questions = Question.decode(
        File('assets/questions.json').readAsStringSync(),
      );
      expect(questions.fold(0, (sum, q) => sum + q.answers.length), 3467);
      expect(
        questions.every(
          (q) =>
              q.answers.length >= 2 &&
              q.answers.every((a) => a.explanation.trim().isNotEmpty),
        ),
        isTrue,
      );
    },
  );
  late List<Question> catalog;
  setUp(
    () => catalog = Question.decode(
      File('assets/questions.json').readAsStringSync(),
    ),
  );
  test('catalog has 1733 unique questions with interest coverage', () {
    expect(catalog.length, 1733);
    expect(catalog.map((q) => q.id).toSet().length, 1733);
    for (final level in levels) {
      for (final scene in scenes) {
        expect(
          selectQuestions(
            catalog,
            LearningData(),
            level: level,
            scene: scene,
          ).length,
          scene == '日常'
              ? (level == '初級'
                    ? 509
                    : level == '中級'
                    ? 496
                    : 498)
              : (level == '初級' ? 39 : 38),
        );
      }
    }
  });
  test('duplicate ids and unsupported schema are rejected', () {
    final raw =
        jsonDecode(File('assets/questions.json').readAsStringSync())
            as Map<String, dynamic>;
    (raw['questions'] as List).add((raw['questions'] as List).first);
    expect(() => Question.decode(jsonEncode(raw)), throwsFormatException);
    expect(() => Question.decode('{"schemaVersion":2}'), throwsFormatException);
  });
  test('rating, review removal, counters and restart roundtrip', () {
    final now = DateTime(2026, 11, 2, 12);
    final a = LearningData().rate(catalog.first.id, false, now);
    expect(
      selectQuestions(catalog, a, reviewOnly: true).single.id,
      catalog.first.id,
    );
    var b = LearningData.decode(a.rate(catalog.first.id, true, now).encode());
    expect(b.entries[catalog.first.id]!.attempts, 2);
    expect(b.entries[catalog.first.id]!.successes, 1);
    expect(b.entries[catalog.first.id]!.lastStudied, now);
    for (var count = 1; count < 5; count++) {
      expect(b.entries[catalog.first.id]!.reviewSuccesses, count);
      expect(selectQuestions(catalog, b, reviewOnly: true), hasLength(1));
      if (count == 2) b = b.rate(catalog.first.id, false, now);
      b = LearningData.decode(b.rate(catalog.first.id, true, now).encode());
    }
    expect(selectQuestions(catalog, b, reviewOnly: true), isEmpty);
    final reopened = b
        .rate(catalog.first.id, false, now)
        .entries[catalog.first.id]!;
    expect(reopened.needsReview, isTrue);
    expect(reopened.reviewSuccesses, 0);
  });
  test(
    'legacy review starts at zero and a saved goal only affects open reviews',
    () {
      final now = DateTime(2026, 11, 2, 12);
      var data = LearningData.decode(
        '{"schemaVersion":1,"entries":{"q":{"attempts":8,"successes":7,"needsReview":true,"lastStudied":"2026-11-02T12:00:00"}}}',
      );
      expect(data.reviewGoal, 5);
      expect(data.entries['q']!.reviewSuccesses, 0);
      data = data
          .rate('q', true, now)
          .withReviewGoal(7)
          .visit(now)
          .withInterests(['travel'])
          .addTime({'2026-11-02': 1000});
      data = LearningData.decode(data.encode());
      expect(data.reviewGoal, 7);
      expect(data.entries['q']!.reviewSuccesses, 1);
      expect(data.entries['q']!.needsReview, isTrue);
      final complete = data.withReviewGoal(1);
      expect(complete.entries['q']!.needsReview, isFalse);
      expect(complete.withReviewGoal(9).entries['q']!.needsReview, isFalse);
      expect(complete.earnedXp, data.earnedXp);
      expect(complete.levelXpOffset, data.levelXpOffset);
      expect(() => complete.withReviewGoal(0), throwsArgumentError);
    },
  );
  test(
    'filters intersect and unstudied questions are excluded from review',
    () {
      final a = LearningData().rate(catalog.first.id, false, DateTime.now());
      expect(
        selectQuestions(catalog, a, level: '上級', reviewOnly: true),
        isEmpty,
      );
      expect(
        selectQuestions(catalog, a, scene: '日常', reviewOnly: true).length,
        1,
      );
      expect(selectQuestions(catalog, a, scene: '未定義'), isEmpty);
    },
  );
  test('content update retains history by id including retired questions', () {
    final a = LearningData()
        .rate(catalog.first.id, false, DateTime.now())
        .rate('retired-question', true, DateTime.now());
    final restored = LearningData.decode(a.encode());
    final expanded = [
      ...catalog,
      const Question('new-id', '初級', '日常', 'こんにちは。', [
        AnswerExample('Hello.'),
      ], ''),
    ];
    expect(
      selectQuestions(expanded, restored, reviewOnly: true).single.id,
      catalog.first.id,
    );
    expect(restored.entries['retired-question']!.successes, 1);
    expect(restored.entries['new-id'], isNull);
  });
  test('session has at most ten unique questions without changing source', () {
    final ids = catalog.map((q) => q.id).toList();
    final session = createSession(catalog, random: Random(42));
    expect(session.length, 10);
    expect(session.map((q) => q.id).toSet().length, 10);
    expect(catalog.map((q) => q.id), ids);
    expect(createSession(catalog.take(4).toList()).length, 4);
    expect(createSession([]), isEmpty);
  });
  test(
    'corrupt progress and unsupported versions fail instead of silently resetting',
    () {
      expect(() => LearningData.decode('broken'), throwsFormatException);
      expect(
        () => LearningData.decode('{"schemaVersion":2}'),
        throwsFormatException,
      );
      expect(
        () => LearningData.decode(
          jsonEncode({
            'schemaVersion': 1,
            'entries': {
              'q': {'attempts': 1, 'successes': 2},
            },
          }),
        ),
        throwsFormatException,
      );
    },
  );
}
