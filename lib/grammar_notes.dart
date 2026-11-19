typedef GrammarNote = (
  String title,
  String rule,
  String english,
  String japanese,
);

const grammarNotes = <String, List<GrammarNote>>{
  'verbs': [
    (
      '動作や習慣を伝える',
      'I・you・we・they のあとは動詞の原形。毎日の習慣などを表せます。',
      'We walk to school every day.',
      '私たちは毎日歩いて学校に行きます。',
    ),
    (
      '「何を」は動詞のあと',
      '「何を」にあたる語は、ふつう動詞のあとに置きます。',
      'I read books on weekends.',
      '私は週末に本を読みます。',
    ),
    (
      '動作の文と状態の文',
      'play が文の動詞です。この形では play の前に am・is・are を置きません。',
      'They play tennis after school.',
      '彼らは放課後にテニスをします。',
    ),
  ],
  'questions-negatives': [
    (
      '一般動詞で尋ねる',
      'Do / Does ＋ 主語 ＋ 動詞の原形。主語が she のときは Does を使います。',
      'Does she like coffee?',
      '彼女はコーヒーが好きですか？',
    ),
    (
      '一般動詞を否定する',
      '主語のあとに don’t / doesn’t を置き、続く動詞は原形にします。',
      'She doesn’t like coffee.',
      '彼女はコーヒーが好きではありません。',
    ),
    (
      'be動詞の文',
      '疑問文では be動詞を前に、否定文では be動詞のあとに not を置きます。',
      'Is she at home?',
      '彼女は家にいますか？',
    ),
  ],
  'question-words': [
    (
      '何・どこ・いつを聞く',
      'What・Where・When などを文の先頭に置き、そのあとを疑問文の語順にします。',
      'Where do you buy bread?',
      'どこでパンを買いますか？',
    ),
    (
      '「誰が」を聞く',
      'Who 自体が主語なら、Who のあとに動詞が続きます。',
      'Who teaches English here?',
      'ここでは誰が英語を教えていますか？',
    ),
    (
      '理由や方法を聞く',
      '理由は Why、方法は How。どちらも聞きたい内容を文の先頭で示します。',
      'How do you get to work?',
      'どうやって職場に行きますか？',
    ),
  ],
  'imperatives': [
    (
      '指示やお願い',
      '動詞の原形から始めます。Please を添えるとお願いの形になります。',
      'Please wait here.',
      'ここでお待ちください。',
    ),
    (
      '「〜しないで」',
      'Don’t ＋ 動詞の原形。be動詞を使うときは Don’t be の形です。',
      'Don’t open the window.',
      '窓を開けないでください。',
    ),
    (
      '「一緒に〜しよう」',
      '自分も含めて誘うときは Let’s ＋ 動詞の原形を使います。',
      'Let’s take a break.',
      '休憩しましょう。',
    ),
  ],
  'third-person': [
    (
      'he・she・it なら s',
      '現在の習慣などを言うとき、主語が he・she・it や一人の名前なら動詞に s が付きます。',
      'She reads before bed.',
      '彼女は寝る前に本を読みます。',
    ),
    (
      'つづりが変わる動詞',
      'go → goes、study → studies、have → has のように形が変わる動詞もあります。',
      'My brother studies at night.',
      '兄は夜に勉強します。',
    ),
    (
      'does のあとは原形',
      '疑問文や否定文で does / doesn’t を使うと、続く動詞から s が取れます。',
      'Does your brother study at night?',
      'お兄さんは夜に勉強しますか？',
    ),
  ],
  'present-progressive': [
    (
      '今していること',
      '主語 ＋ am / is / are ＋ 動詞の ing形。be動詞も一緒に使います。',
      'I am washing the dishes.',
      '私は皿を洗っています。',
    ),
    (
      'ing形のつづり',
      'make → making のように末尾の e を落とすものや、run → running のように子音を重ねるものがあります。',
      'She is making lunch.',
      '彼女は昼食を作っています。',
    ),
    (
      '進行中かを尋ねる',
      'be動詞を主語の前に出します。否定する場合は be動詞のあとに not を置きます。',
      'Are they waiting outside?',
      '彼らは外で待っていますか？',
    ),
  ],
  'can': [
    (
      '「〜できる」',
      '主語 ＋ can ＋ 動詞の原形。主語が she でも can や動詞に s は付きません。',
      'She can play the piano.',
      '彼女はピアノを弾けます。',
    ),
    (
      '「〜できない」',
      'can の否定は cannot または短縮形の can’t です。',
      'I can’t swim yet.',
      '私はまだ泳げません。',
    ),
    (
      '許可やお願い',
      'Can I ...? は許可、Can you ...? は相手へのお願いにも使えます。',
      'Can I sit here?',
      'ここに座ってもいいですか？',
    ),
  ],
  'past-verbs': [
    (
      '過去にしたこと',
      '多くの動詞は ed を付けます。go → went のように不規則に変わる動詞もあります。',
      'I went to the library yesterday.',
      '昨日、図書館に行きました。',
    ),
    (
      '過去の否定文',
      '主語 ＋ didn’t ＋ 動詞の原形。went ではなく go を使います。',
      'I didn’t go to the library yesterday.',
      '昨日は図書館に行きませんでした。',
    ),
    (
      '過去の疑問文',
      'Did ＋ 主語 ＋ 動詞の原形。過去を表す did が先頭に来ます。',
      'Did you go to the library yesterday?',
      '昨日、図書館に行きましたか？',
    ),
  ],
  'plurals': [
    (
      '数えられるものが2つ以上',
      '数えられる名詞には、ふつう s を付けます。数が一つなら単数形です。',
      'I bought two notebooks.',
      'ノートを2冊買いました。',
    ),
    (
      'つづりが変わるもの',
      'box → boxes、city → cities のように末尾のつづりによって形が変わります。',
      'We packed three boxes.',
      '私たちは箱を3つ詰めました。',
    ),
    (
      '不規則な複数形',
      'child → children、person → people のように s だけでは作れないものもあります。',
      'The children are in the park.',
      '子どもたちは公園にいます。',
    ),
  ],
  'pronouns': [
    (
      '「誰が」と「誰を・誰に」',
      '主語には I・he・they など、動詞や前置詞のあとには me・him・them などを使います。',
      'He called me last night.',
      '彼は昨晩、私に電話しました。',
    ),
    (
      '「私の」のあとに名詞',
      'my・your・her などのあとには、何を持っているのかを表す名詞が続きます。',
      'This is her umbrella.',
      'これは彼女の傘です。',
    ),
    (
      '「私のもの」は一語で',
      'mine・yours・hers は「〜のもの」を表すので、そのあとに名詞を置く必要はありません。',
      'This umbrella is hers.',
      'この傘は彼女のものです。',
    ),
  ],
  'past-be': [
    (
      '過去の状態を表す',
      'I・he・she・it には was、you・we・they には were を使います。',
      'I was tired yesterday.',
      '昨日は疲れていました。',
    ),
    (
      '「〜ではなかった」',
      'was / were のあとに not を置きます。短くすると wasn’t / weren’t です。',
      'We weren’t at home last night.',
      '昨晩、私たちは家にいませんでした。',
    ),
    (
      '過去の状態を尋ねる',
      'Was / Were を主語の前へ出します。',
      'Were you busy yesterday?',
      '昨日は忙しかったですか？',
    ),
  ],
  'past-progressive': [
    (
      '過去のある時点で進行中',
      '主語 ＋ was / were ＋ 動詞の ing形。「そのとき〜していた」と言えます。',
      'I was studying at eight last night.',
      '昨晩8時には勉強していました。',
    ),
    (
      '別の出来事と組み合わせる',
      '続いていた行動を過去進行形、途中で起きた出来事を過去形で表せます。',
      'I was cooking when the phone rang.',
      '電話が鳴ったとき、料理をしていました。',
    ),
    (
      '何をしていたか聞く',
      'What のあとに were ＋ 主語 ＋ ing形を続けます。',
      'What were you doing then?',
      'そのとき何をしていましたか？',
    ),
  ],
  'future': [
    (
      'その場で決めたこと',
      'will のあとには原形が来ます。その場での申し出や判断にも使います。',
      'I’ll carry that for you.',
      'それ、私が持ちますよ。',
    ),
    (
      '前から決めていた予定',
      'am / is / are going to ＋ 原形で、すでに考えている予定を表せます。',
      'We’re going to visit Kyoto next month.',
      '来月、京都を訪れる予定です。',
    ),
    (
      '今の様子から予想する',
      '目の前に根拠がある予想にも be going to を使えます。',
      'Look at those clouds. It’s going to rain.',
      'あの雲を見て。雨が降りそうです。',
    ),
  ],
  'gerunds': [
    (
      '「〜すること」を表す',
      '動詞の ing形を、文の主語など名詞と同じ位置で使えます。',
      'Cooking is fun.',
      '料理をするのは楽しいです。',
    ),
    (
      'enjoy のあとに置く',
      'enjoy や finish などは、あとに別の動作を続けるとき ing形を使います。',
      'I enjoy walking by the river.',
      '川沿いを散歩するのが楽しいです。',
    ),
    (
      '前置詞のあとに置く',
      'about や for などの前置詞のあとで動作を表すときは ing形です。',
      'Thank you for helping me.',
      '手伝ってくれてありがとう。',
    ),
  ],
  'infinitives': [
    (
      '「〜したい」',
      'want のあとに to ＋ 動詞の原形を置くと、したいことを言えます。',
      'I want to learn Italian.',
      'イタリア語を学びたいです。',
    ),
    (
      '「〜するために」',
      '行動の目的を付け足すときにも to ＋ 原形を使います。',
      'I went outside to get some fresh air.',
      '新鮮な空気を吸うために外に出ました。',
    ),
    (
      '「〜するもの」',
      '名詞のあとに to ＋ 原形を置き、何に使うかを説明できます。',
      'Do you have anything to drink?',
      '何か飲み物はありますか？',
    ),
  ],
  'modals': [
    (
      'must で必要性を伝える',
      'must ＋ 動詞の原形は「〜しなければならない」。must not は禁止を表します。',
      'You must show your ticket.',
      'チケットを見せる必要があります。',
    ),
    (
      'should で助言する',
      'should ＋ 原形は「〜したほうがいい」と勧めるときに使えます。',
      'You should take a short break.',
      '少し休憩したほうがいいですよ。',
    ),
    (
      'may で可能性を示す',
      'may ＋ 原形は「〜かもしれない」。確かではない見込みを伝えます。',
      'It may snow tonight.',
      '今夜は雪が降るかもしれません。',
    ),
  ],
  'comparison': [
    (
      '2つを比べる',
      '短い形容詞は比較級にして than を続けます。longer than なら「〜より長い」です。',
      'This bridge is longer than that one.',
      'この橋はあの橋より長いです。',
    ),
    (
      'いちばんを表す',
      'the ＋ 最上級で、グループの中の「いちばん」を表します。long なら the longest です。',
      'This is the longest bridge in town.',
      'これは町でいちばん長い橋です。',
    ),
    (
      '同じくらいを表す',
      'as ＋ 元の形の形容詞 ＋ as で「〜と同じくらい」。',
      'This bag is as light as mine.',
      'このバッグは私のものと同じくらい軽いです。',
    ),
  ],
  'there': [
    (
      '何かがある・いる',
      'There is ＋ 単数名詞で、まだ話題に出ていないものの存在を紹介できます。',
      'There is a bakery near my house.',
      '家の近くにパン屋があります。',
    ),
    (
      '複数ある・いる',
      '複数を紹介するときは There are を使います。場所はあとに添えられます。',
      'There are two chairs by the door.',
      'ドアのそばに椅子が2脚あります。',
    ),
    (
      'あるかを尋ねる',
      'Is there / Are there を先頭に置き、後ろの名詞に合わせて選びます。',
      'Are there any seats left?',
      '空いている席はありますか？',
    ),
  ],
  'conjunctions': [
    (
      '内容を足す・対比する',
      'and は内容を足し、but は前の内容と対比します。',
      'I like coffee, but my sister prefers tea.',
      '私はコーヒーが好きですが、妹は紅茶のほうが好きです。',
    ),
    (
      '理由を伝える',
      'because のあとに主語と動詞を含む文を置きます。',
      'I stayed home because I was sick.',
      '具合が悪かったので家にいました。',
    ),
    (
      '条件や時を伝える',
      'if は条件、when は時を表します。if のまとまりを文の先頭に置くこともできます。',
      'If it rains, we’ll stay inside.',
      '雨が降ったら、屋内にいます。',
    ),
  ],
  'passive': [
    (
      '「〜される」を表す',
      '受け身は be動詞 ＋ 過去分詞。動作を受けるものを主語にします。',
      'These cookies are made by hand.',
      'このクッキーは手作りです。',
    ),
    (
      '過去の受け身',
      '過去のことなら was / were ＋ 過去分詞。過去分詞の形はそのままです。',
      'The window was repaired yesterday.',
      '窓は昨日修理されました。',
    ),
    (
      '誰がしたかを伝える',
      '動作をした人を添えるなら by ＋ 人。分からないときや重要でないときは省けます。',
      'This picture was painted by my aunt.',
      'この絵は叔母が描きました。',
    ),
  ],
  'perfect-continuation': [
    (
      '過去から今まで続く状態',
      'have / has ＋ 過去分詞で、今まで続く状態を伝えられます。',
      'We have lived here for three years.',
      '私たちはここに3年間住んでいます。',
    ),
    (
      'for と since を選ぶ',
      'for のあとには期間、since のあとには始まった時点を置きます。',
      'She has lived here since 2020.',
      '彼女は2020年からここに住んでいます。',
    ),
    (
      '続いた長さを尋ねる',
      'How long ＋ have / has ＋ 主語 ＋ 過去分詞で、どのくらい続いているか尋ねます。',
      'How long have you known him?',
      '彼とは知り合ってどのくらいですか？',
    ),
  ],
  'perfect-experience': [
    (
      '「〜したことがある」',
      'have / has ＋ 過去分詞で、今までの経験を伝えます。before は「以前に」です。',
      'I have seen that film before.',
      '以前、その映画を見たことがあります。',
    ),
    (
      '経験があるかを尋ねる',
      'Have ＋ 主語 ＋ ever ＋ 過去分詞。ever は「今までに」の意味です。',
      'Have you ever visited Canada?',
      'カナダに行ったことがありますか？',
    ),
    (
      '一度もない経験',
      'never を have / has のあとに置きます。never に否定の意味があるので not は不要です。',
      'I have never tried skiing.',
      'スキーをしたことが一度もありません。',
    ),
  ],
  'perfect-completion': [
    (
      '「たった今〜した」',
      'have / has ＋ just ＋ 過去分詞で、終わったばかりのことを伝えます。',
      'I have just finished lunch.',
      'ちょうど昼食を食べ終えたところです。',
    ),
    (
      '「もう〜した」',
      'already は、今の時点ですでに終わっていることを表します。',
      'She has already sent the email.',
      '彼女はもうメールを送りました。',
    ),
    (
      '「まだ〜していない」',
      'yet は疑問文や否定文の末尾でよく使います。否定文では「まだ」の意味です。',
      'I haven’t opened it yet.',
      '私はまだそれを開けていません。',
    ),
  ],
  'perfect-progressive': [
    (
      '続けている動作',
      'have / has been ＋ ing形で、過去に始まり今まで続いている動作を表します。',
      'I have been studying for two hours.',
      '2時間ずっと勉強しています。',
    ),
    (
      '開始時点を添える',
      'since のあとに開始時点、for のあとに期間を添えます。',
      'It has been raining since noon.',
      '正午からずっと雨が降っています。',
    ),
    (
      '状態には現在完了を使う',
      'know のように状態を表す動詞は、通常は進行形にせず have / has ＋ 過去分詞を使います。',
      'I have known her for years.',
      '彼女とは何年も前からの知り合いです。',
    ),
  ],
  'infinitives-advanced': [
    (
      'やり方を表す',
      'how to ＋ 動詞の原形で「〜する方法」を表せます。',
      'I don’t know how to use this app.',
      'このアプリの使い方が分かりません。',
    ),
    (
      '人に何かを頼む',
      'ask ＋ 人 ＋ to ＋ 原形で「人に〜するよう頼む」です。',
      'I asked him to open the door.',
      '彼にドアを開けてくれるよう頼みました。',
    ),
    (
      '「〜すぎてできない」',
      'too ＋ 形容詞 ＋ to ＋ 原形で、程度が大きすぎてできないことを伝えます。',
      'The box is too heavy to lift.',
      'その箱は重すぎて持ち上げられません。',
    ),
  ],
  'bare-infinitives': [
    (
      'let は「させてあげる」',
      'let ＋ 人 ＋ 動詞の原形で、ある行動を許したことを表します。',
      'They let me use their computer.',
      '彼らは私にパソコンを使わせてくれました。',
    ),
    (
      'make は「〜させる」',
      'make ＋ 人 ＋ 原形は、働きかけや出来事によって人が何かをしたときに使えます。',
      'The joke made us laugh.',
      'その冗談で私たちは笑いました。',
    ),
    (
      'help は「〜するのを手伝う」',
      'help ＋ 人 のあとは原形を使えます。help では to を添える形も使えます。',
      'She helped me carry the bags.',
      '彼女は私が荷物を運ぶのを手伝ってくれました。',
    ),
  ],
  'participles': [
    (
      'している側を説明する',
      'ing形で、名詞がしている動作を説明できます。',
      'A sleeping cat was on the sofa.',
      '眠っている猫がソファにいました。',
    ),
    (
      'された側を説明する',
      '過去分詞で、名詞が何かをされたことや、その結果の状態を説明できます。',
      'We replaced the broken chair.',
      '壊れた椅子を取り替えました。',
    ),
    (
      '語が続く説明は名詞のあと',
      '分詞に場所などの語が続くときは、まとまりを名詞のあとに置けます。',
      'The man standing by the door is my uncle.',
      'ドアのそばに立っている男性は私の叔父です。',
    ),
  ],
  'indirect-questions': [
    (
      '疑問を文の中に入れる',
      '疑問詞のあとは、主語 ＋ 動詞の順にします。where the station is がひとまとまりです。',
      'Do you know where the station is?',
      '駅がどこにあるか知っていますか？',
    ),
    (
      'do / does を外す',
      '疑問が文の一部になったら、語順を戻し、疑問文を作るための do / does は使いません。',
      'I know what she wants.',
      '彼女が何を欲しいか知っています。',
    ),
    (
      '「誰が」なら同じ語順',
      'who 自体が主語のときは、who のあとに動詞が続きます。',
      'Do you know who made this cake?',
      '誰がこのケーキを作ったか知っていますか？',
    ),
  ],
  'relative-subject': [
    (
      '人を who で説明する',
      '人を表す名詞のあとに who ＋ 動詞。「〜する人」というまとまりになります。',
      'I know a girl who plays the violin.',
      'バイオリンを弾く女の子を知っています。',
    ),
    (
      '物を which や that で説明する',
      '物や動物には which や that が使えます。あとに、その物や動物がすることを続けます。',
      'This is a bus that goes to the airport.',
      'これは空港へ行くバスです。',
    ),
    (
      '関係代名詞が主語になる',
      'who 自体が後ろの動詞の主語です。who の直後に she などを足す必要はありません。',
      'The woman who lives next door is a doctor.',
      '隣に住む女性は医師です。',
    ),
  ],
  'relative-object': [
    (
      '「私が〜したもの」',
      '名詞 ＋ that / which ＋ 主語 ＋ 動詞。説明する名詞が後ろの動詞の目的語にあたります。',
      'This is the book that I bought yesterday.',
      'これは昨日私が買った本です。',
    ),
    (
      '目的格は省けることがある',
      'ここでは that のあとに I という主語があるので、that を省いても意味が伝わります。',
      'This is the book I bought yesterday.',
      'これは昨日私が買った本です。',
    ),
    (
      '同じ目的語を繰り返さない',
      'the movie が watched の目的語にあたるため、watched のあとに it は足しません。',
      'The movie we watched was funny.',
      '私たちが見た映画は面白かったです。',
    ),
  ],
  'subjunctive': [
    (
      '今とは違う状況を想像する',
      'If ＋ 主語 ＋ 過去形で、現実とは違う状況を思い浮かべます。結果には would ＋ 原形を使えます。',
      'If I had more time, I would read more books.',
      'もっと時間があれば、もっと本を読むのに。',
    ),
    (
      '「もし私があなたなら」',
      '助言でよく使う形は If I were you。were はここでは想像を表します。',
      'If I were you, I would ask for help.',
      '私なら、助けを求めます。',
    ),
    (
      'できることを想像する',
      '結果を could ＋ 原形にすると「〜できるのに」という意味になります。',
      'If I had a car, I could visit you more often.',
      '車があれば、もっと頻繁に会いに行けるのに。',
    ),
  ],
  'adjectives': [
    (
      '名詞の前に置く',
      '形容詞 ＋ 名詞で、どんな人やものかを説明します。',
      'We found a quiet café.',
      '静かなカフェを見つけました。',
    ),
    (
      'be動詞のあとに置く',
      '主語 ＋ be動詞 ＋ 形容詞で、主語がどんな状態かを伝えます。',
      'The café is quiet.',
      'そのカフェは静かです。',
    ),
    (
      '状態を表す動詞と使う',
      'look や feel のあとにも、見た目や感じた状態を表す形容詞を置けます。',
      'You look tired.',
      '疲れているように見えます。',
    ),
  ],
  'adverbs': [
    (
      '動作の様子を表す',
      '副詞は、動作がどのように行われるかを伝えます。',
      'Please speak slowly.',
      'ゆっくり話してください。',
    ),
    (
      '頻度を表す',
      'usually や often は、ふつう一般動詞の前、be動詞のあとに置きます。',
      'I usually walk to work.',
      '私はたいてい歩いて通勤します。',
    ),
    (
      '程度を表す',
      'very や really は形容詞などの前に置き、程度を伝えます。',
      'This soup is really hot.',
      'このスープは本当に熱いです。',
    ),
  ],
};
