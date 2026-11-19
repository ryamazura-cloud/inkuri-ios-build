import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:phrase_flow/activity.dart';
import 'package:phrase_flow/domain.dart';
import 'package:phrase_flow/main.dart';
import 'package:phrase_flow/quest_widgets.dart';
import '../test/widget_test.dart' show MemoryStore;
import 'android_smoke_test.dart' show tapText, startStudy;

// Run only in the separate biz.wisemap.encre.qa Android application.
// Demonstration records live in memory and never modify Play learning data.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Pixel: category, daily share at 30 and 40, graph date labels', (
    tester,
  ) async {
    final catalog = Question.decode(
      await rootBundle.loadString('assets/questions.json'),
    );
    final now = DateTime.now();
    var demo = LearningData().withInterests(['lifestyle', 'travel']);
    for (var i = 0; i < 20; i++) {
      demo = demo.rate(catalog.first.id, true, now);
    }
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'NotoSansJP'),
        home: QuestPage(
          data: () => LearningData(),
          ticketsEnabled: true,
          onClaim: (_) async =>
              throw StateError('No reward is claimed in this check'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('苦手を味方に'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('全達成には、この復習クエスト'), findsNothing);
    await binding.takeScreenshot('07-review-quest-note-hidden');
    final store = MemoryStore()..raw = demo.encode();
    await tester.pumpWidget(
      PhraseFlowApp(store: store, loadCatalog: () async => catalog),
    );
    await tester.pumpAndSettle();
    await tapText(tester, 'カテゴリー変更');
    expect(find.text('興味のある分野'), findsOneWidget);
    await binding.takeScreenshot('01-category-picker');
    await tester.tap(find.byTooltip('戻る'));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('02-category-button');
    for (final target in [30, 40]) {
      await startStudy(tester);
      for (var i = 0; i < 10; i++) {
        expect(find.text('今日の取り組みをシェア'), findsNothing);
        await tapText(tester, '答えを表示');
        await tapText(tester, 'できた');
      }
      expect((await store.load()).days[dayKey(now)]!.questions, target);
      expect(find.text('成果を共有'), findsNothing);
      expect(find.text('今日の取り組みをシェア'), findsOneWidget);
      await binding.takeScreenshot('03-result-$target');
      await tapText(tester, '今日の取り組みをシェア');
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        tester.widget<SelectableText>(find.byType(SelectableText)).data,
        contains('今日の学習：$target問'),
      );
      expect(find.byType(Image), findsWidgets);
      await binding.takeScreenshot('04-share-preview-$target');
      await tapText(tester, '閉じる');
      await tapText(tester, 'ホームに戻る');
    }
    await tapText(tester, '学習記録');
    expect(find.text('学習記録を共有'), findsOneWidget);
    expect(
      find.text(
        '${now.day}\n${const ['月', '火', '水', '木', '金', '土', '日'][now.weekday - 1]}',
      ),
      findsOneWidget,
    );
    await binding.takeScreenshot('05-history-daily');
    await tapText(tester, '月別');
    expect(find.text('${now.month}月'), findsOneWidget);
    await binding.takeScreenshot('06-history-monthly');
    binding.reportData = {
      'package': 'biz.wisemap.encre.qa',
      'fixture': 'in-memory demonstration records; separate Android package',
      'dailyCountsVerified': [30, 40],
      'screenshots': binding.reportData?['screenshots'],
      'nativeShareSheet': 'not yet verified by this test',
    };
    // Leave the real share sheet open for the host to inspect. No SNS posting.
    await tapText(tester, '学習記録を共有');
    await tapText(tester, '共有先を選ぶ');
    await tester.pump(const Duration(seconds: 2));
  });
}
