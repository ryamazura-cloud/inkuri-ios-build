import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phrase_flow/activity.dart';
import 'package:phrase_flow/domain.dart';
import 'package:phrase_flow/learning_dashboard.dart';
import 'package:phrase_flow/main.dart';
import 'speech_test.dart' show FakeSpeechEngine;
import 'widget_test.dart' show MemoryStore;

const question = Question('clock', '初級', '日常', 'おはよう。', [
  AnswerExample('Good morning.'),
], '');

Future<void> tap(WidgetTester tester, String text) async {
  final finder = find.text(text).first;
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'dashboard period cards, nonempty and empty graphs, month navigation',
    (tester) async {
      final data = LearningData(
        null,
        {'2026-11-02': const DailyActivity(questions: 3, milliseconds: 125000)},
        {'2026-11-01', '2026-11-02'},
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LearningDashboard(
                data: data,
                catalog: const [question],
                now: DateTime(2026, 11, 2),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ActivityChart), findsOneWidget);
      expect(find.text('学習記録を共有'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('学習の推移')).dy,
        lessThan(tester.getTopLeft(find.text('今日も、一歩ずつ。')).dy),
      );
      expect(find.text('学習問題数  3問'), findsNWidgets(3));
      expect(find.text('学習時間  2分 5秒'), findsNWidgets(3));
      expect(find.text('現在 2日連続  /  最長 2日連続'), findsOneWidget);
      await tap(tester, '月別');
      expect(find.textContaining('2025-12-01 〜 2026-11-30'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('前の期間'));
      await tester.tap(find.byTooltip('前の期間'));
      await tester.pumpAndSettle();
      expect(find.text('この期間の記録はまだありません。'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'dashboard and share preview remain usable at 320px and 2x text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LearningDashboard(
                data: LearningData(),
                catalog: const [question],
                now: DateTime(2026, 11, 2),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tap(tester, '学習記録を共有');
      expect(find.byType(AlertDialog), findsOneWidget);
      await tap(tester, '閉じる');
      await tap(tester, '月別');
      await tester.ensureVisible(find.text('バッジ  0 / 50'));
      final next = find.byTooltip('次のバッジページ');
      await tester.ensureVisible(next);
      await tester.pumpAndSettle();
      expect(find.text('1 / 7'), findsOneWidget);
      expect(find.text('60日継続'), findsOneWidget);
      expect(find.text('90日継続'), findsNothing);
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(find.text('2 / 7'), findsOneWidget);
      expect(find.text('90日継続'), findsOneWidget);
      expect(find.text('1日継続'), findsNothing);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'sharing requires explicit choice and sends exactly the previewed summary',
    (tester) async {
      MethodCall? received;
      const channel = MethodChannel('dev.fluttercommunity.plus/share');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        received = call;
        return 'test-share-target';
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      final total = PeriodTotal(
        '今週',
        DateTime(2026, 11, 2),
        DateTime(2026, 11, 9),
        20,
        60000,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showStudyShare(context, [total]),
                child: const Text('共有'),
              ),
            ),
          ),
        ),
      );
      await tap(tester, '共有');
      expect(received, isNull);
      expect(
        tester.widget<SelectableText>(find.byType(SelectableText)).data,
        shareSummary([total]),
      );
      await tap(tester, '共有先を選ぶ');
      expect(received?.method, 'share');
      expect((received?.arguments as Map)['text'], shareSummary([total]));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'opening the app records a single visit and retains legacy progress',
    (tester) async {
      final store = MemoryStore()
        ..raw = LearningData()
            .rate('old', true, DateTime(2026, 10, 1))
            .encode();
      await tester.pumpWidget(
        PhraseFlowApp(store: store, loadCatalog: () async => [question]),
      );
      await tester.pumpAndSettle();
      expect((await store.load()).visits, contains(dayKey(DateTime.now())));
      expect((await store.load()).entries['old']!.successes, 1);
      expect(find.textContaining('できた問題'), findsNothing);
      await tap(tester, '学習記録');
      expect(find.textContaining('できた問題'), findsNothing);
      expect(
        tester.getTopLeft(find.text('学習の推移')).dy,
        lessThan(tester.getTopLeft(find.text('今日も、一歩ずつ。')).dy),
      );
      final visits = (await store.load()).visits.length;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect((await store.load()).visits.length, visits);
    },
  );
  testWidgets('study time excludes background and the completion screen', (
    tester,
  ) async {
    var now = DateTime(2026, 11, 2, 12), milliseconds = 0, rated = 0;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      MaterialApp(
        home: TrainingPage(
          questions: const [question],
          speechEngine: FakeSpeechEngine(),
          now: () => now,
          onRate: (_, _) async {
            rated++;
          },
          onTime: (batch) async {
            milliseconds += batch.values.fold(0, (a, b) => a + b);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    now = now.add(const Duration(seconds: 10));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    expect(milliseconds, 10000);
    now = now.add(const Duration(hours: 1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    now = now.add(const Duration(seconds: 7));
    await tap(tester, '答えを表示');
    await tap(tester, 'できた');
    expect(milliseconds, 17000);
    expect(rated, 1);
    now = now.add(const Duration(minutes: 5));
    await tester.pump(const Duration(seconds: 16));
    expect(milliseconds, 17000);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'failed time save retries once without losing time or duplicating rating',
    (tester) async {
      var now = DateTime(2026, 11, 2, 12), milliseconds = 0, rated = 0;
      var fail = true;
      await tester.pumpWidget(
        MaterialApp(
          home: TrainingPage(
            questions: const [question],
            speechEngine: FakeSpeechEngine(),
            now: () => now,
            onRate: (_, _) async {
              rated++;
            },
            onTime: (batch) async {
              if (fail) throw StateError('storage full');
              milliseconds += batch.values.fold(0, (a, b) => a + b);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      now = now.add(const Duration(seconds: 5));
      await tap(tester, '答えを表示');
      await tap(tester, 'できた');
      expect(rated, 0);
      expect(milliseconds, 0);
      fail = false;
      now = now.add(const Duration(seconds: 3));
      await tap(tester, 'できた');
      expect(rated, 1);
      expect(milliseconds, 8000);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('exit dialog time is excluded, canceled session resumes timing', (
    tester,
  ) async {
    var now = DateTime(2026, 11, 2, 12), milliseconds = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: TrainingPage(
          questions: const [question],
          speechEngine: FakeSpeechEngine(),
          now: () => now,
          onRate: (_, _) async {},
          onTime: (batch) async {
            milliseconds += batch.values.fold(0, (a, b) => a + b);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    now = now.add(const Duration(seconds: 5));
    await tester.tap(find.byTooltip('学習を終了'));
    await tester.pumpAndSettle();
    now = now.add(const Duration(seconds: 40));
    await tap(tester, '続ける');
    now = now.add(const Duration(seconds: 5));
    await tap(tester, '答えを表示');
    await tap(tester, 'できた');
    expect(milliseconds, 10000);
    await tester.pumpWidget(const SizedBox());
  });
}
