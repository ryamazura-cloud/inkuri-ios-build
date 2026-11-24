import 'package:flutter/material.dart';

class AnswerStudyNote {
  const AnswerStudyNote(this.example, this.explanation, this.usage);

  final String example;
  final String explanation;
  final List<({String term, String detail})> usage;
}

const answerStudyNotes = {
  'work-b-003': AnswerStudyNote(
    "I'm working remotely from home today.",
    'remotely を加えると、出社せずに仕事をしていることが明確になります。',
    [
      (
        term: 'from home / at home',
        detail: 'from home は勤務形態、at home は仕事をしている場所に焦点を当てます。',
      ),
      (term: 'home / house', detail: 'home は自宅や暮らしの場、house は家という建物を指すことが多いです。'),
    ],
  ),
  'daily-i-001': AnswerStudyNote(
    "I'll stay home if it rains.",
    '条件を後ろに置く言い方です。語順を変えても意味は同じです。',
    [
      (
        term: 'stay home / stay at home',
        detail: 'どちらも「家にいる」。at を省く形は特にアメリカ英語でよく使われます。',
      ),
      (term: 'if it rains', detail: '未来の天気についてでも、この条件節では現在形 rains を使います。'),
    ],
  ),
  'daily-a-014': AnswerStudyNote(
    "It's been easier to get ready in the morning since I started going to bed earlier.",
    'It’s been easier to ... で、今まで続く変化を表せます。',
    [
      (
        term: 'in the morning / on Monday morning',
        detail: '「朝に」は in the morning。「月曜の朝に」のように日を指定すると on を使います。',
      ),
      (
        term: 'get ready / prepare',
        detail:
            'get ready は自分の身支度をする場面で自然です。prepare for work なら仕事に向けて準備する意味にもなります。',
      ),
    ],
  ),
  'travel-i-013': AnswerStudyNote(
    "Could you get me a taxi for 6 a.m. tomorrow?",
    'get me a taxi は、ホテルなどでタクシーを手配してもらうときの自然な言い方です。',
    [
      (
        term: 'for six / at six',
        detail:
            'for six はタクシーを予約する時刻。book a taxi at six は、予約の操作を6時に行う意味にも読めます。',
      ),
      (
        term: 'a taxi / the taxi',
        detail: 'まだどの車か決まっていないなら a taxi。すでに話題に出ている車なら the taxi を使えます。',
      ),
    ],
  ),
  'work-b-014': AnswerStudyNote(
    "Could you give me a bit of time to think?",
    'a bit of time は「少しの時間」を柔らかく伝える言い方です。',
    [
      (
        term: 'a little time / little time',
        detail: 'a little time は「少し時間がある」。little time は「ほとんど時間がない」と不足を強調します。',
      ),
      (
        term: 'small / little',
        detail:
            '小さいかばんは a small bag。time や water のように数えないものの量には a little を使えます。',
      ),
    ],
  ),
  'interest-lifestyle-b-001': AnswerStudyNote(
    "I open the curtains first thing in the morning.",
    'first thing in the morning は「朝一番に」という定番の表現です。',
    [
      (
        term: 'the curtains / curtains',
        detail: '自分の部屋など、どのカーテンか分かる場面では the curtains が自然です。',
      ),
      (
        term: 'in the morning / every morning',
        detail: 'every morning は「毎朝」と頻度を明示し、前置詞は付けません。',
      ),
    ],
  ),
  'interest-lifestyle-i-002': AnswerStudyNote(
    "I live close to the station so that I can spend less time commuting.",
    'so that I can ... を使って、駅の近くに住む目的を説明しています。',
    [
      (
        term: 'near / close to',
        detail:
            'どちらも「〜の近くに」。near the station と close to the station のように、close には to が必要です。',
      ),
      (
        term: 'a station / the station',
        detail: 'どの駅か特に指定しなければ a station。最寄り駅など相手も特定できる駅なら the station を使います。',
      ),
      (
        term: 'small / little',
        detail:
            'a small house は建物の大きさを中立的に伝えます。a little house は、小ささに親しみなどの印象が加わることがあります。',
      ),
      (
        term: 'house / home',
        detail:
            'a house near the station は駅近くの建物。my home is near the station は自分の住まいの場所を伝えます。',
      ),
    ],
  ),
  'interest-lifestyle-a-001': AnswerStudyNote(
    "Especially on busy days, I want to set aside a little time for myself.",
    'set aside time は「時間を確保する」。on busy days でどんな日にそうしたいかを示します。',
    [
      (
        term: 'a little time / a short break',
        detail: 'a little time は時間の量。a short break は一回の短い休憩を指します。',
      ),
      (
        term: 'by myself / for myself',
        detail:
            'by myself は「一人で」、for myself は「自分のために」。ここでは自分のための時間なので for myself が合います。',
      ),
    ],
  ),
};

class AnswerStudyDetails extends StatelessWidget {
  const AnswerStudyDetails({super.key, required this.note});

  final AnswerStudyNote note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Text('さらに使える解答例', style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(note.example, style: theme.textTheme.bodyLarge),
        Text(note.explanation, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          child: ExpansionTile(
            leading: const Icon(Icons.lightbulb_outline),
            title: const Text('文法・単語の使い分け'),
            expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            children: [
              for (final item in note.usage) ...[
                const SizedBox(height: 8),
                Text(item.term, style: theme.textTheme.titleSmall),
                Text(item.detail),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
