import 'interest_helpers.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phrase_flow/main.dart';
import 'package:phrase_flow/domain.dart';
import 'package:phrase_flow/store.dart';

const q = Question('q-1', '初級', '日常', '私は毎朝コーヒーを飲みます。', [
  AnswerExample('I drink coffee every morning.'),
], '習慣には現在形。');

class MemoryStore implements ProgressStore {
  String? raw;
  bool fail = false;
  Completer<void>? pending;
  @override
  Future<LearningData> load() async =>
      raw == null ? LearningData() : LearningData.decode(raw!);
  @override
  Future<void> save(LearningData data) async {
    if (fail) throw StateError('storage unavailable');
    if (pending != null) await pending!.future;
    raw = data.encode();
  }
}

Future<void> openApp(WidgetTester tester, MemoryStore store) async {
  await tester.pumpWidget(
    PhraseFlowApp(store: store, loadCatalog: () async => [q]),
  );
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      180,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> startStudy(WidgetTester tester) async {
  await tapText(tester, 'スキルツリーを見る');
  await chooseAvailableInterest(tester);
  final button = find.ancestor(
    of: find.byWidgetPredicate(
      (widget) => widget is Text && (widget.data?.endsWith('の学習へ') ?? false),
    ),
    matching: find.byType(OutlinedButton),
  );
  if (button.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      button,
      180,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await Scrollable.ensureVisible(tester.element(button.first), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(button.first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'not yet rating saves for later and advances to a different question',
    (tester) async {
      const next = Question('q-next', '初級', '日常', '次の問題です。', [
        AnswerExample('This is the next question.'),
      ], '');
      final store = MemoryStore();
      await tester.pumpWidget(
        MaterialApp(
          home: TrainingPage(
            questions: const [q, next],
            onRate: (question, success) async {
              await store.save(
                (await store.load()).rate(question.id, success, DateTime.now()),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tapText(tester, '答えを表示');
      expect(find.text('もう一度'), findsNothing);
      expect(find.text('学習記録に残し、あとから復習できます。'), findsOneWidget);
      await tapText(tester, 'まだ難しい');
      expect(find.text(next.japanese), findsOneWidget);
      expect(find.text(q.japanese), findsNothing);
      final saved = await store.load();
      expect(saved.entries[q.id]!.needsReview, isTrue);
      expect(saved.entries[q.id]!.attempts, 1);
      expect(saved.entries[next.id], isNull);
    },
  );
  testWidgets(
    'new long daily exercise and topic remain usable at large text size',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      final question = Question.decode(
        File('assets/questions.json').readAsStringSync(),
      ).singleWhere((q) => q.id == 'daily-a-020');
      final store = MemoryStore();
      await tester.pumpWidget(
        MaterialApp(
          home: TrainingPage(
            questions: [question],
            onRate: (q, success) async {
              await store.save(
                (await store.load()).rate(q.id, success, DateTime.now()),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('友人・予定'), findsWidgets);
      await tapText(tester, '答えを表示');
      expect(find.text('文法・単語の使い分け'), findsOneWidget);
      for (final answer in question.answers) {
        expect(find.text(answer.text), findsOneWidget);
      }
      await tapText(tester, 'まだ難しい');
      expect((await store.load()).entries[question.id]!.needsReview, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'question alternatives and nuances appear only after reveal at large text size',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      final question = Question.decode(
        File('assets/questions.json').readAsStringSync(),
      ).singleWhere((q) => q.id == 'work-b-004');
      final store = MemoryStore();
      await tester.pumpWidget(
        PhraseFlowApp(store: store, loadCatalog: () async => [question]),
      );
      await tester.pumpAndSettle();
      await startStudy(tester);
      for (final answer in question.answers) {
        expect(find.text(answer.text), findsNothing);
        expect(find.text(answer.explanation), findsNothing);
      }
      await tapText(tester, '答えを表示');
      for (final answer in question.answers) {
        expect(find.text(answer.text), findsOneWidget);
        expect(find.text(answer.explanation), findsOneWidget);
        await Scrollable.ensureVisible(
          tester.element(find.text(answer.explanation)),
          alignment: 0.5,
        );
        await tester.pumpAndSettle();
      }
      expect(find.text('別の言い方 1'), findsOneWidget);
      expect(find.text('別の言い方 2'), findsOneWidget);
      expect(find.text('ニュアンス・使い方'), findsNWidgets(3));
      expect(find.text('学習のポイント'), findsOneWidget);
      await tapText(tester, 'できた');
      expect((await store.load()).entries[question.id]!.successes, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('reveal, rate, finish, restart, review and clear weak status', (
    tester,
  ) async {
    final store = MemoryStore();
    await openApp(tester, store);
    await startStudy(tester);
    expect(find.text(q.answers.first.text), findsNothing);
    expect(find.text('できた'), findsNothing);
    await tapText(tester, '答えを表示');
    expect(find.text(q.answers.first.text), findsOneWidget);
    expect(find.text('ニュアンス・使い方'), findsNothing);
    await tapText(tester, 'まだ難しい');
    expect(find.text('今日の一歩、完了。'), findsOneWidget);
    await tapText(tester, 'ホームに戻る');
    await tester.pumpWidget(const SizedBox());
    await openApp(tester, store);
    expect(find.textContaining(RegExp(r'学習済み .*累計')), findsNothing);
    await tapText(tester, '学習記録');
    await tester.scrollUntilVisible(
      find.text('学習記録をリセット'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining(RegExp(r'学習済み .*累計')), findsNothing);
    expect(find.textContaining('苦手問題'), findsNothing);
    expect(find.text('復習設定'), findsNothing);
    await tapText(tester, 'トレーニング');
    await tapText(tester, '復習（1問）');
    await tapText(tester, '答えを表示');
    await tapText(tester, 'できた');
    await tapText(tester, 'ホームに戻る');
    final reviewed = (await store.load()).entries[q.id]!;
    expect(reviewed.needsReview, isTrue);
    expect(reviewed.reviewSuccesses, 1);
    expect(find.text('復習設定'), findsNothing);
    await tester.tap(find.byTooltip('このアプリについて'));
    await tester.pumpAndSettle();
    expect(find.text('「できた」5回で復習完了'), findsOneWidget);
    await tapText(tester, '復習設定');
    await tester.enterText(find.byType(TextFormField), '0');
    await tapText(tester, '保存する');
    expect(find.text('1以上の整数を入力してください。'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '1');
    await tapText(tester, '保存する');
    expect(find.text('「できた」1回で復習完了'), findsOneWidget);
    await tapText(tester, '閉じる');
    expect(find.text('復習（0問）'), findsOneWidget);
    final saved = await store.load();
    expect(saved.reviewGoal, 1);
    final entry = saved.entries[q.id]!;
    expect(entry.attempts, 2);
    expect(entry.needsReview, false);
  });
  testWidgets('available Play update opens the listing and can be dismissed', (
    tester,
  ) async {
    const updateChannel = MethodChannel('biz.wisemap.encre/app_update');
    const urlChannel = MethodChannel('plugins.flutter.io/url_launcher');
    final messenger = tester.binding.defaultBinaryMessenger;
    final opened = <String>[];
    messenger.setMockMethodCallHandler(updateChannel, (call) async {
      expect(call.method, 'isUpdateAvailable');
      return true;
    });
    messenger.setMockMethodCallHandler(urlChannel, (call) async {
      expect(call.method, 'launch');
      opened.add((call.arguments as Map)['url'] as String);
      return true;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(updateChannel, null);
      messenger.setMockMethodCallHandler(urlChannel, null);
    });

    await openApp(tester, MemoryStore());
    final notice = find.text('新しいバージョンがあります');
    expect(notice, findsOneWidget);
    await tapText(tester, '更新する');
    expect(opened, ['market://details?id=biz.wisemap.encre']);
    await tapText(tester, 'あとで');
    expect(notice, findsNothing);
  });

  testWidgets('Play update check failure leaves the home usable', (
    tester,
  ) async {
    const channel = MethodChannel('biz.wisemap.encre/app_update');
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'unavailable');
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await openApp(tester, MemoryStore());
    expect(find.text('新しいバージョンがあります'), findsNothing);
    expect(find.byTooltip('このアプリについて'), findsOneWidget);
  });

  testWidgets('app info opens the published legal pages', (tester) async {
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    final messenger = tester.binding.defaultBinaryMessenger;
    final opened = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'launch');
      opened.add((call.arguments as Map)['url'] as String);
      return true;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await openApp(tester, MemoryStore());
    await tester.tap(find.byTooltip('このアプリについて'));
    await tester.pumpAndSettle();
    await tapText(tester, 'プライバシーポリシー');
    await tapText(tester, '利用規約');

    expect(opened, [
      'https://encre.wisemap.biz/privacy-policy-2/',
      'https://encre.wisemap.biz/terms/',
    ]);
  });

  testWidgets('failed save keeps question and retry records once', (
    tester,
  ) async {
    final store = MemoryStore();
    await openApp(tester, store);
    await startStudy(tester);
    store.fail = true;
    await tapText(tester, '答えを表示');
    await tapText(tester, 'できた');
    expect(find.text('1 / 1'), findsOneWidget);
    expect((await store.load()).entries, isEmpty);
    store.fail = false;
    await tapText(tester, 'できた');
    expect((await store.load()).entries[q.id]!.attempts, 1);
  });
  testWidgets('rating buttons disable while save is pending', (tester) async {
    final store = MemoryStore();
    await openApp(tester, store);
    await startStudy(tester);
    store.pending = Completer<void>();
    await tapText(tester, '答えを表示');
    await tester.ensureVisible(find.text('できた'));
    await tester.tap(find.text('できた'));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'できた'))
          .onPressed,
      isNull,
    );
    store.pending!.complete();
    await tester.pumpAndSettle();
    expect((await store.load()).entries[q.id]!.attempts, 1);
  });
  testWidgets('exit confirmation and reset cancellation preserve data', (
    tester,
  ) async {
    final store = MemoryStore();
    await openApp(tester, store);
    await startStudy(tester);
    await tester.tap(find.byTooltip('学習を終了'));
    await tester.pumpAndSettle();
    await tapText(tester, '続ける');
    expect(find.text('1 / 1'), findsOneWidget);
    await tester.tap(find.byTooltip('学習を終了'));
    await tester.pumpAndSettle();
    await tapText(tester, '終了する');
    expect((await store.load()).entries, isEmpty);
    await tapText(tester, '学習記録');
    await tapText(tester, '学習記録をリセット');
    await tapText(tester, 'キャンセル');
    expect((await store.load()).entries, isEmpty);
    await tapText(tester, '学習記録をリセット');
    await tapText(tester, '削除する');
    expect((await store.load()).entries, isEmpty);
  });
  testWidgets('corrupt data does not overwrite original', (tester) async {
    final store = MemoryStore()..raw = 'corrupt';
    await openApp(tester, store);
    expect(find.text('データを読み込めませんでした'), findsOneWidget);
    await tapText(tester, '再試行');
    expect(store.raw, 'corrupt');
  });
  testWidgets('small viewport with large text stays scrollable', (
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
    await openApp(tester, MemoryStore());
    await startStudy(tester);
    await tapText(tester, '答えを表示');
    await tapText(tester, 'できた');
    expect(tester.takeException(), isNull);
  });
}
