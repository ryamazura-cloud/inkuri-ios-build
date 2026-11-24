import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phrase_flow/domain.dart';
import 'package:phrase_flow/main.dart';
import 'growth_widget_test.dart' show tap;
import 'widget_test.dart' show MemoryStore;

void main() {
  testWidgets(
    'iOS requests review once at home after 30 answers across two days',
    (tester) async {
      final questions = List.generate(
        50,
        (i) => Question('ios-review-$i', '初級', '日常', 'こんにちは。', const [
          AnswerExample('Hello.'),
        ], ''),
      );
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final data = LearningData()
          .withInterests(['lifestyle'])
          .rate(questions.first.id, true, yesterday);
      final store = MemoryStore()..raw = data.encode();
      var requests = 0;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(
        PhraseFlowApp(
          store: store,
          loadCatalog: () async => questions,
          requestStoreReview: () async {
            final saved = await store.load();
            expect(
              saved.entries.values.fold(0, (n, entry) => n + entry.attempts),
              31,
            );
            requests++;
          },
        ),
      );
      await tester.pumpAndSettle();
      for (var set = 0; set < 3; set++) {
        await tap(tester, 'スキルツリーを見る');
        await tap(tester, 'レベル1 家事勉強中の学習へ');
        for (var index = 0; index < 10; index++) {
          await tap(tester, '答えを表示');
          expect(requests, 0);
          await tap(tester, 'できた');
          expect(requests, 0);
        }
        await tap(tester, 'ホームに戻る');
        expect(requests, set == 2 ? 1 : 0);
      }
      await tap(tester, 'スキルツリーを見る');
      await tap(tester, 'レベル1 家事勉強中の学習へ');
      await tap(tester, '答えを表示');
      await tap(tester, 'できた');
      expect(requests, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
    variant: TargetPlatformVariant({TargetPlatform.iOS}),
  );
}
