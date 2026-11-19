import '../test/interest_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:phrase_flow/domain.dart';
import 'package:phrase_flow/main.dart';
import 'package:phrase_flow/store.dart';
import 'package:phrase_flow/activity.dart';
import 'package:phrase_flow/achievements.dart';
import 'package:phrase_flow/growth.dart';
import 'package:phrase_flow/stages.dart';
import 'package:phrase_flow/interests.dart';

const testKey = 'phrase_flow.progress.android_smoke_test';

Future<void> tapText(
  WidgetTester tester,
  String text, {
  bool settle = true,
}) async {
  await waitForForeground(tester);
  final matches = find.text(text);
  if (matches.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      matches,
      180,
      scrollable: find.byType(Scrollable).first,
    );
  }
  final finder = matches.first;
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  // Native audio updates its position each frame; waiting for all frames to
  // settle here would wait until playback ended before tapping Stop.
  await tester.pump();
  await tester.tap(finder);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

Future<void> startStudy(WidgetTester tester) async {
  await tapText(tester, 'スキルツリーを見る');
  await chooseAvailableInterest(tester);
  final button = find.ancestor(
    of: find.byWidgetPredicate(
      (w) => w is Text && (w.data?.endsWith('の学習へ') ?? false),
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
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android: audio, persistence, challenge gates and usage guide', (
    tester,
  ) async {
    final productionPreferences = SharedPreferencesAsync();
    final productionBefore = await productionPreferences.getString(
      LocalProgressStore.key,
    );
    try {
      for (final questionId in [
        'daily-b-025',
        'travel-b-005',
        'work-b-005',
        'expansion-beauty-b-001',
        'expansion-games-b-003',
      ]) {
        const dailyKey = '$testKey.daily';
        final preferences = SharedPreferencesAsync();
        final catalog = Question.decode(
          await rootBundle.loadString('assets/questions.json'),
        );
        expect(catalog.length, 1733);
        final question = catalog.singleWhere((q) => q.id == questionId);
        final store = LocalProgressStore(storageKey: dailyKey);
        await store.save(LearningData());
        try {
          await tester.pumpWidget(
            PhraseFlowApp(store: store, loadCatalog: () async => [question]),
          );
          await tester.pumpAndSettle();
          await startStudy(tester);
          expect(find.textContaining(question.topic), findsWidgets);
          await tapText(tester, '答えを表示');
          expect(find.text('音声を再生'), findsNWidgets(2));
          await waitForForeground(tester);
          await tapText(tester, '音声を再生', settle: false);
          expect(find.text('音声を停止'), findsOneWidget);
          final timer = Stopwatch()..start();
          while (find.text('音声を停止').evaluate().isNotEmpty &&
              timer.elapsed < const Duration(seconds: 15)) {
            await tester.pump(const Duration(milliseconds: 200));
          }
          debugPrint('[native] bundled audio completed: $questionId');
          expect(timer.elapsedMilliseconds, inExclusiveRange(300, 10000));
          expect(find.text('音声を停止'), findsNothing);
          expect(find.textContaining('音声を再生できませんでした'), findsNothing);
          await waitForForeground(tester);
          await tapText(tester, 'できた');
          final activity = await LocalProgressStore(
            storageKey: dailyKey,
          ).load();
          expect(activity.days[dayKey(DateTime.now())]!.questions, 1);
          expect(
            activity.days[dayKey(DateTime.now())]!.milliseconds,
            greaterThan(0),
          );
          expect(
            achievements(activity).singleWhere((b) => b.id == 'clear-1').earned,
            isTrue,
          );
          expect(
            (await LocalProgressStore(
              storageKey: dailyKey,
            ).load()).entries[question.id]!.successes,
            1,
          );
        } finally {
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          await preferences.remove(dailyKey);
        }
      }
      {
        const growthKey = '$testKey.growth';
        final preferences = SharedPreferencesAsync();
        final catalog = Question.decode(
          await rootBundle.loadString('assets/questions.json'),
        );
        final pool = catalog
            .where(
              (q) => categoryForQuestion(q) == 'lifestyle' && q.level == '初級',
            )
            .take(25)
            .toList();
        final questions = selectStageQuestions(pool, 'lifestyle', 'stage-1');
        var seeded = LearningData();
        for (final q in questions.take(4)) {
          seeded = seeded.rate(q.id, true, DateTime.now());
        }
        final store = LocalProgressStore(storageKey: growthKey);
        await store.save(seeded);
        try {
          await tester.pumpWidget(
            PhraseFlowApp(store: store, loadCatalog: () async => pool),
          );
          await tester.pumpAndSettle();
          expect(find.text('Lv. 1'), findsOneWidget);
          await tapText(tester, 'スキルツリーを見る');
          await chooseAvailableInterest(tester);
          expect(find.text('ライフスタイル・レベル1 家事勉強中'), findsOneWidget);
          await tapText(tester, 'レベル1 家事勉強中の学習へ');
          for (var i = 0; i < 5; i++) {
            await tapText(tester, '答えを表示');
            await tapText(tester, 'できた');
          }
          expect(find.text('獲得経験値  50 EXP'), findsOneWidget);
          expect(find.text('Lv. 1 → Lv. 2'), findsOneWidget);
          final saved = await LocalProgressStore(storageKey: growthKey).load();
          expect(GrowthProgress(saved).xp, 90);
          expect(
            interestSkills(pool, saved.withInterests(['lifestyle'])).first.rank,
            3,
          );
          await tapText(tester, 'ホームに戻る');
          expect(find.text('Lv. 2'), findsOneWidget);
        } finally {
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          await preferences.remove(growthKey);
        }
      }
      {
        final preferences = SharedPreferencesAsync();
        final catalog = Question.decode(
          await rootBundle.loadString('assets/questions.json'),
        );
        final question = catalog.singleWhere((q) => q.id == 'work-b-004');
        final store = LocalProgressStore(storageKey: testKey);
        await store.save(LearningData());
        try {
          await tester.pumpWidget(
            PhraseFlowApp(store: store, loadCatalog: () async => [question]),
          );
          await tester.pumpAndSettle();
          await startStudy(tester);
          expect(find.text('音声を再生'), findsNothing);
          await tapText(tester, '答えを表示');
          expect(find.text('音声を再生'), findsNWidgets(3));

          // Exercises the actual Android audio decoder and player-complete event.
          await waitForForeground(tester);
          await tapText(tester, '音声を再生', settle: false);
          expect(find.textContaining('音声を再生できませんでした'), findsNothing);
          expect(find.text('音声を停止'), findsOneWidget);
          final timer = Stopwatch()..start();
          while (find.text('音声を停止').evaluate().isNotEmpty &&
              timer.elapsed < const Duration(seconds: 15)) {
            await tester.pump(const Duration(milliseconds: 250));
          }
          expect(find.text('音声を停止'), findsNothing);
          expect(find.textContaining('音声を再生できませんでした'), findsNothing);
          expect(timer.elapsedMilliseconds, inExclusiveRange(500, 10000));
          await waitForForeground(tester);

          await tapText(tester, '音声を再生', settle: false);
          await tapText(tester, '音声を停止');
          expect(find.text('音声を停止'), findsNothing);

          await tapText(tester, 'まだ難しい');
          await tapText(tester, 'ホームに戻る');
          final restored = await LocalProgressStore(storageKey: testKey).load();
          expect(restored.entries[question.id]!.attempts, 1);
          expect(restored.entries[question.id]!.needsReview, isTrue);

          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          await tester.pumpWidget(
            PhraseFlowApp(
              store: LocalProgressStore(storageKey: testKey),
              loadCatalog: () async => [question],
            ),
          );
          await tester.pumpAndSettle();
          await tapText(tester, '復習（1問）');
          await tapText(tester, '答えを表示');
          await tapText(tester, 'できた');
          final reviewed = await LocalProgressStore(storageKey: testKey).load();
          expect(reviewed.entries[question.id]!.attempts, 2);
          expect(reviewed.entries[question.id]!.needsReview, isTrue);
          expect(reviewed.entries[question.id]!.reviewSuccesses, 1);
          expect(reviewed.days[dayKey(DateTime.now())]!.questions, 2);
          await tapText(tester, 'ホームに戻る');
          expect(find.text('インクリ'), findsOneWidget);
          await tapText(tester, '学習記録');
          await tapText(tester, '学習記録をまとめて共有');
          expect(find.byType(AlertDialog), findsOneWidget);
          expect(find.byType(SelectableText), findsOneWidget);
          final shared = tester
              .widget<SelectableText>(find.byType(SelectableText))
              .data!;
          expect(shared, contains('今日（'));
          expect(shared, contains('今週（'));
          expect(shared, contains('今月（'));
          expect(find.textContaining('できた問題'), findsNothing);
          await tapText(tester, '閉じる');
          await tapText(tester, '月別');
          expect(find.text('学習問題数と学習時間'), findsOneWidget);
          expect(find.text('獲得済み'), findsWidgets);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          await preferences.remove(testKey);
        }
      }
      await challengeAndGuide(tester);
      debugPrint('[native] challenge 4/5, next stage and usage guide verified');
      await compactHomeAndRoles(tester);
    } finally {
      expect(
        await productionPreferences.getString(LocalProgressStore.key),
        productionBefore,
        reason:
            'Normal learning history must remain unchanged by native scenarios',
      );
      debugPrint(
        '[native] normal learning history unchanged by test scenarios',
      );
    }
  });
}

Future<void> challengeAndGuide(WidgetTester tester) async {
  const key = '$testKey.challenge';
  final preferences = SharedPreferencesAsync();
  final catalog = Question.decode(
    await rootBundle.loadString('assets/questions.json'),
  );
  final pool = selectInterestQuestions(
    catalog,
    'beauty',
    level: '初級',
  ).take(25).toList();
  final basic = selectStageQuestions(pool, 'beauty', 'stage-1');
  final intermediate = selectStageQuestions(pool, 'beauty', 'stage-2');
  final store = LocalProgressStore(storageKey: key);
  var data = LearningData().withInterests(['beauty']);
  for (final q in basic.take(4)) {
    data = data.rate(q.id, true, DateTime.now());
  }
  await store.save(data);
  try {
    await tester.pumpWidget(
      PhraseFlowApp(store: store, loadCatalog: () async => pool),
    );
    await tester.pumpAndSettle();
    await tapText(tester, '使い方');
    expect(find.text('1 / 6'), findsOneWidget);
    expect(find.textContaining('Thank you'), findsOneWidget);
    await tapText(tester, '次へ');
    expect(find.textContaining('英文の組み立て方'), findsOneWidget);
    await tapText(tester, '次へ');
    expect(find.textContaining('学年と文法を選び'), findsOneWidget);
    await tapText(tester, '次へ');
    expect(find.text('2秒以内に言い始める'), findsOneWidget);
    await tapText(tester, '次へ');
    expect(find.textContaining('考えるのに5秒以上'), findsOneWidget);
    await tapText(tester, '次へ');
    expect(find.text('6 / 6'), findsOneWidget);
    expect(find.textContaining('通常問題の8割'), findsOneWidget);
    await tapText(tester, 'はじめる');
    await tapText(tester, 'スキルツリーを見る');
    await tapText(tester, 'レベル1 美容初心者の挑戦問題へ');
    for (var i = 0; i < 5; i++) {
      await tapText(tester, '答えを表示');
      await tapText(tester, i < 4 ? 'できた' : 'まだ難しい');
    }
    expect(find.text('挑戦合格！'), findsOneWidget);
    final saved = await store.load();
    expect(saved.challengePasses['beauty|stage-1']!.score, 4);
    expect(saved.days[dayKey(DateTime.now())]!.questions, 9);
    expect(GrowthProgress(saved).xp, 85);
    await tapText(tester, 'スキルツリーに戻る');
    await tapText(tester, 'レベル2 彩りの使い手の学習へ');
    expect(
      intermediate.any((q) => find.text(q.japanese).evaluate().isNotEmpty),
      isTrue,
    );
    await tester.tap(find.byTooltip('学習を終了'));
    await tester.pumpAndSettle();
    await tapText(tester, '終了する');
    expect(tester.takeException(), isNull);
  } finally {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await preferences.remove(key);
  }
}

Future<void> compactHomeAndRoles(WidgetTester tester) async {
  const key = '$testKey.compact_roles';
  final preferences = SharedPreferencesAsync();
  final catalog = Question.decode(
    await rootBundle.loadString('assets/questions.json'),
  );
  final beauty = catalog.firstWhere((q) => categoryForQuestion(q) == 'beauty');
  final travel = catalog.firstWhere((q) => categoryForQuestion(q) == 'travel');
  var data = LearningData().withInterests(
    interestCategories.map((c) => c.id).toList(),
  );
  for (var i = 0; i < 35; i++) {
    data = data.rate(i.isEven ? beauty.id : travel.id, true, DateTime.now());
  }
  final store = LocalProgressStore(storageKey: key);
  await store.save(data);
  try {
    await tester.pumpWidget(
      PhraseFlowApp(store: store, loadCatalog: () async => catalog),
    );
    await tester.pumpAndSettle();
    expect(find.text('Lv. 5'), findsOneWidget);
    expect(find.text('役職：会話の見習い'), findsOneWidget);
    expect(find.text('次の役職「？？？」は Lv. 10'), findsOneWidget);
    for (final category in interestCategories) {
      expect(
        find.byKey(ValueKey('category-graph-${category.id}')),
        findsOneWidget,
      );
    }
    await tapText(tester, '役職：会話の見習い');
    expect(find.text('冒険者の役職'), findsOneWidget);
    for (final role in adventurerRoles) {
      expect(
        find.text(role.title),
        role.minLevel <= 5 ? findsOneWidget : findsNothing,
      );
    }
    await tapText(tester, '閉じる');
    await tapText(tester, '金融/マネー');
    expect(find.text('金融/マネー・レベル1 コツコツ見習い'), findsOneWidget);
    await tapText(tester, 'レベル1 コツコツ見習いの学習へ');
    expect(find.textContaining('レベル1 コツコツ見習い'), findsOneWidget);
    expect(GrowthProgress(await store.load()).xp, 350);
    expect(tester.takeException(), isNull);
    debugPrint(
      '[native] all 17 category bars, hidden future roles, cross-category Lv.5 and selected tree verified',
    );
  } finally {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await preferences.remove(key);
  }
}

Future<void> waitForForeground(WidgetTester tester) async {
  if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
    debugPrint('[native] waiting for app foreground');
    final timer = Stopwatch()..start();
    while (WidgetsBinding.instance.lifecycleState !=
            AppLifecycleState.resumed &&
        timer.elapsed < const Duration(seconds: 60)) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }
  expect(WidgetsBinding.instance.lifecycleState, AppLifecycleState.resumed);
}
