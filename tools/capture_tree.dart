import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phrase_flow/domain.dart';
import 'package:phrase_flow/main.dart';
import '../test/widget_test.dart' show MemoryStore, tapText;
import 'package:phrase_flow/interests.dart';

void main() {
  testWidgets('capture category and five-level navigation', (tester) async {
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
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: PhraseFlowApp(
          store: MemoryStore()
            ..raw = LearningData()
                .withInterests(interestCategories.map((c) => c.id).toList())
                .encode(),
          loadCatalog: () async => catalog,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tapText(tester, 'スキルツリーを見る');
    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File(
          '../stages-0100-$name.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture('tree');
    await tapText(tester, '美容/コスメ');
    await tester.enterText(find.byType(TextField), '旅行');
    await tester.pumpAndSettle();
    await capture('search');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
