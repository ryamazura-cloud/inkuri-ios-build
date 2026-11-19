import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:phrase_flow/domain.dart';
import 'package:phrase_flow/grammar.dart';
import 'package:phrase_flow/grammar_widgets.dart';
import 'package:phrase_flow/growth.dart';
import 'package:phrase_flow/main.dart';
import 'package:phrase_flow/reminders.dart';
import 'package:phrase_flow/store.dart';
import 'android_smoke_test.dart' show tapText, waitForForeground;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android grammar: ten questions, native audio, review and isolated persistence',
    (tester) async {
      const progressKey = 'phrase_flow.progress.android_grammar_test0140';
      const modeKey = 'inkuri.training_mode.android_grammar_test0140';
      final preferences = SharedPreferencesAsync();
      final protectedKeys = [
        LocalProgressStore.key,
        LocalTrainingModeStore.key,
        LocalReminderStore.key,
      ];
      final before = {
        for (final key in protectedKeys) key: await preferences.getString(key),
      };
      final grammar = GrammarCatalog.decode(
        await rootBundle.loadString('assets/grammar.json'),
      );
      final adventure = Question.decode(
        await rootBundle.loadString('assets/questions.json'),
      );
      final store = LocalProgressStore(storageKey: progressKey);
      final modes = LocalTrainingModeStore(storageKey: modeKey);
      await preferences.remove(progressKey);
      await preferences.remove(modeKey);
      Future<void> open() async {
        await tester.pumpWidget(
          PhraseFlowApp(
            store: store,
            loadCatalog: () async => adventure,
            loadGrammar: () async => grammar,
            modeStore: modes,
          ),
        );
        await tester.pumpAndSettle();
      }

      Future<void> play() async {
        await waitForForeground(tester);
        await tapText(tester, '音声を再生', settle: false);
        expect(find.text('音声を停止'), findsOneWidget);
        final timer = Stopwatch()..start();
        while (find.text('音声を停止').evaluate().isNotEmpty &&
            timer.elapsed < const Duration(seconds: 15)) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        expect(find.text('音声を停止'), findsNothing);
        expect(find.textContaining('音声を再生できませんでした'), findsNothing);
        expect(timer.elapsedMilliseconds, inExclusiveRange(300, 12000));
        debugPrint('[grammar native] bundled playback completed');
      }

      Future<void> selectGroup(String group) async {
        final selected = tester
            .state<FormFieldState<String>>(
              find.byType(DropdownButtonFormField<String>),
            )
            .value!;
        await tapText(tester, selected);
        await tapText(tester, group);
      }

      try {
        await open();
        await tapText(tester, '修行モード');
        await selectGroup('中学2年生文法');
        expect(find.text('受け身'), findsOneWidget);
        expect(find.text('be動詞'), findsNothing);
        await selectGroup('中学1年生文法');
        await tapText(tester, 'be動詞');
        expect(find.text('文法のひとくちメモ'), findsOneWidget);
        await tapText(tester, '10問で修行する');
        final session = tester
            .widget<TrainingPage>(find.byType(TrainingPage))
            .questions;
        expect(session.length, 10);
        expect(session.map((q) => q.id).toSet().length, 10);
        expect(session.every((q) => q.grammarUnit == 'be'), isTrue);
        for (var i = 0; i < session.length; i++) {
          await tapText(tester, '答えを表示');
          if (i == 0) await play();
          await tapText(tester, i == 0 ? 'まだ難しい' : 'できた');
        }
        await tapText(tester, '成果を共有');
        expect(find.text('今回の成果を共有'), findsOneWidget);
        expect(find.textContaining('10問練習しました'), findsOneWidget);
        await tapText(tester, '閉じる');
        await tapText(tester, 'ホームに戻る');
        var saved = await store.load();
        expect(saved.entries.length, 10);
        expect(GrowthProgress(saved).xp, 95);
        expect(saved.interests, isEmpty);
        expect(saved.challengePasses, isEmpty);
        expect(await modes.load(), TrainingMode.grammar);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await open();
        expect(find.text('文法を思い出す、はじめの修行。'), findsOneWidget);
        await tapText(tester, 'be動詞');
        await tapText(tester, 'この文法の苦手問題を復習（1問）');
        expect(
          tester
              .widget<TrainingPage>(find.byType(TrainingPage))
              .questions
              .single
              .id,
          session.first.id,
        );
        await tapText(tester, '答えを表示');
        await tapText(tester, 'できた');
        await tapText(tester, 'ホームに戻る');
        final reviewed = (await store.load()).entries[session.first.id]!;
        expect(reviewed.needsReview, isTrue);
        expect(reviewed.reviewSuccesses, 1);
        debugPrint(
          '[grammar native] ten-question persistence and review passed',
        );
        for (final label in ['一般動詞の過去', '関係代名詞：目的格']) {
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          await open();
          if (label != '一般動詞の過去') {
            await selectGroup('中学3年生文法');
          }
          final title = find.descendant(
            of: find.byType(GrammarPanel),
            matching: find.byWidgetPredicate(
              (widget) => widget is Text && widget.data == label,
            ),
          );
          await tester.ensureVisible(title);
          await tester.pumpAndSettle();
          await tester.tap(title);
          await tester.pumpAndSettle();
          await tapText(tester, '10問で修行する');
          await tapText(tester, '答えを表示');
          await play();
          await tapText(tester, 'まだ難しい');
          await tester.tap(find.byTooltip('学習を終了'));
          await tester.pumpAndSettle();
          await tapText(tester, '終了する');
        }
        expect(find.text('復習（3問）'), findsOneWidget);
        await tapText(tester, '冒険モード');
        expect(find.text('スキルツリーを見る'), findsOneWidget);
        saved = await store.load();
        expect(saved.entries.length, 12);
        expect(GrowthProgress(saved).xp, 115);
        expect(
          saved.days.values.fold(0, (sum, day) => sum + day.questions),
          13,
        );
        expect(
          saved.days.values.fold(0, (sum, day) => sum + day.milliseconds),
          greaterThan(0),
        );
        for (final key in protectedKeys) {
          expect(await preferences.getString(key), before[key]);
        }
        debugPrint(
          '[grammar native] 3 native voices, mixed review count, shared EXP/time, protected data passed',
        );
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await preferences.remove(progressKey);
        await preferences.remove(modeKey);
        for (final key in protectedKeys) {
          expect(await preferences.getString(key), before[key]);
        }
      }
    },
  );
}
