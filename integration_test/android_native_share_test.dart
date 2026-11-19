import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:phrase_flow/domain.dart';
import 'package:phrase_flow/today_share.dart';

// Isolated QA package only. The host inspects and cancels the Android sheet.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Pixel: pass PNG and text to the native Android share sheet', (
    tester,
  ) async {
    final now = DateTime.now();
    var demo = LearningData().withInterests(['lifestyle']);
    for (var i = 0; i < 30; i++) {
      demo = demo.rate('qa-demo', true, now);
    }
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'NotoSansJP'),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showTodayShare(context, data: demo, now: now),
                child: const Text('共有を確認'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('共有を確認'));
    for (
      var i = 0;
      i < 100 && find.byType(AlertDialog).evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    await tester.tap(find.text('共有先を選ぶ'));
    await Future<void>.delayed(const Duration(seconds: 3));
    debugPrint('[qa] IMAGE_SHARE_READY_FOR_HOST_CHECK');
    await Future<void>.delayed(const Duration(seconds: 45));
  });
}
