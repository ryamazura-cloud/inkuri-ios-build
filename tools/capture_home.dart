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
  testWidgets('capture home category levels', (tester) async {
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
          '../home-0140-$name.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture('top');
    await tapText(tester, '役職：会話の見習い');
    await capture('roles');
    await tapText(tester, '閉じる');
    await tapText(tester, '金融/マネー');
    await capture('tree');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

