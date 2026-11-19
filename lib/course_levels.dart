const hiddenTitle = '？？？';

class CourseLevel {
  const CourseLevel(this.key, this.name, this.number);
  final String key, name;
  final int number;
  String get label => 'レベル$number $name';
}

// Keys and order are persistent progression IDs; titles are presentation only.
const courseLevels = [
  CourseLevel('stage-1', '見習い', 1),
  CourseLevel('stage-2', '探究者', 2),
  CourseLevel('stage-3', '使い手', 3),
  CourseLevel('stage-4', '導き手', 4),
  CourseLevel('stage-5', '達人', 5),
];

const categoryTitles = <String, List<String>>{
  'beauty': ['美容初心者', '彩りの使い手', '美肌の案内人', '輝きの仕立て屋', '美の錬金術師'],
  'health': ['からだの探究者', '元気の応援団', '健やかの案内人', 'いのちの守り手', '健康の賢者'],
  'food': ['食べ盛り', '味の探検家', '香りの料理人', '美食の伝道師', '食卓の魔術師'],
  'fashion': ['おしゃれの卵', '装いの冒険者', '着こなしの職人', '流行の仕掛け人', '装いの創造主'],
  'entertainment': ['推し活の新人', '話題の追い人', 'エンタメ通', '熱狂の仕掛け人', '舞台裏の賢者'],
  'lifestyle': ['家事勉強中', '日々の工夫家', '心地よさの職人', '暮らしの演出家', '日常の錬金術師'],
  'parenting': ['見守りの芽', '笑顔の応援団', '子育ての伴走者', '安心の守り手', '家族の太陽'],
  'learning': ['学びの旅人', '知識の収集家', 'ひらめきの使い手', '知恵の探究者', '学びの大賢者'],
  'relationships': ['ときめきの旅人', '心の聞き上手', '想いの橋渡し', '絆の紡ぎ手', '愛の語り部'],
  'pets': ['もふもふ見習い', 'しっぽの友だち', 'お世話の達人', '心をつなぐ相棒', 'どうぶつの賢者'],
  'games': ['物語の旅人', 'クエストの挑戦者', 'コンボの使い手', '世界を渡る勇者', '伝説の冒険王'],
  'business': ['新入社員', '段取りの使い手', '交渉の戦略家', 'チームの導き手', '未来の開拓者'],
  'travel': ['旅じたく中', '街角の探検家', '国境を渡る旅人', '世界の案内人', '七つの海の冒険家'],
  'cars': ['ドライブ見習い', '街道の旅人', 'ハンドルの職人', '大地の探検家', '走りのマイスター'],
  'gadgets': ['スイッチの見習い', '便利の発見者', 'ガジェット使い', '電脳の探検家', '未来の発明家'],
  'sports': ['ウォームアップ隊員', '挑戦の走り出し', '技の磨き手', '勝利の戦略家', '限界を超える覇者'],
  'money': ['コツコツ見習い', '家計の守り手', 'お金の計画家', '資産の航海士', '未来を築く賢者'],
};
CourseLevel courseLevel(String key, {String? category}) {
  final stage = courseLevels.singleWhere((s) => s.key == key);
  final titles = categoryTitles[category];
  return titles == null
      ? stage
      : CourseLevel(stage.key, titles[stage.number - 1], stage.number);
}

bool isCourseLevel(String key) => courseLevels.any((s) => s.key == key);
