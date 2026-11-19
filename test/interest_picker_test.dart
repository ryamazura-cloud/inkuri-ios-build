import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phrase_flow/domain.dart';
import 'package:phrase_flow/interest_picker.dart';

final catalog = Question.decode(
  File('assets/questions.json').readAsStringSync(),
);

Future<void> openPicker(
  WidgetTester tester, {
  List<String> selected = const [],
  required Future<void> Function(List<String>) save,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<bool>(
                builder: (_) => InterestPickerPage(
                  catalog: catalog,
                  selected: selected,
                  onSave: save,
                ),
              ),
            ),
            child: const Text('設定を開く'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('設定を開く'));
  await tester.pumpAndSettle();
}

Future<void> choose(WidgetTester tester, String id) async {
  final finder = find.byKey(ValueKey('interest-$id'));
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      180,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'requires one category and saves multiple choices in stable order',
    (tester) async {
      List<String>? saved;
      await openPicker(
        tester,
        save: (ids) async {
          saved = ids;
        },
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, '0分野を選択して進む'),
            )
            .onPressed,
        isNull,
      );
      await choose(tester, 'beauty');
      await choose(tester, 'games');
      await tester.tap(find.text('2分野を選択して進む'));
      await tester.pumpAndSettle();
      expect(saved, ['beauty', 'games']);
      expect(find.text('設定を開く'), findsOneWidget);
    },
  );
  testWidgets('cancel discards changes rather than writing preferences', (
    tester,
  ) async {
    var calls = 0;
    final original = ['games'];
    await openPicker(
      tester,
      selected: original,
      save: (_) async {
        calls++;
      },
    );
    await choose(tester, 'beauty');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(original, ['games']);
  });
  testWidgets('failed preference save stays on picker and can be retried', (
    tester,
  ) async {
    var fail = true;
    List<String>? saved;
    await openPicker(
      tester,
      save: (ids) async {
        if (fail) throw StateError('disk full');
        saved = ids;
      },
    );
    await choose(tester, 'beauty');
    await tester.tap(find.text('1分野を選択して進む'));
    await tester.pumpAndSettle();
    expect(saved, isNull);
    expect(find.text('興味のある分野'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('1分野を選択して進む'));
    await tester.pumpAndSettle();
    expect(saved, ['beauty']);
  });
  testWidgets('long category labels and footer work at 320px and double text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    List<String>? saved;
    await openPicker(
      tester,
      save: (ids) async {
        saved = ids;
      },
    );
    await choose(tester, 'business');
    await tester.tap(find.text('1分野を選択して進む'));
    await tester.pumpAndSettle();
    expect(saved, ['business']);
    expect(tester.takeException(), isNull);
  });
}
