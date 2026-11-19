import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phrase_flow/domain.dart';
import 'package:phrase_flow/main.dart';
import 'speech_test.dart' show FakeSpeechEngine;

const question = Question('audio', '初級', '仕事', '質問があります。', [
  AnswerExample('I have a question.'),
  AnswerExample("I've got a question."),
], '');

Future<void> tap(WidgetTester tester, String label) async {
  final finder = find.text(label).first;
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> open(
  WidgetTester tester,
  FakeSpeechEngine engine,
  Future<void> Function(Question, bool) onRate,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: TrainingPage(
        questions: [question],
        onRate: onRate,
        speechEngine: engine,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'audio is hidden before reveal and each English answer can play',
    (tester) async {
      final engine = FakeSpeechEngine();
      await open(tester, engine, (_, _) async {});
      expect(find.text('音声を再生'), findsNothing);
      expect(engine.spoken, isEmpty);
      await tap(tester, '答えを表示');
      expect(find.text('音声を再生'), findsNWidgets(2));
      await tap(tester, '音声を再生');
      expect(engine.spoken, ['I have a question.']);
      expect(find.text('音声を停止'), findsOneWidget);
      await tap(tester, '音声を再生');
      expect(engine.spoken.last, "I've got a question.");
      engine.completions.first.complete();
      await tester.pumpAndSettle();
      expect(find.text('音声を停止'), findsOneWidget);
      await tap(tester, '音声を停止');
      expect(find.text('音声を停止'), findsNothing);
      engine.completions.last.complete();
      await tester.pumpAndSettle();
    },
  );
  testWidgets('rating and backgrounding stop current audio', (tester) async {
    final engine = FakeSpeechEngine();
    var rated = 0;
    await open(tester, engine, (_, _) async {
      rated++;
    });
    await tap(tester, '答えを表示');
    await tap(tester, '音声を再生');
    final before = engine.stops;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(engine.stops, greaterThan(before));
    expect(find.text('音声を停止'), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tap(tester, '音声を再生');
    final beforeRating = engine.stops;
    await tap(tester, 'できた');
    expect(rated, 1);
    expect(engine.stops, greaterThan(beforeRating));
    expect(find.text('今日の一歩、完了。'), findsOneWidget);
    for (final completer in engine.completions) {
      completer.complete();
    }
    await tester.pumpAndSettle();
  });
  testWidgets(
    'audio failure shows guidance while self evaluation remains usable',
    (tester) async {
      final engine = FakeSpeechEngine()..fail = true;
      var rated = 0;
      await open(tester, engine, (_, _) async {
        rated++;
      });
      await tap(tester, '答えを表示');
      await tap(tester, '音声を再生');
      expect(find.textContaining('音声を再生できませんでした'), findsOneWidget);
      await tap(tester, 'できた');
      expect(rated, 1);
    },
  );
}
