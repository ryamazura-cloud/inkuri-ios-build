import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phrase_flow/domain.dart';
import 'package:phrase_flow/grammar.dart';
import 'package:phrase_flow/main.dart';
import '../test/widget_test.dart' show MemoryStore, tapText;

void main() {
  testWidgets('capture actual grammar screens for the usage guide', (t) async {
    t.view.physicalSize = const Size(360, 760);
    t.view.devicePixelRatio = 1;
    addTearDown(() {
      t.view.resetPhysicalSize();
      t.view.resetDevicePixelRatio();
    });
    await t.runAsync(() async {
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
    final grammar = GrammarCatalog.decode(
      File('assets/grammar.json').readAsStringSync(),
    );
    final key = GlobalKey();
    await t.pumpWidget(
      RepaintBoundary(
        key: key,
        child: PhraseFlowApp(
          store: MemoryStore(),
          loadCatalog: () async => catalog,
          loadGrammar: () async => grammar,
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.runAsync(
      () => precacheImage(
        const AssetImage('assets/brand/inkuri-icon.png'),
        key.currentContext!,
      ),
    );
    await t.pump();
    Future<void> capture(String name) async {
      await t.pumpAndSettle();
      await t.runAsync(() async {
        final rendered =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
        File(
          'assets/guide/$name.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
        rendered.dispose();
      });
    }

    await tapText(t, '修行モード');
    await t.ensureVisible(find.text('文法を思い出す、はじめの修行。'));
    await t.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    await capture('grammar');
    await tapText(t, 'be動詞');
    await capture('grammar-lesson');
    await tapText(t, '10問で修行する');
    await capture('prompt');
    await tapText(t, '答えを表示');
    await capture('answer');
    await t.ensureVisible(find.text('まだ難しい'));
    await capture('review');
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
}
