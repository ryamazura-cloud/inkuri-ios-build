import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phrase_flow/domain.dart';
import 'package:phrase_flow/main.dart';
import 'package:phrase_flow/monetization.dart';
import 'package:phrase_flow/practice_allowance.dart';
import 'package:phrase_flow/quests.dart';
import 'widget_test.dart' show MemoryStore, q, tapText;

void main() {
  for (final scenario in [
    (name: 'free first', used: 0, tickets: 2, unlimited: false, fail: false),
    (name: 'extra ticket', used: 3, tickets: 1, unlimited: false, fail: false),
    (name: 'exhausted', used: 3, tickets: 0, unlimited: false, fail: false),
    (name: 'unlimited', used: 3, tickets: 0, unlimited: true, fail: false),
    (name: 'save failure', used: 0, tickets: 1, unlimited: false, fail: true),
  ]) {
    testWidgets('review allowance: ${scenario.name}', (tester) async {
      final now = DateTime.now();
      final initial = LearningData()
          .rate(q.id, false, now)
          .withAllowance(
            PracticeAllowance(
              practiceDay:
                  '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
              usedSets: scenario.used,
              tickets: scenario.tickets,
            ),
          );
      final store = MemoryStore()..raw = initial.encode();
      await tester.pumpWidget(
        PhraseFlowApp(
          store: store,
          monetization: Monetization()..unlimited = scenario.unlimited,
          loadCatalog: () async => [q],
        ),
      );
      await tester.pumpAndSettle();
      store.fail = scenario.fail;
      await tapText(tester, '復習（1問）');
      final allowed =
          !scenario.fail &&
          (scenario.unlimited || scenario.used < 3 || scenario.tickets > 0);
      expect(
        find.byType(TrainingPage),
        allowed ? findsOneWidget : findsNothing,
      );
      if (allowed) {
        expect(find.text('0 / 5 回 できた'), findsOneWidget);
      }
      final saved = (await store.load()).allowance;
      expect(
        saved.usedSets,
        allowed && !scenario.unlimited && scenario.used < 3
            ? scenario.used + 1
            : scenario.used,
      );
      expect(
        saved.tickets,
        allowed && !scenario.unlimited && scenario.used == 3
            ? scenario.tickets - 1
            : scenario.tickets,
      );
      expect((await store.load()).entries[q.id]!.attempts, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }

  testWidgets('review displays saved progress and clears only at custom goal', (
    tester,
  ) async {
    final now = DateTime.now();
    final store = MemoryStore()
      ..raw = LearningData()
          .withReviewGoal(2)
          .rate(q.id, false, now)
          .rate(q.id, true, now)
          .encode();
    await tester.pumpWidget(
      PhraseFlowApp(
        store: store,
        monetization: Monetization(),
        loadCatalog: () async => [q],
      ),
    );
    await tester.pumpAndSettle();
    for (final success in [false, true]) {
      await tapText(tester, '復習（1問）');
      expect(find.text('1 / 2 回 できた'), findsOneWidget);
      expect(find.textContaining('TOPのiアイコン'), findsOneWidget);
      await tapText(tester, '答えを表示');
      await tapText(tester, success ? 'できた' : 'まだ難しい');
      final entry = (await store.load()).entries[q.id]!;
      expect(entry.reviewSuccesses, success ? 2 : 1);
      expect(entry.needsReview, !success);
      await tapText(tester, 'ホームに戻る');
    }
    expect(find.text('復習（0問）'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  test(
    'ten-question quest grants EXP without tickets, preserving old claims',
    () {
      final now = DateTime(2026, 11, 18);
      var data = LearningData().withAllowance(
        const PracticeAllowance(tickets: 1),
      );
      for (var i = 0; i < 10; i++) {
        data = data.rate(q.id, false, now);
      }
      final quest = learningQuests(
        data,
        now,
        ticketsEnabled: true,
      ).singleWhere((q) => q.id == 'practice-ten');
      final saved = claimQuestReward(
        data,
        quest.key,
        now,
        ticketsEnabled: true,
      );
      expect(saved.earnedXp - data.earnedXp, 30);
      expect(saved.allowance.tickets, 1);
      final restored = LearningData.decode(saved.encode());
      expect(restored.questClaims, contains(quest.key));
      expect(restored.allowance.tickets, 1);
    },
  );
}
