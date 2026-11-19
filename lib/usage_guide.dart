import 'dart:math' as math;
import 'package:flutter/material.dart';

Future<bool?> showUsageGuide(
  BuildContext context, {
  bool introductionOnly = false,
  bool offerTutorial = false,
}) => showDialog<bool>(
  context: context,
  builder: (_) => _UsageGuide(
    introductionOnly: introductionOnly,
    offerTutorial: offerTutorial,
  ),
);

class _UsageGuide extends StatefulWidget {
  const _UsageGuide({
    required this.introductionOnly,
    required this.offerTutorial,
  });
  final bool introductionOnly, offerTutorial;
  @override
  State<_UsageGuide> createState() => _UsageGuideState();
}

class _PracticePoint extends StatelessWidget {
  const _PracticePoint({
    required this.icon,
    required this.title,
    required this.explanation,
  });

  final IconData icon;
  final String title;
  final String explanation;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          colors.primary.withValues(alpha: 0.06),
          colors.surface,
        ),
        border: Border.all(color: colors.primary.withValues(alpha: 0.18)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.onPrimaryContainer),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: colors.onPrimaryContainer,
              fontWeight: FontWeight.w700,
              height: 1.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            explanation,
            style: TextStyle(color: colors.onPrimaryContainer, height: 1.8),
          ),
        ],
      ),
    );
  }
}

class _UsageGuideState extends State<_UsageGuide> {
  final controller = PageController();
  int page = 0;
  List<(String, String, String)> get steps =>
      widget.introductionOnly ? _steps.take(1).toList() : _steps;
  static const _steps = [
    (
      '1. 使える英語を、少しずつ増やす',
      '「ありがとう」と伝えたいとき、自然に「Thank you」が出てくる。そんな表現を、少しずつ増やしていくのがインクリの目的です。\n\n何度も聞いたり使ったりしてきた表現は、考え込まずに言いやすくなります。\n\nインクリでは、日本語を見て自分で英文を作り、声に出す練習を繰り返します。答えられなかった表現も、解答例と音声を確認して口になじませましょう。\n\n「知っている英語」を「使える英語」へ。短い英文から、一つずつ練習していきましょう。',
      'expression-growth',
    ),
    (
      '2. 学習モードを選ぶ',
      '英文の組み立て方を復習するなら「修行モード」、旅行や料理など興味のあるテーマで練習するなら「冒険モード」を選びます。\n\nモードはいつでも切り替えられます。',
      'home',
    ),
    (
      '3. 練習を始める',
      '修行モードでは、学年と文法を選び、文法メモを確認します。「10問で修行する」を押すと練習が始まります。迷ったら「be動詞」から始めてみてください。\n\n冒険モードでは、「スキルツリーを見る」を押し、テーマとレベルを選びます。',
      'grammar-lesson',
    ),
    (
      '4. 日本語を英語にする',
      '日本語を読んで、英語で言ってみましょう。「答えを表示」で解答例を確認できます。「音声を再生」を押すと、解答例の読み上げを聞けます。',
      'answer',
    ),
    (
      '5. 自己評価と復習',
      'すぐに言えたら「できた」を選びます。\n\nトップ画面の「復習」から苦手な問題に取り組めます。初期設定では、復習対象になってから「できた」が累計5回に達すると復習完了です。途中で「まだ難しい」を選んでも、積み上げた回数は維持されます。\n\n復習も通常練習と同じく、1セット開始時に通常チケット（無料枠）を先に使い、なくなったら追加チケットを1枚使います。無制限プランでは復習も回数制限なく利用できます。\n\n完了に必要な回数は、TOPのiアイコンで開く「このアプリについて」の「復習設定」で変更できます。',
      'review',
    ),
    (
      '6. レベルアップと挑戦',
      'どちらのモードでも、練習で経験値がたまるとレベルが上がります。「クエスト」を達成すると報酬を受け取れます。\n\n冒険モードでは、そのレベルの通常問題の8割（10問なら8問）で「できた」を選ぶと、挑戦問題に進めます。挑戦で5問中4問以上「できた」を選ぶと、次のレベルが解放されます。',
      'quests',
    ),
  ];

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(20),
    child: SizedBox(
      width: 520,
      height: math.min(720, MediaQuery.sizeOf(context).height * .86),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 8, top: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '使い方',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: '使い方を閉じる',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: PageView(
              controller: controller,
              onPageChanged: (index) => setState(() => page = index),
              children: [
                for (final step in steps)
                  SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          step.$1,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (step.$3 == 'answer') ...[
                          Text(step.$2, style: const TextStyle(height: 1.8)),
                          const SizedBox(height: 16),
                          const _PracticePoint(
                            icon: Icons.timer_outlined,
                            title: '2秒以内に言い始める',
                            explanation:
                                '慣れてきたら、日本語を見て2秒以内に英語で話し始めることを目指しましょう。',
                          ),
                          const _PracticePoint(
                            icon: Icons.record_voice_over_outlined,
                            title: '答えられなかったら、3〜5回声に出す',
                            explanation:
                                '解答例と音声を確認したら、解答を見ずに言う練習を3〜5回を目安に繰り返しましょう。見ずに言えるようになるまで練習し、英文を口になじませます。',
                          ),
                        ],
                        if (step.$3 == 'review')
                          const _PracticePoint(
                            icon: Icons.replay,
                            title: '考えるのに5秒以上なら「まだ難しい」',
                            explanation:
                                '答えられなかったときも「まだ難しい」を選びましょう。解答や音声を確認する時間は含めません。',
                          ),
                        if (step.$3 != 'answer')
                          Text(step.$2, style: const TextStyle(height: 1.8)),
                        const SizedBox(height: 16),
                        Semantics(
                          button: true,
                          label: step.$3 == 'expression-growth'
                              ? '英語の表現力が育つイラストを拡大'
                              : '${step.$1}の画面例を拡大',
                          child: InkWell(
                            onTap: () => showDialog<void>(
                              context: context,
                              builder: (ctx) => Dialog(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: InteractiveViewer(
                                        child: Image.asset(
                                          'assets/guide/${step.$3}.png',
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('閉じる'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.asset(
                                'assets/guide/${step.$3}.png',
                                height: 280,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (widget.offerTutorial)
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('実際の画面で操作を試す'),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                if (!widget.introductionOnly)
                  IconButton(
                    tooltip: '前の説明',
                    onPressed: page == 0
                        ? null
                        : () => controller.previousPage(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                          ),
                    icon: const Icon(Icons.chevron_left),
                  ),
                if (!widget.introductionOnly)
                  Text('${page + 1} / ${steps.length}'),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      if (page == steps.length - 1) {
                        Navigator.pop(context);
                      } else {
                        controller.nextPage(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                        );
                      }
                    },
                    child: Text(
                      widget.introductionOnly
                          ? '操作を試す'
                          : page == steps.length - 1
                          ? 'はじめる'
                          : '次へ',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
