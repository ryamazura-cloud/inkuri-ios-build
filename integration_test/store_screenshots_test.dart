import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:phrase_flow/domain.dart';
import 'package:phrase_flow/grammar.dart';
import 'package:phrase_flow/monetization.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:phrase_flow/activity.dart';
import 'package:phrase_flow/interests.dart';
import 'package:phrase_flow/main.dart';
import '../test/widget_test.dart' show MemoryStore, tapText;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('capture actual iOS UI using isolated demonstration progress', (
    tester,
  ) async {
    await (FontLoader(
      'NotoSansJP',
    )..addFont(rootBundle.load('assets/fonts/NotoSansJP.ttf'))).load();
    final catalog = Question.decode(
      await rootBundle.loadString('assets/questions.json'),
    );
    final grammar = GrammarCatalog.decode(
      await rootBundle.loadString('assets/grammar.json'),
    );
    var demo = LearningData().withInterests(
      interestCategories.map((c) => c.id).toList(),
    );
    final now = DateTime.now();
    for (var day = 6; day >= 0; day--) {
      final date = now.subtract(Duration(days: day));
      for (var index = 0; index < 30; index++) {
        demo = demo.rate(catalog[index].id, index % 5 != 0, date);
      }
      demo = demo.addTime({dayKey(date): const Duration(minutes: 4).inMilliseconds});
    }
    Future<void> home({Monetization? monetization}) async {
      await tester.pumpWidget(
        PhraseFlowApp(
          key: UniqueKey(),
          store: MemoryStore()..raw = demo.encode(),
          loadCatalog: () async => catalog,
          loadGrammar: () async => grammar,
          monetization: monetization,
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      await binding.takeScreenshot(name);
    }

    await home();
    await capture('01-home');
    await tapText(tester, '金融/マネー');
    await capture('02-skill-tree');
    final start = find
        .ancestor(
          of: find.byWidgetPredicate(
            (widget) =>
                widget is Text && (widget.data?.endsWith('の学習へ') ?? false),
          ),
          matching: find.byType(OutlinedButton),
        )
        .first;
    await Scrollable.ensureVisible(tester.element(start));
    await tester.pumpAndSettle();
    await tester.tap(start);
    await tester.pumpAndSettle();
    await tapText(tester, '答えを表示');
    await capture('04-practice');
    await home();
    await tapText(tester, '学習記録');
    await capture('05-history');
    await home();
    if (find.text('修行モード').evaluate().isEmpty) {
      await tapText(tester, '冒険モード');
    }
    await tester.tap(find.text('修行モード').last);
    await tester.pumpAndSettle();
    await tapText(tester, 'be動詞');
    await capture('03-grammar-explanation');
    // Review-only UI fixture: product metadata matches App Store Connect JPY 900.
    // This image demonstrates the purchase entry point, not a verified purchase.
    final reviewPlan = Monetization()
      ..storeReady = true
      ..product = ProductDetails(
        id: Monetization.appleProductId,
        title: 'インクリ 無制限プラン',
        description: '通常練習を回数無制限・広告なしで利用できます。',
        price: '¥900',
        rawPrice: 900,
        currencyCode: 'JPY',
      );
    await home(monetization: reviewPlan);
    final planEntry = find.byTooltip('無料枠 3/3・追加チケット 0枚・有料プラン');
    await tester.tap(planEntry);
    await tester.pumpAndSettle();
    await capture('review-only-purchase-plan');
    expect(tester.takeException(), isNull);
  });
}
