import 'package:flutter/material.dart';

import 'domain.dart';

class AnswerStudyNote {
  const AnswerStudyNote(this.example, this.explanation, this.usage);

  final String example;
  final String explanation;
  final List<({String term, String detail})> usage;
}

const answerStudyNotes = {
  'grammar-be-01': AnswerStudyNote("I'm home now.", '帰宅したことを伝える場面でもよく使う表現です。', [
    (
      term: 'at home / home',
      detail: 'I’m at home は今いる場所を伝えます。I’m home! は帰宅を告げるひと言としても使います。',
    ),
  ]),
  'grammar-be-02': AnswerStudyNote(
    'This box is lightweight.',
    'lightweight で、重さが軽いことをはっきり伝えます。',
    [
      (
        term: 'light / lightweight',
        detail: 'light には「明るい」などの意味もあります。lightweight は物の軽さに焦点を当てる表現です。',
      ),
      (
        term: 'this box / these boxes',
        detail: '箱が一つなら This box is ...。複数なら These boxes are ... です。',
      ),
    ],
  ),
  'grammar-be-03': AnswerStudyNote(
    "You're kind.",
    'You are を短くした形です。ふだんの会話で使えます。',
    [
      (
        term: 'kind / nice',
        detail: 'kind は相手を気遣う親切さ、nice は感じのよさなどにも使える広い表現です。',
      ),
    ],
  ),
  'grammar-be-04':
      AnswerStudyNote('We are classmates.', 'classmates は同じクラスで学ぶ人を指します。', [
        (
          term: 'in the same class / classmates',
          detail: 'in the same class は所属するクラスが同じこと、classmates は人同士の関係を伝えます。',
        ),
      ]),
  'grammar-verbs-01': AnswerStudyNote(
    'In the morning, I drink water.',
    '朝にすることを話すときは in the morning を先に置く言い方もできます。',
    [
      (
        term: 'in the morning / every morning',
        detail:
            'in the morning は朝という時間帯、every morning は毎朝という頻度を表します。every morning に in は付けません。',
      ),
      (
        term: 'water / a glass of water',
        detail: 'water は量を指定しません。コップ一杯と伝える場合は a glass of water です。',
      ),
    ],
  ),
  'grammar-verbs-02': AnswerStudyNote(
    'After school, we play tennis.',
    'after school を先に置くと、放課後にすることを伝えやすくなります。',
    [
      (
        term: 'play tennis / play the piano',
        detail:
            'スポーツ名 tennis の前には通常 the を付けません。楽器の演奏では play the piano のように the を付ける言い方が一般的です。',
      ),
    ],
  ),
  'grammar-verbs-03': AnswerStudyNote(
    "I've got a blue pen.",
    'have got も「持っている」を表し、会話でよく使われます。',
    [
      (
        term: 'a blue pen / the blue pen',
        detail: 'どのペンか指定せず一本を指すときは a。相手も分かる特定のペンなら the を使えます。',
      ),
    ],
  ),
  'grammar-verbs-04': AnswerStudyNote(
    'Every day, you work here.',
    'every day を先に置いて、頻度を強調する語順です。',
    [
      (
        term: 'every day / everyday',
        detail:
            'every day は「毎日」。everyday は everyday English のように名詞の前で「日常の」という意味になります。',
      ),
    ],
  ),
  'grammar-pronouns-02':
      AnswerStudyNote('This bag is hers.', 'hers だけで「彼女のもの」を表せます。', [
        (
          term: 'her bag / hers',
          detail: 'her は her bag のように名詞の前。hers は単独で使い、hers bag とは言いません。',
        ),
      ]),
  'grammar-pronouns-03': AnswerStudyNote(
    "That's my red bike.",
    '指しながら話す場面では、my red bike と言えます。',
    [(term: 'mine / my', detail: 'mine は単独で「私のもの」。my は my bike のように名詞に付けます。')],
  ),
  'grammar-pronouns-04': AnswerStudyNote(
    'Could you help us, please?',
    'Could you ...? を使うと、相手に丁寧に頼めます。',
    [
      (
        term: 'we / us',
        detail: 'we は動作の主語、us は動作を受ける相手です。help us では us を使います。',
      ),
    ],
  ),
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

AnswerStudyNote? studyNoteFor(Question question) {
  final curated = answerStudyNotes[question.id];
  if (curated != null) return curated;
  if (!question.isGrammar || question.answers.length != 1) return null;

  // Change the opening only when it is followed by a complement.
  final answer = question.answers.single.text;
  const openings = {
    'I am ': "I'm ",
    'You are ': "You're ",
    'We are ': "We're ",
    'They are ': "They're ",
    'He is ': "He's ",
    'She is ': "She's ",
    'It is ': "It's ",
  };
  for (final entry in openings.entries) {
    if (answer.startsWith(entry.key)) {
      return AnswerStudyNote(
        entry.value + answer.substring(entry.key.length),
        '短縮形は日常会話でよく使います。短縮しても、この文の意味は同じです。',
        const [],
      );
    }
  }
  return null;
}

class AnswerStudyDetails extends StatelessWidget {
  const AnswerStudyDetails({
    super.key,
    required this.question,
    required this.note,
  });

  final Question question;
  final AnswerStudyNote? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firstExplanation = question.answers.first.explanation;
    final explanation = firstExplanation.isEmpty
        ? question.note
        : firstExplanation;
    final supplement = note;
    if (explanation.isEmpty && supplement == null)
      return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F1EB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCCDFD5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('文法・単語の使い分け', style: theme.textTheme.titleSmall),
          if (explanation.isNotEmpty) ...[
            const SizedBox(height: 8),
            if (firstExplanation.isNotEmpty)
              const Text('ニュアンス・使い方', style: TextStyle(fontSize: 12)),
            Text(explanation, style: const TextStyle(height: 1.65)),
          ],
          if (supplement != null) ...[
            const SizedBox(height: 12),
            Text('さらに使える解答例', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(supplement.example, style: theme.textTheme.bodyLarge),
            Text(supplement.explanation, style: theme.textTheme.bodyMedium),
            for (final item in supplement.usage) ...[
              const SizedBox(height: 10),
              Text(item.term, style: theme.textTheme.titleSmall),
              Text(item.detail, style: const TextStyle(height: 1.6)),
            ],
          ],
        ],
      ),
    );
  }
}
