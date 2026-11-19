import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phrase_flow/domain.dart';
import 'package:phrase_flow/growth.dart';
import 'package:phrase_flow/main.dart';
import 'widget_test.dart' show MemoryStore, q;

Map<String, dynamic> legacy(int xp) => {
  'schemaVersion': 1,
  'entries': {
    'q': {
      'attempts': xp ~/ 5,
      'successes': 0,
      'needsReview': true,
      'lastStudied': '2026-11-04T09:00:00',
    },
  },
};

void main() {
  testWidgets(
    'existing level and title remain visible after saving and reopening',
    (t) async {
      final store = MemoryStore()..raw = jsonEncode(legacy(350));
      for (var i = 0; i < 2; i++) {
        await t.pumpWidget(
          PhraseFlowApp(store: store, loadCatalog: () async => [q]),
        );
        await t.pumpAndSettle();
        expect(find.text('Lv. 5'), findsOneWidget);
        expect(find.text('役職：会話の見習い'), findsOneWidget);
        expect(find.text('累計 350 EXP'), findsOneWidget);
        expect(find.text('あと 310 EXPで Lv. 6'), findsOneWidget);
        expect((await store.load()).levelXpOffset, 490);
        await t.pumpWidget(const SizedBox());
        await t.pumpAndSettle();
      }
    },
  );
  test(
    'legacy level, role and fractional progress survive the slower curve',
    () {
      final data = LearningData.decode(jsonEncode(legacy(360)));
      final growth = GrowthProgress(data);
      expect(growth.xp, 360);
      expect(growth.level, 5);
      expect(growth.title, '会話の見習い');
      expect(growth.fraction, closeTo(20 / 310, .000001));
      expect(growth.remaining, 290);
      expect(data.entries['q']!.attempts, 72);
      final advanced = GrowthProgress(
        data.rate('q', true, DateTime(2026, 11, 4)),
      );
      expect(advanced.xp, 370);
      expect(advanced.remaining, 280);
    },
  );

  test(
    'legacy migration applies once and every immutable update retains it',
    () {
      final date = DateTime(2026, 11, 4);
      var data = LearningData.decode(jsonEncode(legacy(350)));
      expect(GrowthProgress(data).level, 5);
      expect(GrowthProgress(data).remaining, 310);
      data = data
          .withInterests(['travel'])
          .visit(date)
          .addTime({'2026-11-04': 60000})
          .finishChallenge('travel', 'stage-1', 4, 5, date)
          .rate('q', true, date)
          .withQuestClaim('2026-11-04|first-step');
      for (var i = 0; i < 3; i++) {
        data = LearningData.decode(data.encode());
        expect(data.levelXpOffset, 490);
        expect(GrowthProgress(data).xp, 370);
        expect(GrowthProgress(data).level, 5);
        expect(GrowthProgress(data).remaining, 290);
      }
      expect(
        GrowthProgress(LearningData().withInterests(data.interests)).xp,
        0,
      );
      expect(LearningData().levelXpOffset, 0);
    },
  );

  test(
    'new learners and their saved data use the new curve from the start',
    () {
      var data = LearningData();
      for (var i = 0; i < 14; i++) {
        data = data.rate('q', true, DateTime(2026, 11, 4));
      }
      data = LearningData.decode(data.encode());
      expect(data.levelXpOffset, 0);
      expect(GrowthProgress(data).level, 1);
      expect(GrowthProgress(data).remaining, 10);
      expect(
        GrowthProgress(data.rate('q', true, DateTime(2026, 11, 4))).level,
        2,
      );
    },
  );

  test('migration includes earned rewards and protects high-level titles', () {
    final raw = legacy(340)..['questClaims'] = ['2026-11-04|first-step'];
    final data = LearningData.decode(jsonEncode(raw));
    expect(GrowthProgress(data).xp, 350);
    expect(GrowthProgress(data).level, 5);
    expect(GrowthProgress(data).remaining, 310);
    final high = LearningData.decode(jsonEncode(legacy(126225)));
    expect(GrowthProgress(high).level, 100);
    expect(GrowthProgress(high).nextRole, isNull);
  });

  test('version 2 keeps current rank, history and earned EXP', () {
    final raw = legacy(1050)
      ..['levelBalanceVersion'] = 2
      ..['levelXpOffset'] = 0
      ..['levelUpDays'] = {'5': '2026-11-08'};
    final migrated = LearningData.decode(jsonEncode(raw));
    final restored = LearningData.decode(migrated.encode());
    final growth = GrowthProgress(restored);
    expect(growth.level, 5);
    expect(growth.title, '会話の見習い');
    expect(growth.xp, 1050);
    expect(growth.remaining, 310);
    expect(restored.levelUpDays, {5: '2026-11-08'});
  });

  test('invalid migration metadata is rejected instead of losing progress', () {
    for (final fields in [
      {'levelBalanceVersion': 4, 'levelXpOffset': 0},
      {'levelBalanceVersion': 3, 'levelXpOffset': -351},
      {'levelBalanceVersion': 2, 'levelXpOffset': -1},
      {'levelBalanceVersion': 2, 'levelXpOffset': '700'},
      {'levelBalanceVersion': 2},
      {'levelXpOffset': 700},
    ]) {
      expect(
        () => LearningData.decode(jsonEncode({...legacy(350), ...fields})),
        throwsFormatException,
      );
    }
  });
}
