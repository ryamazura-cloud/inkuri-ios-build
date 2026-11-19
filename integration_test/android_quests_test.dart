import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:phrase_flow/domain.dart';
import 'package:phrase_flow/grammar.dart';
import 'package:phrase_flow/growth.dart';
import 'package:phrase_flow/main.dart';
import 'package:phrase_flow/quests.dart';
import 'package:phrase_flow/reminders.dart';
import 'package:phrase_flow/store.dart';
import 'android_smoke_test.dart' show tapText;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android quick review and quest rewards use isolated saved records',
    (t) async {
      final prefs = SharedPreferencesAsync();
      const key = 'phrase_flow.progress.android_quests_test0150';
      final protected = [
        LocalProgressStore.key,
        LocalTrainingModeStore.key,
        LocalReminderStore.key,
      ];
      final before = {
        for (final key in protected) key: await prefs.getString(key),
      };
      final catalog = Question.decode(
        await rootBundle.loadString('assets/questions.json'),
      );
      final grammar = GrammarCatalog.decode(
        await rootBundle.loadString('assets/grammar.json'),
      );
      final store = LocalProgressStore(storageKey: key);
      await store.save(
        LearningData()
            .rate(catalog.first.id, false, DateTime.now())
            .rate(grammar.questions.first.id, false, DateTime.now()),
      );
      Future<void> open() async {
        await t.pumpWidget(
          PhraseFlowApp(
            store: store,
            loadCatalog: () async => catalog,
            loadGrammar: () async => grammar,
          ),
        );
        await t.pumpAndSettle();
      }

      Future<void> reward(String title) async {
        final heading = find.text(title);
        await t.scrollUntilVisible(
          heading,
          160,
          scrollable: find.byType(Scrollable).first,
        );
        final card = find
            .ancestor(of: heading, matching: find.byType(Card))
            .first;
        final button = find.descendant(
          of: card,
          matching: find.text('報酬を受け取る'),
        );
        await t.ensureVisible(button);
        await t.pumpAndSettle();
        await t.tap(button);
        await t.pumpAndSettle();
        expect(find.text('クエスト達成！'), findsOneWidget);
        await tapText(t, '冒険を続ける');
      }

      try {
        await prefs.setString(
          key,
          jsonEncode({
            'schemaVersion': 1,
            'entries': {
              catalog.first.id: {
                'attempts': 35,
                'successes': 35,
                'needsReview': false,
                'lastStudied': DateTime.now().toIso8601String(),
              },
            },
          }),
        );
        await open();
        expect(find.text('Lv. 5'), findsOneWidget);
        expect(find.text('累計 350 EXP'), findsOneWidget);
        expect(find.text('あと 450 EXPで Lv. 6'), findsOneWidget);
        await t.pumpWidget(const SizedBox());
        await t.pumpAndSettle();
        await store.save(
          LearningData()
              .rate(catalog.first.id, false, DateTime.now())
              .rate(grammar.questions.first.id, false, DateTime.now()),
        );
        await open();
        await tapText(t, '修行モード');
        expect(find.byType(TextField), findsNothing);
        await tapText(t, '使い方');
        expect(find.text('1 / 6'), findsOneWidget);
        await t.tap(find.byTooltip('使い方を閉じる'));
        await t.pumpAndSettle();
        await tapText(t, '復習（2問）');
        final session = t
            .widget<TrainingPage>(find.byType(TrainingPage))
            .questions;
        expect(session.map((q) => q.id).toSet(), {
          catalog.first.id,
          grammar.questions.first.id,
        });
        await tapText(t, '答えを表示');
        await tapText(t, '音声を再生', settle: false);
        expect(find.text('音声を停止'), findsOneWidget);
        final playback = Stopwatch()..start();
        while (find.text('音声を停止').evaluate().isNotEmpty &&
            playback.elapsed < const Duration(seconds: 15)) {
          await t.pump(const Duration(milliseconds: 200));
        }
        expect(find.text('音声を停止'), findsNothing);
        expect(find.textContaining('音声を再生できませんでした'), findsNothing);
        expect(playback.elapsedMilliseconds, inExclusiveRange(300, 15000));
        await tapText(t, 'まだ難しい');
        await tapText(t, '答えを表示');
        await tapText(t, 'できた');
        await tapText(t, 'ホームに戻る');
        await tapText(t, 'クエスト');
        await reward('はじめの一歩');
        await reward('苦手を味方に');
        final saved = await store.load();
        expect(saved.questClaims.length, 2);
        expect(GrowthProgress(saved).xp, 55);
        expect(saved.days.values.fold(0, (sum, day) => sum + day.questions), 4);
        expect(saved.reviewDays.values.fold(0, (sum, count) => sum + count), 2);
        expect(
          learningQuests(saved, DateTime.now()).where((q) => q.claimed).length,
          2,
        );
        await t.pumpWidget(const SizedBox());
        await t.pumpAndSettle();
        await open();
        expect(find.text('復習（2問）'), findsOneWidget);
        expect(GrowthProgress(await store.load()).xp, 55);
        debugPrint(
          '[quests native] mixed review, reward EXP, single claims and reload passed',
        );
      } finally {
        await t.pumpWidget(const SizedBox());
        await t.pumpAndSettle();
        await prefs.remove(key);
        for (final key in protected) {
          expect(await prefs.getString(key), before[key]);
        }
      }
    },
  );
}
