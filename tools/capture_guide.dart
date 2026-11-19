import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phrase_flow/domain.dart';
import 'package:phrase_flow/main.dart';
import '../test/widget_test.dart' show MemoryStore, startStudy, tapText;

void main() {
  testWidgets('capture real training widgets for the usage guide', (
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
    final q = Question.decode(
      File('assets/questions.json').readAsStringSync(),
    ).first;
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: PhraseFlowApp(
          store: MemoryStore(),
          loadCatalog: () async => [q],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await startStudy(tester);
    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File(
          'assets/guide/$name.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture('prompt');
    await tapText(tester, '答えを表示');
    await capture('answer');
    await tester.ensureVisible(find.text('まだ難しい'));
    await tester.pumpAndSettle();
    await capture('review');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
