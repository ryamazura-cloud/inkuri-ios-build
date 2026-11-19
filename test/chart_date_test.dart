import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phrase_flow/activity.dart';
import 'package:phrase_flow/category_levels.dart';
import 'package:phrase_flow/domain.dart';
import 'package:phrase_flow/learning_dashboard.dart';

void main() {
  testWidgets(
    'dates stay readable across a year boundary, monthly mode and large text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      final boundaryKey = GlobalKey();
      final anchor = DateTime(2027, 1, 5);
      final days = <String, DailyActivity>{
        for (var i = 0; i < 14; i++)
          dayKey(anchor.subtract(Duration(days: i))): DailyActivity(
            questions: (i % 4 + 1) * 10,
            milliseconds: (i % 4 + 1) * 120000,
          ),
      };
      final catalog = Question.decode(
        File('assets/questions.json').readAsStringSync(),
      );
      for (final large in [false, true]) {
        tester.view.physicalSize = Size(large ? 320 : 390, 844);
        tester.platformDispatcher.textScaleFactorTestValue = large ? 2 : 1;
        for (final monthly in [false, true]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(
                fontFamily: 'NotoSansJP',
                colorSchemeSeed: const Color(0xFF176B61),
              ),
              home: RepaintBoundary(
                key: boundaryKey,
                child: Scaffold(
                  backgroundColor: const Color(0xFFF6F7F2),
                  body: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          CategoryLevels(
                            catalog: catalog,
                            data: LearningData().withInterests([
                              'beauty',
                              'travel',
                            ]),
                            onOpen: (_) {},
                            onEdit: () {},
                          ),
                          const SizedBox(height: 16),
                          ActivityChart(
                            key: ValueKey('$large-$monthly'),
                            points: chartPeriods(
                              days,
                              anchor,
                              monthly: monthly,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final label = monthly ? '1月' : '1\n金';
          await Scrollable.ensureVisible(
            tester.element(find.text(label)),
            alignment: 0.5,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text(label));
          await tester.pumpAndSettle();
          expect(
            find.textContaining(monthly ? '2027年1月：' : '2027年1月1日（金）：'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          final output = Platform.environment['INKURI_CHART_PREVIEW_OUTPUT'];
          if (output != null && !large && !monthly) {
            await tester.runAsync(() async {
              final loader = FontLoader('NotoSansJP')
                ..addFont(rootBundle.load('assets/fonts/NotoSansJP.ttf'));
              await loader.load();
              final icons = FontLoader('MaterialIcons')
                ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
              await icons.load();
            });
            await tester.pumpAndSettle();
            await tester.runAsync(() async {
              final image =
                  await (boundaryKey.currentContext!.findRenderObject()
                          as RenderRepaintBoundary)
                      .toImage(pixelRatio: 2);
              final png = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File(output).writeAsBytes(png!.buffer.asUint8List());
              image.dispose();
            });
          }
        }
      }
    },
  );
}
