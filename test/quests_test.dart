import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phrase_flow/activity.dart';
import 'package:phrase_flow/domain.dart';
import 'package:phrase_flow/grammar.dart';
import 'package:phrase_flow/growth.dart';
import 'package:phrase_flow/main.dart';
import 'package:phrase_flow/quests.dart';
import 'package:phrase_flow/quest_widgets.dart';
import 'grammar_test.dart' show selectGrammarMode;
import 'widget_test.dart' show MemoryStore, q, tapText;

void main() {
  final date = DateTime(2026, 11, 4, 12);
  testWidgets(
    'busy reward button cannot double-submit and midnight refresh retains earned EXP',
    (t) async {
      var clock = DateTime(2026, 11, 4, 23, 59, 59);
      var data = LearningData().rate('q', true, clock);
      final gate = Completer<void>();
      var calls = 0;
      await t.pumpWidget(
        MaterialApp(
          home: QuestPage(
            data: () => data,
            now: () => clock,
            onClaim: (key) async {
              calls++;
              await gate.future;
              final before = GrowthProgress(data);
              data = claimQuestReward(data, key, clock);
              return QuestReceipt(10, before, GrowthProgress(data));
            },
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.text('報酬を受け取る'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await t.tap(find.text('報酬を受け取る'));
      await t.pump();
      await t.tap(find.text('報酬を受け取る'));
      await t.pump();
      expect(calls, 1);
      gate.complete();
      await t.pumpAndSettle();
      await tapText(t, '冒険を続ける');
      clock = DateTime(2026, 11, 5);
      await t.pump(const Duration(seconds: 31));
      await t.pumpAndSettle();
      expect(find.text('受け取り済み'), findsNothing);
      expect(GrowthProgress(data).xp, 20);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'long review counts keep neighboring button top and bottom aligned',
    (t) async {
      t.view.physicalSize = const Size(411, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(() {
        t.view.resetPhysicalSize();
        t.view.resetDevicePixelRatio();
      });
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: HomeLearningActions(
                weakCount: 2073,
                claimable: 4,
                onReview: () {},
                onQuests: () {},
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final review = find
          .ancestor(
            of: find.text('復習（2073問）'),
            matching: find.byWidgetPredicate((w) => w is FilledButton),
          )
          .first;
      final quests = find
          .ancestor(
            of: find.text('クエスト'),
            matching: find.byWidgetPredicate((w) => w is OutlinedButton),
          )
          .first;
      expect(t.getRect(review).top, t.getRect(quests).top);
      expect(t.getRect(review).bottom, t.getRect(quests).bottom);
      expect(t.takeException(), isNull);
    },
  );
  test(
    'old progress retains exact base EXP with no invented rewards or reviews',
    () {
      final old = LearningData().rate('q', false, date);
      final raw = jsonDecode(old.encode()) as Map<String, dynamic>;
      expect(raw.containsKey('questClaims'), isFalse);
      expect(raw.containsKey('reviewDays'), isFalse);
      final restored = LearningData.decode(jsonEncode(raw));
      expect(GrowthProgress(restored).xp, 5);
      expect(restored.questClaims, isEmpty);
      expect(restored.reviewDays, isEmpty);
    },
  );
  test(
    'claim is eligible once, persists, and changes no question/time counters',
    () {
      var data = LearningData().rate('q', true, date);
      final key = learningQuests(data, date).first.key;
      data = claimQuestReward(data, key, date);
      expect(GrowthProgress(data).xp, 20);
      expect(data.days[dayKey(date)]!.questions, 1);
      expect(data.days[dayKey(date)]!.milliseconds, 0);
      final restored = LearningData.decode(data.encode());
      expect(GrowthProgress(claimQuestReward(restored, key, date)).xp, 20);
      expect(learningQuests(restored, date).first.claimed, isTrue);
      expect(
        () => claimQuestReward(
          restored,
          learningQuests(restored, date)[1].key,
          date,
        ),
        throwsStateError,
      );
    },
  );
  test('day and week boundaries renew quests without losing earned EXP', () {
    final sunday = DateTime(2027, 1, 3, 23, 59), monday = DateTime(2027, 1, 4);
    var data = LearningData().rate('q', true, sunday);
    final yesterdayKey = learningQuests(data, sunday).first.key;
    data = claimQuestReward(data, yesterdayKey, sunday);
    expect(learningQuests(data, monday).first.value, 0);
    expect(learningQuests(data, monday).first.claimed, isFalse);
    expect(
      learningQuests(
        data,
        sunday,
      ).singleWhere((q) => q.id == 'weekly-three').key,
      '2026-12-28|weekly-three',
    );
    expect(
      learningQuests(
        data,
        monday,
      ).singleWhere((q) => q.id == 'weekly-three').key,
      '2027-01-04|weekly-three',
    );
    expect(
      () => claimQuestReward(data, yesterdayKey, monday),
      throwsStateError,
    );
    data = data.rate('q', false, monday);
    data = claimQuestReward(
      data,
      learningQuests(data, monday).first.key,
      monday,
    );
    expect(GrowthProgress(data).xp, 35);
  });
  test(
    'weekly days require ratings, ignore future records and visits alone',
    () {
      var data = LearningData().visit(date).addTime({dayKey(date): 60000});
      expect(
        learningQuests(
          data,
          date,
        ).singleWhere((q) => q.id == 'weekly-three').value,
        0,
      );
      for (final day in [2, 3, 4, 5]) {
        data = data.rate('q', false, DateTime(2026, 11, day));
      }
      expect(
        learningQuests(
          data,
          date,
        ).singleWhere((q) => q.id == 'weekly-three').value,
        3,
      );
      expect(currentStreak(studiedDays(data, date), date), 3);
      data = claimQuestReward(
        data,
        learningQuests(
          data,
          date,
        ).singleWhere((q) => q.id == 'weekly-three').key,
        date,
      );
      expect(GrowthProgress(data).xp, 100);
    },
  );
  test('daily completion and both weekly milestones grant tickets once', () {
    final friday = DateTime(2026, 11, 6);
    var data = LearningData();
    for (var day = 2; day <= 5; day++) {
      data = data.rate('q', false, DateTime(2026, 11, day));
    }
    LearningQuest quest(String id) => learningQuests(
      data,
      friday,
      ticketsEnabled: true,
    ).singleWhere((quest) => quest.id == id);
    void claim(String id) {
      data = claimQuestReward(
        data,
        quest(id).key,
        friday,
        ticketsEnabled: true,
      );
    }

    expect(quest('weekly-five').complete, isFalse);
    for (var i = 0; i < 29; i++) {
      data = data.rate('q', false, friday);
    }
    expect(quest('practice-thirty').complete, isFalse);
    expect(quest('daily-all').complete, isFalse);
    data = data.rate('q', false, friday);
    expect(quest('daily-all').complete, isTrue);
    expect(quest('weekly-five').complete, isTrue);
    claim('daily-all');
    claim('daily-all');
    expect(data.allowance.tickets, 1);
    claim('weekly-three');
    claim('weekly-five');
    data = LearningData.decode(data.encode());
    claim('weekly-five');
    expect(data.allowance.tickets, 3);
    claim('practice-ten');
    expect(quest('practice-ten').claimed, isTrue);
    expect(quest('practice-ten').awardsTicket, isFalse);
    expect(data.allowance.tickets, 3);
    expect(quest('daily-all').claimed, isTrue);
  });

  test('review counts previously weak questions even when still difficult', () {
    var data = LearningData().rate('q', false, DateTime(2026, 11, 3));
    expect(learningQuests(data, date)[2].value, 0);
    data = data.rate('q', false, date);
    expect(learningQuests(data, date)[2].value, 1);
    data = data.rate('q', true, date).rate('q', true, date);
    expect(data.reviewDays[dayKey(date)], 3);
    expect(data.entries['q']!.needsReview, isTrue);
    expect(data.entries['q']!.reviewSuccesses, 2);
    expect(LearningData.decode(data.encode()).reviewDays, data.reviewDays);
  });
  test(
    'all immutable updates preserve rewards; reset clears rewards and review days',
    () {
      var data = LearningData().rate('q', false, date).rate('q', false, date);
      data = claimQuestReward(data, learningQuests(data, date).first.key, date);
      data = data
          .withInterests(['beauty'])
          .visit(date)
          .addTime({dayKey(date): 1000})
          .finishChallenge('beauty', 'stage-1', 4, 5, date)
          .rate('q', true, date);
      expect(GrowthProgress(data).xp, 30);
      expect(data.questClaims.length, 1);
      expect(data.reviewDays[dayKey(date)], 2);
      expect(
        GrowthProgress(LearningData().withInterests(data.interests)).xp,
        0,
      );
    },
  );
  test('malformed claims and review counts fail closed', () {
    final base = LearningData().rate('q', false, date);
    for (final claims in [
      ['bad'],
      ['2026-11-04|weekly-three'],
      ['2026-11-04|unknown'],
      ['2026-11-04|first-step', '2026-11-04|first-step'],
    ]) {
      final raw = jsonDecode(base.encode()) as Map<String, dynamic>;
      raw['questClaims'] = claims;
      expect(() => LearningData.decode(jsonEncode(raw)), throwsFormatException);
    }
    final raw = jsonDecode(base.encode()) as Map<String, dynamic>;
    raw['reviewDays'] = {'2026-11-04': 2};
    expect(() => LearningData.decode(jsonEncode(raw)), throwsFormatException);
  });
  testWidgets(
    'fixed review shortcut starts mixed weak questions in either mode',
    (t) async {
      final grammar = GrammarCatalog.decode(
        File('assets/grammar.json').readAsStringSync(),
      );
      final data = LearningData()
          .rate(q.id, false, date)
          .rate(grammar.questions.first.id, false, date);
      final store = MemoryStore()..raw = data.encode();
      await t.pumpWidget(
        PhraseFlowApp(
          store: store,
          loadCatalog: () async => [q],
          loadGrammar: () async => grammar,
        ),
      );
      await t.pumpAndSettle();
      await selectGrammarMode(t);
      await tapText(t, '復習（2問）');
      final questions = t
          .widget<TrainingPage>(find.byType(TrainingPage))
          .questions;
      expect(questions.map((q) => q.id).toSet(), {
        q.id,
        grammar.questions.first.id,
      });
      expect(find.text('1 / 2'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'reward save failure is retryable and a received reward cannot be taken twice',
    (t) async {
      final store = MemoryStore()
        ..raw = LearningData().rate(q.id, true, DateTime.now()).encode();
      await t.pumpWidget(
        PhraseFlowApp(store: store, loadCatalog: () async => [q]),
      );
      await t.pumpAndSettle();
      await tapText(t, 'クエスト');
      store.fail = true;
      await tapText(t, '報酬を受け取る');
      expect(find.textContaining('報酬を受け取れませんでした'), findsOneWidget);
      expect(GrowthProgress(LearningData.decode(store.raw!)).xp, 10);
      store.fail = false;
      await tapText(t, '報酬を受け取る');
      expect(find.text('クエスト達成！'), findsOneWidget);
      expect(find.text('+10 EXP'), findsWidgets);
      await tapText(t, '冒険を続ける');
      expect(GrowthProgress(LearningData.decode(store.raw!)).xp, 20);
      expect(find.text('受け取り済み'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
      await t.pumpWidget(
        PhraseFlowApp(store: store, loadCatalog: () async => [q]),
      );
      await t.pumpAndSettle();
      await tapText(t, 'クエスト');
      await t.scrollUntilVisible(
        find.text('受け取り済み'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('受け取り済み'), findsOneWidget);
      expect(GrowthProgress(LearningData.decode(store.raw!)).xp, 20);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    '320px double text retains quick review, quest stamps and reward celebration',
    (t) async {
      t.view.physicalSize = const Size(320, 568);
      t.view.devicePixelRatio = 1;
      t.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() {
        t.view.resetPhysicalSize();
        t.view.resetDevicePixelRatio();
        t.platformDispatcher.clearTextScaleFactorTestValue();
      });
      final store = MemoryStore()
        ..raw = LearningData().rate(q.id, false, DateTime.now()).encode();
      await t.pumpWidget(
        PhraseFlowApp(store: store, loadCatalog: () async => [q]),
      );
      await t.pumpAndSettle();
      expect(find.text('復習（1問）'), findsOneWidget);
      await tapText(t, 'クエスト');
      await tapText(t, '報酬を受け取る');
      expect(find.text('クエスト達成！'), findsOneWidget);
      expect(t.takeException(), isNull);
      await tapText(t, '冒険を続ける');
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
}
