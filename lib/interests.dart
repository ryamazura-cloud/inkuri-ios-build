class InterestCategory {
  const InterestCategory(this.id, this.label);
  final String id, label;
}

const interestCategories = [
  InterestCategory('beauty', '美容/コスメ'),
  InterestCategory('health', '健康/医療'),
  InterestCategory('food', 'グルメ/料理'),
  InterestCategory('fashion', 'ファッション'),
  InterestCategory('entertainment', 'エンタメ/芸能'),
  InterestCategory('lifestyle', 'ライフスタイル'),
  InterestCategory('parenting', '出産/育児'),
  InterestCategory('learning', '学び/資格'),
  InterestCategory('relationships', '恋愛/結婚'),
  InterestCategory('pets', 'ペット'),
  InterestCategory('games', 'ゲーム/アニメ'),
  InterestCategory('business', 'ビジネス/経済'),
  InterestCategory('travel', '旅行/観光'),
  InterestCategory('cars', '自動車'),
  InterestCategory('gadgets', '家電/ガジェット'),
  InterestCategory('sports', 'スポーツ'),
  InterestCategory('money', '金融/マネー'),
];

bool isInterest(String id) => interestCategories.any((c) => c.id == id);
String interestLabel(String id) =>
    interestCategories.singleWhere((c) => c.id == id).label;

List<String> validateInterests(dynamic raw) {
  if (raw == null) return const [];
  if (raw is! List ||
      raw.any((value) => value is! String || !isInterest(value))) {
    throw const FormatException('Invalid interests');
  }
  if (raw.toSet().length != raw.length) {
    throw const FormatException('Repeated interest');
  }
  return List<String>.from(raw);
}
