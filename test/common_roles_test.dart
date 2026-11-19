import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phrase_flow/domain.dart';
import 'package:phrase_flow/growth.dart';
import 'package:phrase_flow/growth_widgets.dart';
import 'widget_test.dart' show tapText;

LearningData atXp(int xp) => LearningData({
  'q': ProgressEntry(
    attempts: xp ~/ 5,
    successes: 0,
    needsReview: true,
    lastStudied: DateTime(2026, 11, 3),
  ),
});
void main() {
  testWidgets('growth history keeps dates and hides the next title', (t) async {
    final now = DateTime(2026, 11, 8);
    final legacy = atXp(GrowthProgress.threshold(5));
    expect(LearningData.decode(legacy.encode()).levelUpDays, isEmpty);
    final restored = LearningData.decode(
      legacy.recordLevelUps(3, 5, now).withInterests(['travel']).encode(),
    );
    expect(restored.levelUpDays, {4: '2026-11-08', 5: '2026-11-08'});
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GrowthCard(data: restored, onSkills: () {}),
        ),
      ),
    );
    await t.tap(find.byTooltip('成長履歴'));
    await t.pumpAndSettle();
    expect(find.text('Lv. 6まであと 310 EXP'), findsOneWidget);
    expect(find.text('次の称号：？？？（Lv. 10）'), findsOneWidget);
    expect(find.text('フレーズの使い手'), findsNothing);
    expect(find.text('会話の見習い'), findsOneWidget);
    expect(find.text('Lv. 5 に到達'), findsOneWidget);
    expect(find.text('2026-11-08'), findsNWidgets(2));
    expect(t.takeException(), isNull);
  });

  test('level 50 continues toward 60 and final role persists above 100', () {
    final formerFinal = GrowthProgress(atXp(GrowthProgress.threshold(50)));
    expect(formerFinal.title, '世界をつなぐ語り部');
    expect(formerFinal.nextRole!.minLevel, 60);
    expect(formerFinal.titleFor(formerFinal.nextRole!), '？？？');
    final finalRole = GrowthProgress(atXp(GrowthProgress.threshold(100)));
    expect(finalRole.title, '伝説のことばの創造主');
    expect(finalRole.nextRole, isNull);
    final continuing = GrowthProgress(
      LearningData.decode(atXp(GrowthProgress.threshold(101)).encode()),
    );
    expect(continuing.level, 101);
    expect(continuing.title, finalRole.title);
  });
  test('every common role promotes exactly at its level threshold', () {
    for (var i = 0; i < adventurerRoles.length; i++) {
      final role = adventurerRoles[i],
          xp = GrowthProgress.threshold(role.minLevel);
      final growth = GrowthProgress(atXp(xp));
      expect(growth.title, role.title);
      expect(growth.level, role.minLevel);
      expect(
        growth.nextRole,
        i + 1 < adventurerRoles.length ? adventurerRoles[i + 1] : null,
      );
      if (i > 0) {
        expect(
          GrowthProgress(atXp(xp - 5)).title,
          adventurerRoles[i - 1].title,
        );
      }
    }
  });
  test(
    'cross-category EXP and roles survive removing interests and reloading',
    () {
      var data = LearningData().withInterests(['beauty', 'travel']);
      final now = DateTime(2026, 11, 3);
      for (var i = 0; i < 60; i++) {
        data = data.rate('beauty-q', true, now);
      }
      for (var i = 0; i < 45; i++) {
        data = data.rate('travel-q', true, now);
      }
      expect(GrowthProgress(data).xp, 1050);
      expect(GrowthProgress(data).level, 5);
      final restored = LearningData.decode(
        data.withInterests(['pets']).encode(),
      );
      expect(GrowthProgress(restored).title, '会話の見習い');
      expect(GrowthProgress(restored).xp, 1050);
    },
  );
  testWidgets('profile shows common role, next promotion and all roles', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: GrowthCard(data: atXp(1050), onSkills: () {}),
          ),
        ),
      ),
    );
    expect(find.text('Lv. 5'), findsOneWidget);
    expect(find.text('役職：会話の見習い'), findsOneWidget);
    expect(find.text('次の役職「？？？」は Lv. 10'), findsOneWidget);
    await tapText(t, '役職：会話の見習い');
    expect(find.text('冒険者の役職'), findsOneWidget);
    expect(find.text('？？？'), findsNWidgets(11));
    for (final role in adventurerRoles) {
      expect(
        find.text(role.title),
        role.minLevel <= 5 ? findsOneWidget : findsNothing,
      );
    }
    expect(t.takeException(), isNull);
    await tapText(t, '閉じる');
    t.view.physicalSize = const Size(320, 568);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      t.view.resetPhysicalSize();
      t.view.resetDevicePixelRatio();
      t.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: GrowthCard(
              data: atXp(GrowthProgress.threshold(100)),
              onSkills: () {},
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('役職：伝説のことばの創造主'), findsOneWidget);
    expect(find.text('最高役職に到達！ 冒険はまだ続きます。'), findsOneWidget);
    expect(t.takeException(), isNull);
    await tapText(t, '役職：伝説のことばの創造主');
    await t.ensureVisible(find.text('伝説のことばの創造主'));
    await t.pumpAndSettle();
    expect(find.text('Lv. 100から ・現在の役職'), findsOneWidget);
    expect(find.text('？？？'), findsNothing);
    expect(t.takeException(), isNull);
    await tapText(t, '閉じる');
  });
}
