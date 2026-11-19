import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phrase_flow/activity.dart';
import 'package:phrase_flow/domain.dart';
import 'package:phrase_flow/main.dart';
import 'package:phrase_flow/today_share.dart';
import 'speech_test.dart' show FakeSpeechEngine;
import 'growth_widget_test.dart' show tap, question;
import 'widget_test.dart' show MemoryStore;

void main() {
  testWidgets('C achievement card fits a small screen with double text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    var data = LearningData();
    final now = DateTime(2026, 11, 19, 12);
    for (var i = 0; i < 30; i++) {
      data = data.rate(question.id, true, now);
    }
    await tester.pumpWidget(
      MaterialApp(
        home: TrainingPage(
          questions: List.filled(10, question),
          speechEngine: FakeSpeechEngine(),
          studyData: () => data,
          now: () => now,
          onRate: (q, success) async {
            data = data.rate(q.id, success, now);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 10; i++) {
      await tap(tester, '答えを表示');
      await tap(tester, 'できた');
    }
    await tester.ensureVisible(find.text('今日の取り組みをシェア'));
    await tester.pumpAndSettle();
    expect(find.text('今日40問に挑戦！'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('ホームに戻る'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final output = Platform.environment['INKURI_SHARE_CARD_PREVIEW_OUTPUT'];
    if (output != null) {
      tester.view.physicalSize = const Size(390, 420);
      tester.platformDispatcher.textScaleFactorTestValue = 1;
      final key = GlobalKey();
      await tester.runAsync(() async {
        await (FontLoader(
          'NotoSansJP',
        )..addFont(rootBundle.load('assets/fonts/NotoSansJP.ttf'))).load();
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            fontFamily: 'NotoSansJP',
            colorSchemeSeed: const Color(0xFF176B61),
          ),
          home: RepaintBoundary(
            key: key,
            child: Scaffold(
              backgroundColor: const Color(0xFFF6F7F2),
              body: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TodayShareCard(questions: 40, onShare: () {}),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF176B61),
                        side: const BorderSide(color: Color(0xFF176B61)),
                      ),
                      onPressed: () {},
                      child: const Text('ホームに戻る'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(output).writeAsBytes(png!.buffer.asUint8List());
        image.dispose();
      });
    }
  });

  testWidgets(
    'daily sharing starts at 30, remains above 30 and resets at midnight',
    (tester) async {
      var now = DateTime(2026, 11, 19, 12);
      var data = LearningData();
      for (var i = 0; i < 28; i++) {
        data = data.rate(question.id, true, now);
      }
      final originalAllowance = data.allowance;
      for (final count in [29, 30, 31, 1]) {
        if (count == 1) now = DateTime(2026, 11, 20);
        await tester.pumpWidget(
          MaterialApp(
            home: TrainingPage(
              key: UniqueKey(),
              questions: const [question],
              speechEngine: FakeSpeechEngine(),
              studyData: () => data,
              now: () => now,
              onRate: (q, success) async {
                data = data.rate(q.id, success, now);
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('今日の取り組みをシェア'), findsNothing);
        await tap(tester, '答えを表示');
        await tap(tester, 'できた');
        expect(data.days[dayKey(now)]!.questions, count);
        expect(find.text('成果を共有'), findsNothing);
        expect(
          find.text('今日の取り組みをシェア'),
          count >= 30 ? findsOneWidget : findsNothing,
        );
        expect(data.allowance, same(originalAllowance));
        expect(
          find.text('今日$count問に挑戦！'),
          count >= 30 ? findsOneWidget : findsNothing,
        );
        if (count >= 30) {
          expect(
            tester.getTopLeft(find.text('今日の取り組みをシェア')).dy,
            lessThan(tester.getTopLeft(find.text('ホームに戻る')).dy),
          );
          expect(
            find.ancestor(
              of: find.text('ホームに戻る'),
              matching: find.byType(OutlinedButton),
            ),
            findsOneWidget,
          );
        }
      }
    },
  );

  testWidgets('home practice passes saved daily activity to the result', (
    tester,
  ) async {
    var data = LearningData().withInterests(['lifestyle']);
    for (var i = 0; i < 29; i++) {
      data = data.rate(question.id, true, DateTime.now());
    }
    final store = MemoryStore()..raw = data.encode();
    await tester.pumpWidget(
      PhraseFlowApp(store: store, loadCatalog: () async => [question]),
    );
    await tester.pumpAndSettle();
    await tap(tester, 'スキルツリーを見る');
    await tap(tester, 'レベル1 家事勉強中の学習へ');
    await tap(tester, '答えを表示');
    await tap(tester, 'できた');
    expect(find.text('今日の取り組みをシェア'), findsOneWidget);
    expect((await store.load()).days[dayKey(DateTime.now())]!.questions, 30);
  });

  testWidgets(
    'today image and text use only today and sharing sends the PNG after confirmation',
    (tester) async {
      final now = DateTime(2026, 11, 19, 12);
      var data = LearningData().withInterests(['lifestyle']);
      for (var i = 0; i < 40; i++) {
        data = data.rate(question.id, true, now);
      }
      data = data.rate(question.id, true, DateTime(2026, 11, 18)).addTime({
        '2026-11-19': 612000,
        '2026-11-18': 999000,
      });
      final text = todayShareText(data, now);
      expect(text, contains('今日の学習：40問'));
      expect(text, contains('学習時間：10分 12秒'));
      expect(text, contains('連続学習：2日'));
      expect(text, isNot(contains('41問')));
      expect(
        text,
        contains(
          '日本語を見て、2秒で英語を考え始める練習。\n瞬間英作文アプリ「インクリ」\nhttps://encre.wisemap.biz/',
        ),
      );
      MethodCall? received;
      const paths = MethodChannel('plugins.flutter.io/path_provider');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        paths,
        (_) async => Directory.systemTemp.path,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          paths,
          null,
        ),
      );
      const channel = MethodChannel('dev.fluttercommunity.plus/share');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        received = call;
        return 'test-target';
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showTodayShare(context, data: data, now: now),
                child: const Text('開く'),
              ),
            ),
          ),
        ),
      );
      final loader = FontLoader('NotoSansJP')
        ..addFont(rootBundle.load('assets/fonts/NotoSansJP.ttf'));
      await tester.runAsync(() async {
        await loader.load();
        final image = await todayShareImage(data, now);
        expect(image.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
        final output = Platform.environment['INKURI_SHARE_PREVIEW_OUTPUT'];
        if (output != null) await File(output).writeAsBytes(image);
        await tester.tap(find.text('開く'));
      });
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pumpAndSettle();
      expect(received, isNull);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(
        tester.widget<SelectableText>(find.byType(SelectableText)).data,
        text,
      );
      await tester.runAsync(() async {
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '共有先を選ぶ'))
            .onPressed!();
      });
      for (var i = 0; i < 40 && received == null; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(received?.method, 'share');
      expect((received!.arguments as Map)['text'], text);
      expect((received!.arguments as Map)['paths'], isNotEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
