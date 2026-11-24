import 'package:flutter/material.dart';
import 'domain.dart';
import 'grammar.dart';
import 'grammar_notes.dart';

class TrainingModeSwitch extends StatelessWidget {
  const TrainingModeSwitch({
    super.key,
    required this.mode,
    required this.onChanged,
    this.forceSegmented = false,
  });
  final TrainingMode mode;
  final ValueChanged<TrainingMode>? onChanged;
  final bool forceSegmented;
  @override
  Widget build(BuildContext context) {
    Widget option(TrainingMode value, String title, String subtitle) {
      final selected = mode == value;
      final color = selected ? Colors.white : const Color(0xFF176B61);
      final style = OutlinedButton.styleFrom(
        foregroundColor: color,
        backgroundColor: selected ? const Color(0xFF176B61) : Colors.white,
        padding: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      );
      return Semantics(
        selected: selected,
        child: OutlinedButton(
          style: style,
          onPressed: onChanged == null ? null : () => onChanged!(value),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (selected) ...[
                    const Icon(Icons.check, size: 16),
                    const SizedBox(width: 4),
                  ],
                  Expanded(child: Text(title)),
                ],
              ),
              const SizedBox(height: 3),
              Text(subtitle, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final adventure = option(TrainingMode.adventure, '冒険モード', '好きなテーマで英作文');
        final grammar = option(TrainingMode.grammar, '修行モード', '文法を単元ごとに練習');
        final stack =
            constraints.maxWidth < 310 ||
            MediaQuery.textScalerOf(context).scale(14) > 19;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '現在のモード：${mode == TrainingMode.adventure ? '冒険' : '修行'}モード',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF176B61),
              ),
            ),
            const SizedBox(height: 8),
            if (stack) ...[
              adventure,
              const SizedBox(height: 8),
              grammar,
            ] else
              Row(
                children: [
                  Expanded(child: adventure),
                  const SizedBox(width: 8),
                  Expanded(child: grammar),
                ],
              ),
            const SizedBox(height: 8),
            const Text('どちらのモードで学んでも、EXPは共通レベルに加算されます。'),
          ],
        );
      },
    );
  }
}

class GrammarPanel extends StatefulWidget {
  const GrammarPanel({
    super.key,
    required this.catalog,
    required this.data,
    required this.onOpen,
    this.guidedUnitId,
    this.guidedUnitKey,
  });
  final GrammarCatalog catalog;
  final LearningData data;
  final ValueChanged<GrammarUnit> onOpen;
  final String? guidedUnitId;
  final GlobalKey? guidedUnitKey;
  @override
  State<GrammarPanel> createState() => _GrammarPanelState();
}

class _GrammarPanelState extends State<GrammarPanel> {
  String? group;
  @override
  Widget build(BuildContext context) {
    final groups = widget.catalog.units.map((u) => u.group).toSet();
    final selectedGroup = groups.contains(group) ? group : groups.firstOrNull;
    final visible = widget.catalog.units
        .where((u) => u.group == selectedGroup)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '文法を思い出す、はじめの修行。',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          '${widget.catalog.units.length}文法・各10問。好きな文法から始められます。文法を思い出しながら、一つずつ練習しましょう。',
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: selectedGroup,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: '学年をえらぶ',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final name in groups)
              DropdownMenuItem(value: name, child: Text(name)),
          ],
          onChanged: (name) {
            if (name != null) setState(() => group = name);
          },
        ),
        const SizedBox(height: 8),
        for (final unit in visible)
          Card(
            key: unit.id == widget.guidedUnitId ? widget.guidedUnitKey : null,
            elevation: 0,
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              title: Text(
                unit.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '学習済み ${unit.questions.where((q) => (widget.data.entries[q.id]?.attempts ?? 0) > 0).length} / 10問',
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => widget.onOpen(unit),
            ),
          ),
      ],
    );
  }
}

typedef GrammarStudyChoice = ({List<Question> questions, bool review});

class GrammarLessonPage extends StatelessWidget {
  const GrammarLessonPage({
    super.key,
    required this.unit,
    required this.data,
    this.startButtonKey,
  });
  final GrammarUnit unit;
  final LearningData data;
  final GlobalKey? startButtonKey;
  @override
  Widget build(BuildContext context) {
    final weak = unit.questions
        .where((q) => data.entries[q.id]?.needsReview ?? false)
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(unit.title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '文法のひとくちメモ',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (unit.id == 'be' || grammarNotes.containsKey(unit.id))
                _GrammarNotes(unit)
              else ...[
                Text(
                  unit.hint,
                  style: const TextStyle(fontSize: 17, height: 1.8),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE4EDE7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '基本の形\n${unit.pattern}',
                    style: const TextStyle(fontSize: 17, height: 1.8),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              const Text(
                '日本語から英文を考えて、答えを確認します。最初はメモを見ながらでも大丈夫。解説と音声で、少しずつ文の形に慣れましょう。慣れてきたら2秒以内に言い始めるのが目標です。答えを考えるのに5秒以上かかったら「まだ難しい」を選び、あとで復習しましょう。',
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: startButtonKey,
                onPressed: () => Navigator.pop(context, (
                  questions: unit.questions,
                  review: false,
                )),
                icon: const Icon(Icons.school_outlined),
                label: const Text('10問で修行する'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: weak.isEmpty
                    ? null
                    : () => Navigator.pop(context, (
                        questions: weak,
                        review: true,
                      )),
                child: Text('この文法の苦手問題を復習（${weak.length}問）'),
              ),
              const SizedBox(height: 16),
              const Text(
                '学習時間・復習対象・EXPは冒険モードと共通で記録します。文法の学習でカテゴリーの挑戦が解放されることはありません。',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GrammarNotes extends StatelessWidget {
  const _GrammarNotes(this.unit);
  final GrammarUnit unit;

  static const beSections = [
    (
      title: '1. 主語で am・is・are を選ぶ',
      rule: 'I → am\nhe・she・it、1人や1つのもの → is\nyou・we・they、複数の人やもの → are',
      examples: [
        ('I am a student.', '私は生徒です。'),
        ('She is busy.', '彼女は忙しいです。'),
        ('They are at home.', '彼らは家にいます。'),
      ],
    ),
    (
      title: '2. 否定文は be動詞のあとに not',
      rule: '主語 ＋ am / is / are ＋ not ＋ 続き',
      examples: [('She is not busy.', '彼女は忙しくありません。')],
    ),
    (
      title: '3. 疑問文は be動詞を主語の前へ',
      rule: 'Am / Is / Are ＋ 主語 ＋ 続き？',
      examples: [
        ('Is she busy?', '彼女は忙しいですか？'),
        ('Yes, she is. / No, she is not.', 'はい、忙しいです。／いいえ、忙しくありません。'),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBe = unit.id == 'be';
    final sections = isBe
        ? beSections
        : [
            for (final (title, rule, english, japanese)
                in grammarNotes[unit.id]!)
              (title: title, rule: rule, examples: [(english, japanese)]),
          ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          isBe ? 'be動詞は、主語が「何か」「どんな状態か」「どこにいるか」を伝えるときに使います。' : unit.hint,
          style: const TextStyle(fontSize: 17, height: 1.6),
        ),
        for (final section in sections)
          Card(
            elevation: 0,
            margin: const EdgeInsets.only(top: 12),
            color: const Color(0xFFE4EDE7),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(section.title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(section.rule, style: const TextStyle(height: 1.5)),
                  for (final (english, japanese) in section.examples) ...[
                    const SizedBox(height: 12),
                    Text(
                      english,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(japanese),
                  ],
                ],
              ),
            ),
          ),
        if (isBe) ...[
          const SizedBox(height: 12),
          const Text(
            '会話では I am → I’m、she is → she’s、are not → aren’t のように短く言うこともよくあります。',
          ),
        ],
      ],
    );
  }
}
