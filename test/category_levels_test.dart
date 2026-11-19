import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phrase_flow/category_levels.dart';
import 'package:phrase_flow/domain.dart';
import 'package:phrase_flow/interests.dart';
import 'package:phrase_flow/main.dart';
import 'widget_test.dart' show MemoryStore, tapText;

void main() {
  final catalog = Question.decode(
    File('assets/questions.json').readAsStringSync(),
  );
  final now = DateTime(2026, 11, 3);
  testWidgets(
    'all category bars preserve current stage and completion labels',
    (t) async {
      var data = LearningData()
          .withInterests(['beauty', 'travel', 'business'])
          .finishChallenge('beauty', 'stage-1', 4, 5, now);
      for (var i = 1; i <= 5; i++) {
        data = data.finishChallenge('business', 'stage-$i', 4, 5, now);
        if (i < 5) data = data.finishChallenge('travel', 'stage-$i', 4, 5, now);
      }
      var selected = '';
      var editOpened = false;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CategoryLevels(
                catalog: catalog,
                data: data,
                onOpen: (id) => selected = id,
                onEdit: () => editOpened = true,
              ),
            ),
          ),
        ),
      );
      expect(find.byTooltip('美容/コスメ レベル2 彩りの使い手'), findsOneWidget);
      expect(find.byTooltip('旅行/観光 レベル5 七つの海の冒険家'), findsOneWidget);
      expect(find.byTooltip('ビジネス/経済 レベル5 未来の開拓者 ・全レベル達成'), findsOneWidget);
      expect(find.text('ペット'), findsNothing);
      expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);
      await t.tap(find.text('カテゴリー変更'));
      expect(editOpened, isTrue);
      await tapText(t, '旅行/観光');
      expect(selected, 'travel');
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('all 17 bars fit 320px double text and open selected category', (
    t,
  ) async {
    t.view.physicalSize = const Size(320, 568);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      t.view.resetPhysicalSize();
      t.view.resetDevicePixelRatio();
      t.platformDispatcher.clearTextScaleFactorTestValue();
    });
    var selected = '';
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: CategoryLevels(
                catalog: catalog,
                data: LearningData().withInterests(
                  interestCategories.map((c) => c.id).toList(),
                ),
                onOpen: (id) => selected = id,
                onEdit: () {},
              ),
            ),
          ),
        ),
      ),
    );
    for (final category in interestCategories) {
      expect(
        find.byKey(ValueKey('category-graph-${category.id}')),
        findsOneWidget,
      );
    }
    await tapText(t, '金融/マネー');
    expect(selected, 'money');
    expect(t.takeException(), isNull);
  });
  testWidgets('home graph opens category current stage below common profile', (
    t,
  ) async {
    final data = LearningData()
        .withInterests(['beauty', 'travel'])
        .finishChallenge('travel', 'stage-1', 4, 5, now);
    final store = MemoryStore()..raw = data.encode();
    await t.pumpWidget(
      PhraseFlowApp(store: store, loadCatalog: () async => catalog),
    );
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.text('カテゴリーの成長'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await t.pumpAndSettle();
    expect(
      t.getTopLeft(find.text('Lv. 1')).dy,
      lessThan(t.getTopLeft(find.text('カテゴリーの成長')).dy),
    );
    await tapText(t, '旅行/観光');
    expect(find.text('旅行/観光・レベル2 街角の探検家'), findsOneWidget);
    expect(
      LearningData.decode(store.raw!).challengePasses['travel|stage-1'],
      isNotNull,
    );
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'compact graph uses two columns at normal size and one for large text',
    (t) async {
      t.view.physicalSize = const Size(360, 760);
      t.view.devicePixelRatio = 1;
      addTearDown(() {
        t.view.resetPhysicalSize();
        t.view.resetDevicePixelRatio();
        t.platformDispatcher.clearTextScaleFactorTestValue();
      });
      Future<void> render() async {
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: CategoryLevels(
                    catalog: catalog,
                    data: LearningData().withInterests(['beauty', 'travel']),
                    onOpen: (_) {},
                    onEdit: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
      }

      await render();
      expect(
        t.getTopLeft(find.text('美容/コスメ')).dy,
        t.getTopLeft(find.text('旅行/観光')).dy,
      );
      t.platformDispatcher.textScaleFactorTestValue = 2;
      await render();
      expect(
        t.getTopLeft(find.text('美容/コスメ')).dy,
        lessThan(t.getTopLeft(find.text('旅行/観光')).dy),
      );
      expect(t.takeException(), isNull);
    },
  );
}
