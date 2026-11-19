import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phrase_flow/course_levels.dart';
import 'package:phrase_flow/domain.dart';
import 'package:phrase_flow/interests.dart';
import 'package:phrase_flow/growth_widgets.dart';
import 'package:phrase_flow/stages.dart';

void main() {
  final catalog = Question.decode(
    File('assets/questions.json').readAsStringSync(),
  );
  test(
    '85 category-specific titles preserve stage IDs and question assignments',
    () {
      expect(
        categoryTitles.keys.toSet(),
        interestCategories.map((c) => c.id).toSet(),
      );
      expect(categoryTitles.values.expand((s) => s).toSet().length, 85);
      for (final c in interestCategories) {
        expect(categoryTitles[c.id]!.length, 5);
        for (final stage in courseLevels) {
          final named = courseLevel(stage.key, category: c.id);
          expect(named.key, stage.key);
          expect(named.number, stage.number);
          expect(named.name, isNot(isIn(['入門', '基礎', '実践', '応用', '発展'])));
          for (final q in selectStageQuestions(catalog, c.id, stage.key)) {
            expect(stageLabels(catalog)[q.id], named.label);
          }
        }
      }
    },
  );
  testWidgets(
    'all category title selectors fit small screens and double text',
    (t) async {
      t.view.physicalSize = const Size(320, 568);
      t.view.devicePixelRatio = 1;
      addTearDown(() {
        t.view.resetPhysicalSize();
        t.view.resetDevicePixelRatio();
        t.platformDispatcher.clearTextScaleFactorTestValue();
      });
      for (final scale in [1.0, 2.0]) {
        t.platformDispatcher.textScaleFactorTestValue = scale;
        for (final c in interestCategories) {
          await t.pumpWidget(
            MaterialApp(
              home: SkillTreePage(
                key: ValueKey('${c.id}-$scale'),
                catalog: catalog,
                data: LearningData().withInterests([c.id]),
              ),
            ),
          );
          await t.pumpAndSettle();

          await t.tap(find.byTooltip('レベル5 ？？？'));
          await t.pumpAndSettle();
          await t.ensureVisible(find.text('レベル5 ？？？の挑戦問題へ'));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull, reason: '${c.id} text $scale');
        }
      }
    },
  );
}
