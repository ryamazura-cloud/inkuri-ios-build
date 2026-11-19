import 'interests.dart';
import 'course_levels.dart';

int eightyPercent(int total) => (total * 4 + 4) ~/ 5;

String challengeKey(String category, String level) {
  if (!isInterest(category) ||
      (!isCourseLevel(level) && !['初級', '中級', '上級'].contains(level))) {
    throw const FormatException('Invalid challenge course');
  }
  return '$category|$level';
}

class ChallengePass {
  const ChallengePass(this.score, this.total, this.passedAt);
  final int score, total;
  final DateTime passedAt;
  Map<String, Object> toJson() => {
    'score': score,
    'total': total,
    'passedAt': passedAt.toIso8601String(),
  };
  static ChallengePass decode(dynamic raw) {
    if (raw is! Map ||
        raw['score'] is! int ||
        raw['total'] is! int ||
        raw['passedAt'] is! String) {
      throw const FormatException('Invalid challenge pass');
    }
    final score = raw['score'] as int, total = raw['total'] as int;
    if (total < 1 ||
        total > 5 ||
        score < eightyPercent(total) ||
        score > total) {
      throw const FormatException('Invalid challenge score');
    }
    return ChallengePass(
      score,
      total,
      DateTime.parse(raw['passedAt'] as String),
    );
  }
}
