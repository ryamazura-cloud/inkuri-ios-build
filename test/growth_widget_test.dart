import 'interest_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phrase_flow/domain.dart';
import 'package:phrase_flow/growth.dart';
import 'package:phrase_flow/main.dart';
import 'speech_test.dart' show FakeSpeechEngine;
import 'widget_test.dart' show MemoryStore;

const question = Question('growth-q', '初級', '日常', 'こんにちは。', [
  AnswerExample('Hello.'),
], '');

Future<void> tap(WidgetTester tester, String label) async {
  final matches = find.text(label);
  if (matches.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      matches,
      180,
      scrollable: find.byType(Scrollable).first,
    );
  }
  final finder = matches.first;
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('store review is requested once after the 30th saved answer', (
    tester,
  ) async {
    var progress = LearningData().withInterests(['lifestyle']);
    for (var i = 0; i < 29; i++) {
      progress = progress.rate(question.id, true, DateTime(2026, 11, 8));
    }
    final store = MemoryStore()..raw = progress.encode();
    var requests = 0;
    await tester.pumpWidget(
      PhraseFlowApp(
        store: store,
        loadCatalog: () async => [question],
        requestStoreReview: () async {
          expect((await store.load()).entries[question.id]!.attempts, 30);
          requests++;
        },
      ),
    );
    await tester.pumpAndSettle();
    for (final expected in [0, 1]) {
      await tap(tester, 'スキルツリーを見る');
      await tap(tester, 'レベル1 家事勉強中の学習へ');
      await tap(tester, '答えを表示');
      expect(requests, expected);
      await tap(tester, 'できた');
      expect(requests, 1);
      expect(find.text('今日の取り組みをシェア'), findsNothing);
      await tap(tester, 'ホームに戻る');
    }
  });

  testWidgets('home opens tree and tree selection starts the matching lesson', (
    tester,
  ) async {
    final store = MemoryStore();
    await tester.pumpWidget(
      PhraseFlowApp(store: store, loadCatalog: () async => [question]),
    );
    await tester.pumpAndSettle();
    expect(find.text('Lv. 1'), findsOneWidget);
    expect(find.text('今日のトレーニング'), findsNothing);
    expect(find.text('難易度'), findsNothing);
    await tap(tester, 'スキルツリーを見る');
    await chooseAvailableInterest(tester);
    expect(find.text('スキルツリー'), findsOneWidget);
    expect(find.text('ライフスタイル・レベル1 家事勉強中'), findsOneWidget);
    await tap(tester, 'レベル1 家事勉強中の学習へ');
    expect(find.text(question.japanese), findsOneWidget);
    await tap(tester, '答えを表示');
    await tap(tester, 'できた');
    expect(find.text('獲得経験値  10 EXP'), findsOneWidget);
    expect(find.text('成果を共有'), findsNothing);
    expect((await store.load()).entries[question.id]!.successes, 1);
    await tap(tester, 'ホームに戻る');
    expect(find.text('累計 10 EXP'), findsOneWidget);
  });
  testWidgets(
    'level up result rewards saved ratings and failed saves award nothing',
    (tester) async {
      var data = LearningData();
      for (var i = 0; i < 14; i++) {
        data = data.rate(question.id, true, DateTime(2026, 11, 2));
      }
      var fail = true;
      await tester.pumpWidget(
        MaterialApp(
          home: TrainingPage(
            questions: const [question],
            speechEngine: FakeSpeechEngine(),
            growth: () => GrowthProgress(data),
            onRate: (q, success) async {
              if (fail) throw StateError('disk full');
              data = data.rate(q.id, success, DateTime(2026, 11, 2));
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tap(tester, '答えを表示');
      await tap(tester, 'できた');
      expect(GrowthProgress(data).xp, 140);
      fail = false;
      await tap(tester, 'できた');
      expect(find.text('獲得経験値  10 EXP'), findsOneWidget);
      expect(find.text('Lv. 1 → Lv. 2'), findsOneWidget);
      expect(GrowthProgress(data).xp, 150);
    },
  );
  testWidgets(
    'retry awards 5 EXP and a level increase is visible on the next question',
    (tester) async {
      var data = LearningData();
      for (var i = 0; i < 29; i++) {
        data = data.rate(question.id, false, DateTime(2026, 11, 2));
      }
      await tester.pumpWidget(
        MaterialApp(
          home: TrainingPage(
            questions: const [question, question],
            speechEngine: FakeSpeechEngine(),
            growth: () => GrowthProgress(data),
            onRate: (q, success) async {
              data = data.rate(q.id, success, DateTime(2026, 11, 2));
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tap(tester, '答えを表示');
      await tap(tester, 'まだ難しい');
      expect(find.text('レベルアップ！ Lv. 1 → 2'), findsOneWidget);
      expect(GrowthProgress(data).xp, 150);
      await tap(tester, '答えを表示');
      await tap(tester, 'まだ難しい');
      expect(find.text('獲得経験値  10 EXP'), findsOneWidget);
    },
  );
  testWidgets(
    'ten-question result retains ads but removes the old share button',
    (tester) async {
      var data = LearningData().rate(question.id, true, DateTime(2026, 11, 1));
      await tester.pumpWidget(
        MaterialApp(
          home: TrainingPage(
            questions: List.filled(10, question),
            completionBanner: const Text('成果画面の広告枠'),
            speechEngine: FakeSpeechEngine(),
            growth: () => GrowthProgress(data),
            onRate: (q, success) async {
              data = data.rate(q.id, success, DateTime(2026, 11, 2));
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (var i = 0; i < 10; i++) {
        expect(find.text('成果を共有'), findsNothing);
        expect(find.text('成果画面の広告枠'), findsNothing);
        await tap(tester, '答えを表示');
        await tap(tester, i == 0 ? 'まだ難しい' : 'できた');
      }
      expect(find.text('成果画面の広告枠'), findsOneWidget);
      expect(find.text('成果を共有'), findsNothing);
      expect(find.text('今日の取り組みをシェア'), findsNothing);
      expect(find.text('ホームに戻る'), findsOneWidget);
    },
  );
  testWidgets('growth card and tree are usable at 320px and double text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await tester.pumpWidget(
      PhraseFlowApp(store: MemoryStore(), loadCatalog: () async => [question]),
    );
    await tester.pumpAndSettle();
    await tap(tester, 'スキルツリーを見る');
    await chooseAvailableInterest(tester);
    await tap(tester, 'Lv. 2');
    await tester.scrollUntilVisible(
      find.text('レベル2 ？？？の学習へ'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'レベル2 ？？？の学習へ').first,
          )
          .onPressed,
      isNull,
    );
    await tester.fling(
      find.byType(Scrollable).first,
      const Offset(0, 2000),
      2000,
    );
    await tester.pumpAndSettle();
    await tap(tester, 'Lv. 1');
    await tap(tester, 'レベル1 家事勉強中の学習へ');
    await tap(tester, '答えを表示');
    await tap(tester, 'できた');
    await tap(tester, 'ホームに戻る');
    expect(tester.takeException(), isNull);
  });
}
