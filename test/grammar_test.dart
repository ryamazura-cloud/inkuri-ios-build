import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phrase_flow/domain.dart';
import 'package:phrase_flow/grammar.dart';
import 'package:phrase_flow/grammar_notes.dart';
import 'package:phrase_flow/grammar_widgets.dart';
import 'package:phrase_flow/growth.dart';
import 'package:phrase_flow/main.dart';
import 'package:phrase_flow/stages.dart';
import 'widget_test.dart' show MemoryStore, q, tapText;

class MemoryModeStore implements TrainingModeStore {
  TrainingMode value = TrainingMode.adventure;
  bool fail = false;
  @override
  Future<TrainingMode> load() async => value;
  @override
  Future<void> save(TrainingMode mode) async {
    if (fail) throw StateError('unavailable');
    value = mode;
  }
}

Future<void> selectGrammarMode(WidgetTester t) async {
  if (find.text('修行モード').evaluate().isEmpty) await tapText(t, '冒険モード');
  await t.tap(find.text('修行モード').last);
  await t.pumpAndSettle();
}

void main() {
  final source = File('assets/grammar.json').readAsStringSync();
  final grammar = GrammarCatalog.decode(source);
  final adventure = Question.decode(
    File('assets/questions.json').readAsStringSync(),
  );
  testWidgets('all grammar units have detailed notes with bilingual examples', (
    t,
  ) async {
    expect(
      grammarNotes.keys.toSet(),
      grammar.units.map((unit) => unit.id).where((id) => id != 'be').toSet(),
    );
    expect(grammarNotes.values.every((notes) => notes.length == 3), isTrue);
    await t.pumpWidget(
      MaterialApp(
        home: GrammarLessonPage(
          unit: grammar.units.singleWhere((unit) => unit.id == 'comparison'),
          data: LearningData(),
        ),
      ),
    );
    expect(find.text('This bridge is longer than that one.'), findsOneWidget);
    expect(find.text('この橋はあの橋より長いです。'), findsOneWidget);
    expect(find.text('10問で修行する'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  test('34 units contain exactly ten independent original questions each', () {
    expect(grammar.units.length, 34);
    expect(grammar.questions.length, 340);
    expect(grammar.units.map((u) => u.title).toSet().length, 34);
    expect(
      grammar.questions
          .map((q) => q.id)
          .toSet()
          .intersection(adventure.map((q) => q.id).toSet()),
      isEmpty,
    );
    expect(grammar.questions.map((q) => q.japanese).toSet().length, 340);
    for (final unit in grammar.units) {
      expect(unit.questions.length, 10);
      expect(
        unit.questions.every(
          (q) => q.isGrammar && q.grammarUnit == unit.id && q.note.isNotEmpty,
        ),
        isTrue,
      );
    }
    expect(
      grammar.units.singleWhere((u) => u.id == 'relative-subject').title,
      '関係代名詞：主格',
    );
    expect(
      grammar.units.singleWhere((u) => u.id == 'relative-object').title,
      '関係代名詞：目的格',
    );
  });
  test('corrupt or repeated cross-unit references cannot enter the app', () {
    for (final change in [
      (Map<String, dynamic> raw) =>
          (raw['units'] as List).first['questionIds'].removeLast(),
      (Map<String, dynamic> raw) =>
          raw['units'][1]['questionIds'][0] = raw['units'][0]['questionIds'][0],
      (Map<String, dynamic> raw) =>
          raw['questions'][0]['grammarUnit'] = 'unknown',
      (Map<String, dynamic> raw) =>
          raw['units'][1]['id'] = raw['units'][0]['id'],
    ]) {
      final raw = jsonDecode(source) as Map<String, dynamic>;
      change(raw);
      expect(
        () => GrammarCatalog.decode(jsonEncode(raw)),
        throwsFormatException,
      );
    }
  });
  test(
    'grammar never changes category membership, stage allocation or challenge gates',
    () {
      final all = [...adventure, ...grammar.questions];
      final selected = LearningData().withInterests([
        'beauty',
        'lifestyle',
        'travel',
      ]);
      var rated = selected;
      for (final question in grammar.questions) {
        rated = rated.rate(question.id, true, DateTime(2026, 11, 3));
      }
      expect(stageLabels(all), stageLabels(adventure));
      for (final category in selected.interests) {
        expect(
          categoryStages(
            all,
            category,
          ).map((key, value) => MapEntry(key, value.map((q) => q.id).toList())),
          categoryStages(
            adventure,
            category,
          ).map((key, value) => MapEntry(key, value.map((q) => q.id).toList())),
        );
      }
      expect(
        interestSkills(all, rated).where((s) => s.challengeUnlocked),
        isEmpty,
      );
      expect(GrowthProgress(rated).xp, 3400);
      expect(rated.challengePasses, isEmpty);
    },
  );
  testWidgets(
    'ten grammar questions save review, EXP and shared history without requiring interests',
    (t) async {
      final store = MemoryStore(), modeStore = MemoryModeStore();
      Future<void> open() async {
        await t.pumpWidget(
          PhraseFlowApp(
            store: store,
            loadCatalog: () async => [q],
            loadGrammar: () async => grammar,
            modeStore: modeStore,
          ),
        );
        await t.pumpAndSettle();
      }

      await open();
      await selectGrammarMode(t);
      expect(modeStore.value, TrainingMode.grammar);
      expect(find.text('スキルツリーを見る'), findsNothing);
      await tapText(t, 'be動詞');
      expect(find.text('文法のひとくちメモ'), findsOneWidget);
      await tapText(t, '10問で修行する');
      final session = t
          .widget<TrainingPage>(find.byType(TrainingPage))
          .questions;
      expect(session.length, 10);
      expect(session.every((q) => q.grammarUnit == 'be'), isTrue);
      expect(session.map((q) => q.id).toSet().length, 10);
      for (var i = 0; i < 10; i++) {
        expect(find.text(session[i].japanese), findsOneWidget);
        await tapText(t, '答えを表示');
        expect(find.text(session[i].answers.first.text), findsOneWidget);
        expect(find.text('文法・単語の使い分け'), findsOneWidget);
        await tapText(t, i == 0 ? 'まだ難しい' : 'できた');
      }
      await tapText(t, 'ホームに戻る');
      final saved = LearningData.decode(store.raw!);
      expect(saved.entries.length, 10);
      expect(GrowthProgress(saved).xp, 95);
      expect(saved.entries[session.first.id]!.needsReview, isTrue);
      expect(saved.interests, isEmpty);
      expect(saved.challengePasses, isEmpty);
      expect(saved.days.values.fold(0, (sum, day) => sum + day.questions), 10);
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
      await open();
      await tapText(t, 'be動詞');
      await tapText(t, 'この文法の苦手問題を復習（1問）');
      expect(
        t.widget<TrainingPage>(find.byType(TrainingPage)).questions.single.id,
        session.first.id,
      );
      await tapText(t, '答えを表示');
      await tapText(t, 'できた');
      await tapText(t, 'ホームに戻る');
      expect(find.text('復習（1問）'), findsOneWidget);
      expect(GrowthProgress(LearningData.decode(store.raw!)).xp, 105);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'group selection finds advanced topics without search and mode failures keep the old selection',
    (t) async {
      final modeStore = MemoryModeStore();
      await t.pumpWidget(
        PhraseFlowApp(
          store: MemoryStore(),
          loadCatalog: () async => [q],
          loadGrammar: () async => grammar,
          modeStore: modeStore,
        ),
      );
      await t.pumpAndSettle();
      await selectGrammarMode(t);
      expect(find.byType(TextField), findsNothing);
      await tapText(t, '中学1年生文法');
      await tapText(t, '中学2年生文法');
      expect(find.text('受け身'), findsOneWidget);
      expect(find.text('be動詞'), findsNothing);
      await tapText(t, '中学2年生文法');
      await tapText(t, '中学3年生文法');
      await t.pumpAndSettle();
      expect(find.text('関係代名詞：主格'), findsOneWidget);
      expect(find.text('関係代名詞：目的格'), findsOneWidget);
      expect(find.text('be動詞'), findsNothing);
      await tapText(t, '関係代名詞：目的格');
      expect(
        find.text(
          grammar.units.singleWhere((u) => u.id == 'relative-object').hint,
        ),
        findsOneWidget,
      );
      await t.tap(find.byTooltip('戻る'));
      await t.pumpAndSettle();
      modeStore.fail = true;
      await tapText(t, '冒険モード');
      expect(modeStore.value, TrainingMode.grammar);
      expect(find.byType(GrammarPanel), findsOneWidget);
      expect(find.textContaining('学習モードを保存できませんでした'), findsOneWidget);
    },
  );
  testWidgets(
    'home review includes weak questions from different grammar units',
    (t) async {
      final first = grammar.units
          .singleWhere((u) => u.id == 'past-verbs')
          .questions
          .first;
      final second = grammar.units
          .singleWhere((u) => u.id == 'relative-object')
          .questions
          .first;
      final data = LearningData()
          .rate(first.id, false, DateTime(2026, 11, 3))
          .rate(second.id, false, DateTime(2026, 11, 3));
      final store = MemoryStore()..raw = data.encode();
      await t.pumpWidget(
        PhraseFlowApp(
          store: store,
          loadCatalog: () async => [q],
          loadGrammar: () async => grammar,
        ),
      );
      await t.pumpAndSettle();
      await tapText(t, '復習（2問）');
      final session = t.widget<TrainingPage>(find.byType(TrainingPage));
      expect(session.questions.map((q) => q.id).toSet(), {first.id, second.id});
      expect(LearningData.decode(store.raw!).entries.length, 2);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    '320px and doubled text retain usable mode, grammar list, lesson and question',
    (t) async {
      t.view.physicalSize = const Size(320, 568);
      t.view.devicePixelRatio = 1;
      t.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() {
        t.view.resetPhysicalSize();
        t.view.resetDevicePixelRatio();
        t.platformDispatcher.clearTextScaleFactorTestValue();
      });
      await t.pumpWidget(
        PhraseFlowApp(
          store: MemoryStore(),
          loadCatalog: () async => [q],
          loadGrammar: () async => grammar,
        ),
      );
      await t.pumpAndSettle();
      await selectGrammarMode(t);
      await tapText(t, 'be動詞');
      await tapText(t, '10問で修行する');
      await tapText(t, '答えを表示');
      await tapText(t, 'まだ難しい');
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
}
