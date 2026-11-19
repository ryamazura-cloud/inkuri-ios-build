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
  testWidgets('capture real quest screens with sample records', (t) async {
    t.view.physicalSize = const Size(411, 880); t.view.devicePixelRatio = 1;
    addTearDown(() {t.view.resetPhysicalSize();t.view.resetDevicePixelRatio();});
    await t.runAsync(() async {
      await (FontLoader('NotoSansJP')..addFont(rootBundle.load('assets/fonts/NotoSansJP.ttf'))).load();
      await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    });
    final catalog = Question.decode(File('assets/questions.json').readAsStringSync());
    final grammar = GrammarCatalog.decode(File('assets/grammar.json').readAsStringSync());
    final now = DateTime.now();
    final week = DateTime(now.year, now.month, now.day - now.weekday + 1);
    var data = LearningData().withInterests(['beauty','health','food']);
    if (now.weekday >= 3) {
      data = data.rate(catalog[0].id, true, week)
        .rate(catalog[1].id, false, DateTime(week.year, week.month, week.day + 1))
        .rate(catalog[1].id, false, now)
        .rate(catalog[2].id, true, now).rate(catalog[3].id, true, now);
    } else {
      data = data.rate(catalog[1].id, false, now).rate(catalog[1].id, false, now)
        .rate(catalog[2].id, true, now).rate(catalog[3].id, true, now);
    }
    final key = GlobalKey();
    await t.pumpWidget(RepaintBoundary(key: key, child: PhraseFlowApp(
      store: MemoryStore()..raw = data.encode(), loadCatalog: () async => catalog,
      loadGrammar: () async => grammar)));
    await t.pumpAndSettle();
    await t.runAsync(() => precacheImage(const AssetImage('assets/brand/inkuri-icon.png'), key.currentContext!));
    await t.pump();
    Future<void> capture(String name) async {
      await t.pumpAndSettle();
      await t.runAsync(() async {
        final rendered = await (key.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage(pixelRatio: 2);
        final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
        File('../quests-0150-$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        rendered.dispose();
      });
    }
    await capture('home');
    await tapText(t, 'クエスト'); await capture('quests');
    final reward = find.text('報酬を受け取る').first;
    await t.ensureVisible(reward); await t.pumpAndSettle(); await t.tap(reward); await t.pumpAndSettle();
    await capture('reward');
    expect(find.text('クエスト達成！'), findsOneWidget);
    expect(t.takeException(), isNull);
    await tapText(t, '冒険を続ける');
    await t.pumpWidget(const SizedBox());
  });
}
