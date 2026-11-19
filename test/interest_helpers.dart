import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> chooseAvailableInterest(WidgetTester tester) async {
  if (find.text('興味のある分野').evaluate().isEmpty) return;
  final checkbox = find.byWidgetPredicate(
    (w) => w is CheckboxListTile && w.onChanged != null && w.value != true,
  );
  if (checkbox.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      checkbox,
      180,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await Scrollable.ensureVisible(
    tester.element(checkbox.first),
    alignment: 0.5,
  );
  await tester.pumpAndSettle();
  await tester.tap(checkbox.first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('1分野を選択して進む'));
  await tester.pumpAndSettle();
}
