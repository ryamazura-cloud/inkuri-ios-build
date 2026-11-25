import 'dart:io';
import 'package:phrase_flow/monetization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phrase_flow/grammar.dart';
import 'package:phrase_flow/main.dart';
import 'package:phrase_flow/growth.dart';
import 'package:phrase_flow/reminders.dart';
import 'package:phrase_flow/reminder_settings_page.dart';
import 'reminders_test.dart' show MemoryReminderStore, FakeReminderBackend;
import 'widget_test.dart' show MemoryStore, q;

Future<void> coachTap(WidgetTester tester, String label) async {
  await tester.tap(find.bySemanticsLabel('$labelをタップ'));
  await tester.pumpAndSettle();
}

void main() {
  final grammar = GrammarCatalog.decode(
    File('assets/grammar.json').readAsStringSync(),
  );
  for (final configuration in [
    (success: true, width: 411.0, height: 790.0, scale: 1.0, compact: false),
    (success: false, width: 320.0, height: 568.0, scale: 1.0, compact: true),
    (success: false, width: 320.0, height: 568.0, scale: 2.0, compact: true),
  ]) {
    final success = configuration.success;
    testWidgets(
      'first-run ${configuration.width}px scale ${configuration.scale} saves one ${success ? 'success' : 'review'} then explains growth and history before reminders',
      (tester) async {
        tester.view.physicalSize = Size(
          configuration.width,
          configuration.height,
        );
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue =
            configuration.scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final semantics = tester.ensureSemantics();
        try {
          final store = MemoryStore();
          final reminderStore = MemoryReminderStore();
          final backend = FakeReminderBackend();
          await tester.pumpWidget(
            PhraseFlowApp(
              store: store,
              monetization: Monetization(),
              loadCatalog: () async => [q],
              loadGrammar: () async => grammar,
              claimFirstRun: () async => true,
              reminders: ReminderManager(
                store: reminderStore,
                backend: backend,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.textContaining('Thank you'), findsOneWidget);
          expect(find.text('次へ'), findsNothing);
          expect(find.byType(ReminderSettingsPage), findsNothing);
          await tester.tap(find.text('操作を試す'));
          await tester.pumpAndSettle();
          expect(find.text('興味のあるテーマで、冒険しよう'), findsOneWidget);
          if (configuration.compact) {
            final dropdown = find.byType(DropdownButtonFormField<TrainingMode>);
            expect(dropdown, findsOneWidget);
            expect(
              tester
                  .getRect(find.bySemanticsLabel('学習モードの切り替えをタップ'))
                  .contains(tester.getCenter(dropdown)),
              isTrue,
            );
            for (var index = 0; index < 2; index++) {
              final next = find.widgetWithText(FilledButton, '次へ');
              await tester.tap(next);
              await tester.pumpAndSettle();
            }
          } else {
            expect(find.text('現在のモード：冒険モード'), findsOneWidget);
            for (final mode in ['冒険モード', '修行モード']) {
              final card = find.widgetWithText(OutlinedButton, mode);
              final spot = find.bySemanticsLabel(mode + 'をタップ');
              expect(
                tester.getRect(spot).contains(tester.getCenter(card)),
                isTrue,
              );
              await coachTap(tester, mode);
            }
            expect(find.text('現在のモード：修行モード'), findsOneWidget);
          }
          await coachTap(tester, 'be動詞');
          await coachTap(tester, '10問で修行する');
          expect(find.text('1 / 10'), findsOneWidget);
          await coachTap(tester, '答えを表示');
          expect(find.textContaining('倍率ボタンで速度を選べます'), findsOneWidget);
          await tester.tap(find.text('自己評価へ'));
          await tester.pumpAndSettle();
          await coachTap(tester, success ? 'できた' : 'まだ難しい');
          expect(find.text('2 / 10'), findsOneWidget);
          await coachTap(tester, '学習を終了');
          expect(find.text('学習を終了しますか？'), findsOneWidget);
          expect(find.text('操作ガイド：今回は「終了する」を選びます'), findsOneWidget);
          expect(find.widgetWithText(FilledButton, '終了する'), findsOneWidget);
          if (success) {
            await tester.tap(find.text('続ける'));
            await tester.pumpAndSettle();
            expect(find.text('2 / 10'), findsOneWidget);
            await coachTap(tester, '学習を終了');
            expect(find.text('操作ガイド：今回は「終了する」を選びます'), findsOneWidget);
          }
          await tester.tap(find.text('終了する'));
          await tester.pumpAndSettle();
          expect(find.text('2問目は、途中で終えてみましょう'), findsNothing);
          expect(find.text('1問の練習も、成長につながります'), findsOneWidget);
          final saved = await store.load();
          expect(
            saved.entries.values.fold<int>(0, (sum, e) => sum + e.attempts),
            1,
          );
          expect(saved.entries['grammar-be-01']!.needsReview, !success);
          expect(GrowthProgress(saved).xp, success ? 10 : 5);
          expect(saved.interests, isEmpty);
          expect(saved.allowance.tickets, 0);
          await tester.tap(find.text('次へ'));
          await tester.pumpAndSettle();
          expect(find.text('復習は、ここから'), findsOneWidget);
          await tester.tap(find.text('確認しました'));
          await tester.pumpAndSettle();
          await coachTap(tester, '学習記録');
          expect(find.text('学習の積み重ねが見える画面'), findsOneWidget);
          await tester.tap(find.text('次へ'));
          await tester.pumpAndSettle();
          expect(find.text('チケットと有料プランは、ここから'), findsOneWidget);
          expect(find.bySemanticsLabel('チケット・有料プランをタップ'), findsOneWidget);
          expect(find.textContaining('復習もチケットを使います'), findsOneWidget);
          await tester.tap(find.text('次へ'));
          await tester.pumpAndSettle();
          expect(find.text('いつでも「使い方」で確認できます'), findsOneWidget);
          final guideSpot = find.bySemanticsLabel('使い方をタップ');
          final guideButton = find.byWidgetPredicate(
            (widget) =>
                widget is IconButton && widget.tooltip == '使い方' ||
                widget is TextButton &&
                    widget.child is Text &&
                    (widget.child as Text).data == '使い方',
          );
          expect(guideSpot, findsOneWidget);
          expect(
            tester.getRect(guideSpot).contains(tester.getCenter(guideButton)),
            isTrue,
          );
          expect(find.byType(ReminderSettingsPage), findsNothing);
          await tester.tap(find.text('わかりました'));
          await tester.pumpAndSettle();
          expect(find.byType(ReminderSettingsPage), findsOneWidget);
          expect(backend.requests, 0);
          expect(reminderStore.value.enabled, isFalse);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        } finally {
          semantics.dispose();
        }
      },
    );
  }
  testWidgets(
    'skipping the coach does not invent ratings and still offers reminders',
    (tester) async {
      final store = MemoryStore();
      await tester.pumpWidget(
        PhraseFlowApp(
          store: store,
          loadCatalog: () async => [q],
          loadGrammar: () async => grammar,
          claimFirstRun: () async => true,
          reminders: ReminderManager(
            store: MemoryReminderStore(),
            backend: FakeReminderBackend(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('操作を試す'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('スキップ'));
      await tester.pumpAndSettle();
      expect((await store.load()).entries, isEmpty);
      await tester.tap(find.text('わかりました'));
      await tester.pumpAndSettle();
      expect(find.byType(ReminderSettingsPage), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
