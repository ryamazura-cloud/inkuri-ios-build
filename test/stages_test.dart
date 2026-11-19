import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phrase_flow/domain.dart';
import 'package:phrase_flow/course_levels.dart';
import 'package:phrase_flow/stages.dart';
import 'package:phrase_flow/growth.dart';
import 'package:phrase_flow/growth_widgets.dart';
import 'package:phrase_flow/interests.dart';

void main() {
  final catalog = Question.decode(
    File('assets/questions.json').readAsStringSync(),
  );
  final now = DateTime(2026, 11, 3);
  test('all 85 category portraits are bundled', () async {
    final assets = await AssetManifest.loadFromAssetBundle(rootBundle);
    final expected = {
      for (final category in interestCategories)
        for (final level in courseLevels)
          'assets/characters/${category.id}/${level.key}.jpg',
    };
    expect(expected, hasLength(85));
    expect(assets.listAssets().toSet(), containsAll(expected));
  });
  for (final category in ['travel', 'business']) {
    testWidgets('$category portraits follow the selected unlocked title', (
      t,
    ) async {
      var data = LearningData().withInterests([category]);
      Future<void> openTree() async {
        await t.pumpWidget(
          MaterialApp(
            home: SkillTreePage(
              key: ValueKey(data.challengePasses.length),
              catalog: catalog,
              data: data,
            ),
          ),
        );
        await t.pumpAndSettle();
      }

      await openTree();
      await t.tap(find.byTooltip('レベル5 ？？？'));
      await t.pumpAndSettle();
      expect(find.byType(Image), findsNothing);

      for (final level in courseLevels.take(4)) {
        data = data.finishChallenge(category, level.key, 4, 5, now);
      }
      await openTree();
      for (final level in courseLevels) {
        final categoryLevel = courseLevel(level.key, category: category);
        await t.tap(find.byTooltip(categoryLevel.label));
        await t.pumpAndSettle();
        final portrait = t.widget<Image>(find.byType(Image));
        expect(
          t.getTopRight(find.byType(Image)).dx,
          lessThan(t.getTopLeft(find.byType(ChoiceChip).first).dx),
        );
        expect(
          (portrait.image as AssetImage).assetName,
          'assets/characters/$category/${level.key}.jpg',
        );
        expect(portrait.semanticLabel, '${categoryLevel.name}のキャラクター');
        expect(find.textContaining('RANK'), findsNothing);
        expect(find.textContaining('次のランクまで'), findsNothing);
      }
      expect(t.takeException(), isNull);
    });
  }

  test(
    'all categories split into five balanced, disjoint, easy-to-hard stages',
    () {
      for (final category in interestCategories) {
        final groups = categoryStages(catalog, category.id);
        expect(groups.length, 5);
        final sizes = groups.values.map((q) => q.length).toList();
        expect(
          sizes.reduce((a, b) => a > b ? a : b) -
              sizes.reduce((a, b) => a < b ? a : b),
          lessThanOrEqualTo(1),
        );
        final all = groups.values.expand((q) => q).toList();
        final original = selectInterestQuestions(catalog, category.id);
        expect(all.map((q) => q.id).toSet(), original.map((q) => q.id).toSet());
        expect(all.length, original.length);
        final difficulties = all.map((q) => levels.indexOf(q.level)).toList();
        for (var i = 1; i < difficulties.length; i++) {
          expect(difficulties[i], greaterThanOrEqualTo(difficulties[i - 1]));
        }
      }
      expect(categoryStages(catalog, 'beauty').values.map((q) => q.length), [
        20,
        20,
        20,
        20,
        20,
      ]);
      expect(categoryStages(catalog, 'lifestyle').values.map((q) => q.length), [
        21,
        21,
        21,
        20,
        20,
      ]);
      expect(categoryStages(catalog, 'travel').values.map((q) => q.length), [
        23,
        23,
        23,
        23,
        23,
      ]);
    },
  );
  test('reordering JSON never changes stage membership', () {
    for (final category in interestCategories) {
      final before = categoryStages(catalog, category.id),
          after = categoryStages(catalog.reversed.toList(), category.id);
      for (final stage in courseLevels) {
        expect(
          after[stage.key]!.map((q) => q.id),
          before[stage.key]!.map((q) => q.id),
        );
      }
    }
  });
  test(
    'old challenge passes remain readable without bypassing new five-stage gates',
    () {
      var data = LearningData()
          .withInterests(['beauty'])
          .finishChallenge('beauty', '初級', 4, 5, now);
      final old = data.challengePasses['beauty|初級']!.toJson();
      data = LearningData.decode(
        data.rate(catalog.first.id, true, now).encode(),
      );
      expect(data.challengePasses['beauty|初級']!.toJson(), old);
      final skills = interestSkills(catalog, data);
      expect(skills.length, 5);
      expect(skills.where((s) => s.unlocked).length, 1);
      expect(skills.every((s) => !s.challengePassed), isTrue);
    },
  );
  test('small catalogs have no phantom or duplicated questions', () {
    final one = [catalog.first];
    expect(
      categoryStages(
        one,
        categoryForQuestion(one.first),
      ).values.map((q) => q.length),
      [1, 0, 0, 0, 0],
    );
    expect(stageLabels(catalog).length, 1733);
  });
  testWidgets(
    'search switches the category directly and five chips show one stage only',
    (t) async {
      var selected = '';
      final data = LearningData().withInterests(
        interestCategories.map((c) => c.id).toList(),
      );
      await t.pumpWidget(
        MaterialApp(
          home: SkillTreePage(
            catalog: catalog,
            data: data,
            onCategoryChanged: (id) => selected = id,
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byType(ChoiceChip), findsNWidgets(5));
      expect(find.text('美容/コスメ・レベル1 美容初心者'), findsOneWidget);
      expect(find.text('ペット・レベル1 もふもふ見習い'), findsNothing);
      await t.tap(find.text('美容/コスメ'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), '旅行');
      await t.pumpAndSettle();
      expect(find.text('金融/マネー'), findsNothing);
      await t.tap(find.text('旅行/観光'));
      await t.pumpAndSettle();
      expect(selected, 'travel');
      expect(find.text('旅行/観光・レベル1 旅じたく中'), findsOneWidget);
      await t.tap(find.byTooltip('レベル5 ？？？'));
      await t.pumpAndSettle();
      final button = find.widgetWithText(OutlinedButton, 'レベル5 ？？？の学習へ');
      expect(t.widget<OutlinedButton>(button).onPressed, isNull);
      final top = t.getTopLeft(find.text('旅行/観光')).dy;
      await t.ensureVisible(button);
      await t.pumpAndSettle();
      expect(t.getTopLeft(find.text('旅行/観光')).dy, top);
      expect(find.text('旅行/観光・レベル1 旅じたく中'), findsNothing);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('category context and next available stage survive tree return', (
    t,
  ) async {
    var data = LearningData().withInterests(['beauty', 'travel']);
    data = data.finishChallenge('travel', 'stage-1', 4, 5, now);
    await t.pumpWidget(
      MaterialApp(
        home: SkillTreePage(
          catalog: catalog,
          data: data,
          initialCategory: 'travel',
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('旅行/観光・レベル2 街角の探検家'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '2 街角の探検家'), findsOneWidget);
  });
  testWidgets(
    'search and stage controls fit 320px double text including keyboard',
    (t) async {
      t.view.physicalSize = const Size(320, 568);
      t.view.devicePixelRatio = 1;
      t.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() {
        t.view.resetPhysicalSize();
        t.view.resetDevicePixelRatio();
        t.view.resetViewInsets();
        t.platformDispatcher.clearTextScaleFactorTestValue();
      });
      await t.pumpWidget(
        MaterialApp(
          home: SkillTreePage(
            catalog: catalog,
            data: LearningData().withInterests(['beauty', 'money']),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('美容/コスメ'));
      await t.pumpAndSettle();
      t.view.viewInsets = const FakeViewPadding(bottom: 200);
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'マネー');
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      t.view.resetViewInsets();
      await t.pumpAndSettle();
      await t.tap(find.text('金融/マネー'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('レベル5 ？？？'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('レベル5 ？？？の挑戦問題へ'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    },
  );
}
