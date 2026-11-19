import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phrase_flow/domain.dart';
import 'package:phrase_flow/grammar.dart';
import 'package:phrase_flow/main.dart';
import 'package:phrase_flow/monetization.dart';
import 'package:phrase_flow/practice_allowance.dart';

import 'grammar_test.dart' show MemoryModeStore;
import 'widget_test.dart' show MemoryStore, q, tapText;

class _Preview extends Monetization {
  int adViews = 0;

  @override
  Future<bool> watchReward() async {
    adViews++;
    return true;
  }

  void unlock() {
    unlimited = true;
    notifyListeners();
  }
}

void main() {
  test(
    'daily sets, one ad reward and carried tickets persist independently',
    () {
      final today = DateTime(2026, 11, 4, 23);
      final tomorrow = DateTime(2026, 11, 5);
      var allowance = const PracticeAllowance();
      expect(allowance.canWatchAd(today), isFalse);
      for (var set = 0; set < 3; set++) {
        allowance = allowance.startSet(today)!;
      }
      expect(allowance.startSet(today), isNull);
      expect(allowance.canWatchAd(today), isTrue);
      allowance = allowance.grantAdTicket(today);
      expect(allowance.tickets, 1);
      expect(allowance.grantAdTicket(today).tickets, 1);
      allowance = allowance.startSet(today)!;
      expect(allowance.startSet(today), isNull);
      expect(allowance.canWatchAd(today), isFalse);
      allowance = allowance.grantTickets(10);
      final data = LearningData()
          .withAllowance(allowance)
          .rate('example', true, today)
          .withReviewGoal(4);
      final restored = LearningData.decode(data.encode()).allowance;
      expect(restored.remaining(today), 0);
      expect(restored.tickets, 3);
      expect(restored.canWatchAd(today), isFalse);
      expect(restored.remaining(tomorrow), 3);
      expect(restored.startSet(tomorrow)!.tickets, 3);
      expect(
        LearningData.decode(LearningData().encode()).allowance.remaining(today),
        3,
      );
    },
  );

  testWidgets(
    'exhausted grammar practice can resume with a ticket or unlimited',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final grammar = GrammarCatalog.decode(
        File('assets/grammar.json').readAsStringSync(),
      );
      final now = DateTime.now();
      var allowance = const PracticeAllowance();
      for (var set = 0; set < 3; set++) {
        allowance = allowance.startSet(now)!;
      }
      final store = MemoryStore()
        ..raw = LearningData().withAllowance(allowance).encode();
      final monetization = _Preview()..adsReady = true;
      await tester.pumpWidget(
        PhraseFlowApp(
          store: store,
          loadCatalog: () async => [q],
          loadGrammar: () async => grammar,
          modeStore: MemoryModeStore()..value = TrainingMode.grammar,
          monetization: monetization,
        ),
      );
      await tester.pumpAndSettle();
      final planButton = find.byTooltip('無料枠 0/3・追加チケット 0枚・有料プラン');
      expect(planButton, findsOneWidget);
      expect(
        tester.getRect(planButton).left,
        greaterThanOrEqualTo(tester.getRect(find.byTooltip('学習リマインダー')).right),
      );
      await tester.tap(planButton);
      await tester.pumpAndSettle();
      expect(find.text('練習枠と有料プラン'), findsOneWidget);
      expect(find.textContaining('回数無制限・広告なし'), findsOneWidget);
      expect(find.text('広告を見て追加チケットを1枚もらう'), findsNothing);
      await tapText(tester, '閉じる');
      Future<void> start() async {
        await tapText(tester, 'be動詞');
        await tapText(tester, '10問で修行する');
      }

      await start();
      expect(find.byType(TrainingPage), findsNothing);
      expect(monetization.adViews, 0);
      expect(find.text('有料プランを見る'), findsOneWidget);
      await tapText(tester, '有料プランを見る');
      expect(find.text('練習枠と有料プラン'), findsOneWidget);
      await tapText(tester, '閉じる');
      await start();
      await tapText(tester, '広告を見て追加チケットを1枚もらう');
      expect((await store.load()).allowance.tickets, 1);
      expect(find.byTooltip('無料枠 0/3・追加チケット 1枚・有料プラン'), findsOneWidget);
      await start();
      expect(find.byType(TrainingPage), findsOneWidget);
      expect((await store.load()).allowance.tickets, 0);
      await tester.tap(find.byTooltip('学習を終了'));
      await tester.pumpAndSettle();
      await tapText(tester, '終了する');
      await start();
      expect(find.text('今日の通常練習はここまで'), findsOneWidget);
      expect(find.text('広告を見て追加チケットを1枚もらう'), findsNothing);
      await tapText(tester, '閉じる');
      monetization.unlock();
      await tester.pumpAndSettle();
      expect(find.byType(PracticeBanner), findsNothing);
      expect(find.byTooltip('無制限プラン・広告なし'), findsOneWidget);
      await start();
      expect(find.byType(TrainingPage), findsOneWidget);
      expect((await store.load()).allowance.remaining(now), 0);
    },
  );
}
