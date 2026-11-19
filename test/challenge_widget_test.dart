import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phrase_flow/domain.dart';
import 'package:phrase_flow/growth.dart';
import 'package:phrase_flow/main.dart';
import 'speech_test.dart' show FakeSpeechEngine;
import 'widget_test.dart' show MemoryStore;

Future<void> tap(WidgetTester t, String label) async {
  final f = find.text(label).first;
  await Scrollable.ensureVisible(t.element(f), alignment: .5);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

void main() {
  final questions = List.generate(
    5,
    (i) => Question(
      'exam-$i',
      '初級',
      '日常',
      '問題$iです。',
      [AnswerExample('This is question $i.')],
      '',
      category: 'beauty',
    ),
  );
  testWidgets(
    'last rating and pass save atomically; failed save retries once',
    (t) async {
      final store = MemoryStore();
      Future<void> rate(
        Question q,
        bool success,
        int? finalScore,
        int total,
      ) async {
        var next = (await store.load()).rate(
          q.id,
          success,
          DateTime(2026, 11, 3),
        );
        if (finalScore != null) {
          next = next.finishChallenge(
            'beauty',
            'stage-1',
            finalScore,
            total,
            DateTime(2026, 11, 3),
          );
        }
        await store.save(next);
      }

      await t.pumpWidget(
        MaterialApp(
          home: TrainingPage(
            questions: questions,
            onRate: (_, _) async {
              throw StateError('wrong callback');
            },
            challengeLabel: '美容/コスメ・レベル1 美容初心者',
            onChallengeRate: rate,
            speechEngine: FakeSpeechEngine(),
          ),
        ),
      );
      await t.pumpAndSettle();
      for (var i = 0; i < 4; i++) {
        await tap(t, '答えを表示');
        await tap(t, 'できた');
      }
      expect((await store.load()).challengePasses, isEmpty);
      await tap(t, '答えを表示');
      store.fail = true;
      await tap(t, 'まだ難しい');
      expect(find.text('挑戦合格！'), findsNothing);
      expect((await store.load()).entries.length, 4);
      expect((await store.load()).challengePasses, isEmpty);
      store.fail = false;
      await tap(t, 'まだ難しい');
      final data = await store.load();
      expect(data.entries['exam-4']!.attempts, 1);
      expect(data.days['2026-11-03']!.questions, 5);
      expect(data.challengePasses['beauty|stage-1']!.score, 4);
      expect(find.text('挑戦合格！'), findsOneWidget);
      expect(find.text('今回の達成率 80%（合格基準80%以上）'), findsOneWidget);
      expect(GrowthProgress(data).xp, 45);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets('unfinished challenge stores ratings but no pass', (t) async {
    var data = LearningData();
    await t.pumpWidget(
      MaterialApp(
        home: TrainingPage(
          questions: questions,
          onRate: (_, _) async {},
          challengeLabel: '美容/コスメ・レベル1 美容初心者',
          speechEngine: FakeSpeechEngine(),
          onChallengeRate: (q, ok, score, total) async {
            data = data.rate(q.id, ok, DateTime(2026, 11, 3));
            if (score != null) {
              data = data.finishChallenge(
                'beauty',
                '初級',
                score,
                total,
                DateTime(2026, 11, 3),
              );
            }
          },
        ),
      ),
    );
    await t.pumpAndSettle();
    await tap(t, '答えを表示');
    await tap(t, 'できた');
    await t.tap(find.byTooltip('学習を終了'));
    await t.pumpAndSettle();
    expect(find.textContaining('挑戦の合否は保存されません'), findsOneWidget);
    expect(data.entries.length, 1);
    expect(data.challengePasses, isEmpty);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
    'three of five is a failed attempt; advanced pass has final message',
    (t) async {
      Future<void> run(int score, String level) async {
        await t.pumpWidget(
          MaterialApp(
            key: UniqueKey(),
            home: TrainingPage(
              questions: questions,
              onRate: (_, _) async {},
              challengeLabel: '美容/コスメ・$level',
              finalChallenge: level == 'レベル5 美の錬金術師',
              speechEngine: FakeSpeechEngine(),
              onChallengeRate: (_, _, _, _) async {},
            ),
          ),
        );
        await t.pumpAndSettle();
        for (var i = 0; i < 5; i++) {
          await tap(t, '答えを表示');
          await tap(t, i < score ? 'できた' : 'まだ難しい');
        }
      }

      await run(3, '初級');
      expect(find.text('挑戦合格！'), findsNothing);
      expect(find.text('今回の達成率 60%（合格基準80%以上）'), findsOneWidget);
      await run(4, 'レベル5 美の錬金術師');
      expect(find.text('この分野の最終チャレンジを達成しました！'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'usage button next to info shows screenshots, 2/5 second advice, and zoom at double text',
    (t) async {
      t.view.physicalSize = const Size(320, 568);
      t.view.devicePixelRatio = 1;
      t.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() {
        t.view.resetPhysicalSize();
        t.view.resetDevicePixelRatio();
        t.platformDispatcher.clearTextScaleFactorTestValue();
      });
      final store = MemoryStore();
      await t.pumpWidget(
        PhraseFlowApp(store: store, loadCatalog: () async => questions),
      );
      await t.pumpAndSettle();
      expect(find.byTooltip('このアプリについて'), findsOneWidget);
      await t.tap(find.text('使い方'));
      await t.pumpAndSettle();
      expect(find.text('1 / 6'), findsOneWidget);
      expect(find.textContaining('Thank you'), findsOneWidget);
      expect(
        find.image(const AssetImage('assets/guide/expression-growth.png')),
        findsOneWidget,
      );
      await tap(t, '次へ');
      expect(find.textContaining('英文の組み立て方'), findsOneWidget);
      await tap(t, '次へ');
      expect(find.textContaining('10問で修行する'), findsOneWidget);
      expect(find.textContaining('冒険モードでは、「スキルツリーを見る」'), findsOneWidget);
      await tap(t, '次へ');
      expect(find.text('2秒以内に言い始める'), findsOneWidget);
      expect(find.text('答えられなかったら、3〜5回声に出す'), findsOneWidget);
      expect(find.textContaining('音声を再生'), findsOneWidget);
      await tap(t, '次へ');
      expect(find.textContaining('5秒以上'), findsOneWidget);
      expect(find.textContaining('累計5回'), findsOneWidget);
      expect(find.textContaining('「復習設定」で変更'), findsOneWidget);
      final screenshot = find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName == 'assets/guide/review.png',
      );
      await t.ensureVisible(screenshot);
      await t.pumpAndSettle();
      await t.tap(screenshot);
      await t.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      await tap(t, '閉じる');
      await tap(t, '次へ');
      expect(find.text('6 / 6'), findsOneWidget);
      expect(find.textContaining('報酬を受け取れます'), findsOneWidget);
      expect(find.textContaining('挑戦で5問中4問'), findsOneWidget);
      await tap(t, 'はじめる');
      expect(find.byType(Dialog), findsNothing);
      await t.tap(find.byTooltip('このアプリについて'));
      await t.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('登録不要'), findsOneWidget);
      expect(find.textContaining('機種変更で失われる'), findsOneWidget);
      expect(find.textContaining('共有機能では'), findsNothing);
      expect(find.text('ライセンスを表示'), findsNothing);
      await tap(t, '閉じる');
      await t.pumpAndSettle();
      expect((await store.load()).entries, isEmpty);
      expect(t.takeException(), isNull);
    },
  );
}
