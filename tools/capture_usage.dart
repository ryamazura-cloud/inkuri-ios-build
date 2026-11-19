import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phrase_flow/domain.dart';
import 'package:phrase_flow/main.dart';
import 'package:phrase_flow/interests.dart';
import '../test/widget_test.dart' show MemoryStore, tapText;

void main() {
  testWidgets('capture simple five-page guide and about dialog', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.runAsync(() async {
      await (FontLoader(
        'NotoSansJP',
      )..addFont(rootBundle.load('assets/fonts/NotoSansJP.ttf'))).load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    });
    final catalog = Question.decode(
      File('assets/questions.json').readAsStringSync(),
    );
    var demo = LearningData()
        .withInterests(interestCategories.map((c) => c.id).toList())
        .finishChallenge('travel', 'stage-1', 4, 5, DateTime(2026, 11, 3));
    final travel = catalog.firstWhere(
      (q) => categoryForQuestion(q) == 'travel',
    );
    for (var i = 0; i < 35; i++) {
      demo = demo.rate(
        i.isEven ? catalog.first.id : travel.id,
        true,
        DateTime(2026, 11, 3),
      );
    }
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: PhraseFlowApp(
          store: MemoryStore()..raw = demo.encode(),
          loadCatalog: () async => catalog,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/brand/inkuri-icon.png'),
        key.currentContext!,
      ),
    );
    await tester.pump();

    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File(
          '../usage-simple-$name.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await tester.runAsync(() async {
      for (final name in [
        'home',
        'grammar',
        'grammar-lesson',
        'prompt',
        'answer',
        'review',
        'tree',
        'quests',
      ]) {
        await precacheImage(
          AssetImage('assets/guide/$name.png'),
          key.currentContext!,
        );
      }
    });
    await tester.pumpAndSettle();
    await tapText(tester, '使い方');
    for (var i = 1; i <= 5; i++) {
      await capture('page-$i');
      if (i < 5) {
        await tapText(tester, '次へ');
      }
    }
    await tapText(tester, 'はじめる');
    await tester.tap(find.byTooltip('このアプリについて'));
    await tester.pumpAndSettle();
    await capture('about');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
