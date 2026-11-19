import 'dart:convert';
import 'dart:math';
import 'activity.dart';
import 'interests.dart';
import 'challenge.dart';
import 'quest_rules.dart';
import 'practice_allowance.dart';
import 'level_curve.dart';

const levels = ['初級', '中級', '上級'];
const scenes = ['日常', '旅行', '仕事'];

class AnswerExample {
  const AnswerExample(this.text, {this.explanation = ''});
  final String text, explanation;

  static AnswerExample decode(dynamic raw) {
    if (raw is String) return AnswerExample(raw);
    if (raw is! Map<String, dynamic> ||
        raw['text'] is! String ||
        (raw['explanation'] != null && raw['explanation'] is! String)) {
      throw const FormatException('Invalid answer example');
    }
    return AnswerExample(
      raw['text'] as String,
      explanation: raw['explanation'] as String? ?? '',
    );
  }
}

class Question {
  const Question(
    this.id,
    this.level,
    this.scene,
    this.japanese,
    this.answers,
    this.note, {
    this.topic = '',
    this.category = '',
    this.grammarUnit = '',
  });
  final String id, level, scene, japanese, note;
  final String topic;
  final String category;
  final String grammarUnit;
  bool get isGrammar => grammarUnit.isNotEmpty;
  final List<AnswerExample> answers;

  static List<Question> decode(String source) {
    final root = jsonDecode(source) as Map<String, dynamic>;
    if (root['schemaVersion'] != 1) {
      throw const FormatException('Unsupported question schema');
    }
    final ids = <String>{};
    final result = <Question>[];
    for (final raw in root['questions'] as List) {
      final q = raw as Map<String, dynamic>;
      final id = q['id'] as String;
      final ja = q['japanese'] as String;
      final en = (q['answers'] as List).map(AnswerExample.decode).toList();
      if (q['category'] != null &&
          (q['category'] is! String || !isInterest(q['category'] as String))) {
        throw const FormatException('Unknown question category');
      }
      if (q['topic'] != null && q['topic'] is! String) {
        throw const FormatException('Invalid question topic');
      }
      if (q['grammarUnit'] != null &&
          (q['grammarUnit'] is! String ||
              !RegExp(
                r'^[a-z]+(?:-[a-z]+)*$',
              ).hasMatch(q['grammarUnit'] as String))) {
        throw const FormatException('Invalid grammar unit');
      }
      if (id.trim().isEmpty ||
          !ids.add(id) ||
          !levels.contains(q['level']) ||
          !scenes.contains(q['scene']) ||
          ja.trim().isEmpty ||
          en.isEmpty ||
          en.any((s) => s.text.trim().isEmpty) ||
          en.map((s) => s.text.trim()).toSet().length != en.length) {
        throw FormatException('Invalid question: $id');
      }
      result.add(
        Question(
          id,
          q['level'] as String,
          q['scene'] as String,
          ja,
          en,
          q['note'] as String? ?? '',
          topic: q['topic'] as String? ?? '',
          category: q['category'] as String? ?? '',
          grammarUnit: q['grammarUnit'] as String? ?? '',
        ),
      );
    }
    if (result.isEmpty) throw const FormatException('Empty catalog');
    return List.unmodifiable(result);
  }
}

const defaultReviewGoal = 5;

class ProgressEntry {
  const ProgressEntry({
    required this.attempts,
    required this.successes,
    required this.needsReview,
    required this.lastStudied,
    this.reviewSuccesses = 0,
    this.firstClearDay,
  });
  final int attempts, successes;
  final bool needsReview;
  final int reviewSuccesses;
  final DateTime lastStudied;
  final String? firstClearDay;
  ProgressEntry rated(bool success, DateTime now, int reviewGoal) {
    final progress = needsReview
        ? reviewSuccesses + (success ? 1 : 0)
        : success
        ? reviewSuccesses
        : 0;
    return ProgressEntry(
      attempts: attempts + 1,
      successes: successes + (success ? 1 : 0),
      needsReview: needsReview ? progress < reviewGoal : !success,
      lastStudied: now,
      reviewSuccesses: progress,
      firstClearDay:
          firstClearDay ?? (success && successes == 0 ? dayKey(now) : null),
    );
  }

  ProgressEntry _applyReviewGoal(int goal) =>
      needsReview && reviewSuccesses >= goal
      ? ProgressEntry(
          attempts: attempts,
          successes: successes,
          needsReview: false,
          lastStudied: lastStudied,
          reviewSuccesses: reviewSuccesses,
          firstClearDay: firstClearDay,
        )
      : this;
  Map<String, Object> toJson() => {
    'attempts': attempts,
    'successes': successes,
    'needsReview': needsReview,
    if (reviewSuccesses != 0) 'reviewSuccesses': reviewSuccesses,
    'lastStudied': lastStudied.toIso8601String(),
    if (firstClearDay != null) 'firstClearDay': firstClearDay!,
  };
}

class LearningData {
  LearningData([
    Map<String, ProgressEntry>? entries,
    Map<String, DailyActivity>? days,
    Set<String>? visits,
    List<String>? interests,
    Map<String, ChallengePass>? challengePasses,
    Map<String, int>? reviewDays,
    Set<String>? questClaims,
    this.levelXpOffset = 0,
    this.reviewGoal = defaultReviewGoal,
    this.allowance = const PracticeAllowance(),
    Map<int, String>? levelUpDays,
  ]) : entries = Map.unmodifiable(entries ?? {}),
       days = Map.unmodifiable(days ?? {}),
       visits = Set.unmodifiable(visits ?? {}),
       interests = List.unmodifiable(interests ?? []),
       challengePasses = Map.unmodifiable(challengePasses ?? {}),
       reviewDays = Map.unmodifiable(reviewDays ?? {}),
       questClaims = Set.unmodifiable(questClaims ?? {}),
       levelUpDays = Map.unmodifiable(levelUpDays ?? {});
  final Map<String, ProgressEntry> entries;
  final Map<String, DailyActivity> days;
  final Set<String> visits;
  final List<String> interests;
  final Map<String, ChallengePass> challengePasses;
  final Map<String, int> reviewDays;
  final Set<String> questClaims;
  // Preserves the legacy level without adding to earned EXP.
  final int levelXpOffset;
  final int reviewGoal;
  final PracticeAllowance allowance;
  final Map<int, String> levelUpDays;
  int get earnedXp =>
      entries.values.fold<int>(
        0,
        (sum, entry) =>
            sum + entry.successes * 10 + (entry.attempts - entry.successes) * 5,
      ) +
      questClaims.fold<int>(0, (sum, key) => sum + rewardForClaim(key));
  LearningData withInterests(List<String> selected) => LearningData(
    entries,
    days,
    visits,
    validateInterests(selected),
    challengePasses,
    reviewDays,
    questClaims,
    levelXpOffset,
    reviewGoal,
    allowance,
    levelUpDays,
  );
  LearningData visit(DateTime now) => LearningData(
    entries,
    days,
    {...visits, dayKey(now)},
    interests,
    challengePasses,
    reviewDays,
    questClaims,
    levelXpOffset,
    reviewGoal,
    allowance,
    levelUpDays,
  );
  LearningData addTime(Map<String, int> elapsed) {
    final next = Map<String, DailyActivity>.of(days);
    for (final entry in elapsed.entries) {
      parseDay(entry.key);
      if (entry.value < 0) throw ArgumentError('Negative study time');
      next[entry.key] = (next[entry.key] ?? const DailyActivity()).plus(
        milliseconds: entry.value,
      );
    }
    return LearningData(
      entries,
      next,
      visits,
      interests,
      challengePasses,
      reviewDays,
      questClaims,
      levelXpOffset,
      reviewGoal,
      allowance,
      levelUpDays,
    );
  }

  LearningData rate(String id, bool success, DateTime now) {
    final old =
        entries[id] ??
        ProgressEntry(
          attempts: 0,
          successes: 0,
          needsReview: false,
          lastStudied: now,
        );
    final key = dayKey(now);
    return LearningData(
      {...entries, id: old.rated(success, now, reviewGoal)},
      {...days, key: (days[key] ?? const DailyActivity()).plus(questions: 1)},
      {...visits, key},
      interests,
      challengePasses,
      old.needsReview
          ? {...reviewDays, key: (reviewDays[key] ?? 0) + 1}
          : reviewDays,
      questClaims,
      levelXpOffset,
      reviewGoal,
      allowance,
      levelUpDays,
    );
  }

  LearningData finishChallenge(
    String category,
    String level,
    int score,
    int total,
    DateTime now,
  ) {
    final key = challengeKey(category, level);
    if (total < 1 || total > 5 || score < 0 || score > total) {
      throw ArgumentError('Invalid challenge score');
    }
    if (score < eightyPercent(total) || challengePasses.containsKey(key)) {
      return this;
    }
    return LearningData(
      entries,
      days,
      visits,
      interests,
      {...challengePasses, key: ChallengePass(score, total, now)},
      reviewDays,
      questClaims,
      levelXpOffset,
      reviewGoal,
      allowance,
      levelUpDays,
    );
  }

  LearningData withQuestClaim(String key) {
    rewardForClaim(key);
    return LearningData(
      entries,
      days,
      visits,
      interests,
      challengePasses,
      reviewDays,
      {...questClaims, key},
      levelXpOffset,
      reviewGoal,
      allowance,
      levelUpDays,
    );
  }

  LearningData withReviewGoal(int goal) {
    if (goal < 1) throw ArgumentError.value(goal, 'goal');
    if (goal == reviewGoal) return this;
    return LearningData(
      entries.map((id, entry) => MapEntry(id, entry._applyReviewGoal(goal))),
      days,
      visits,
      interests,
      challengePasses,
      reviewDays,
      questClaims,
      levelXpOffset,
      goal,
      allowance,
      levelUpDays,
    );
  }

  LearningData withAllowance(PracticeAllowance value) => LearningData(
    entries,
    days,
    visits,
    interests,
    challengePasses,
    reviewDays,
    questClaims,
    levelXpOffset,
    reviewGoal,
    value,
    levelUpDays,
  );

  LearningData recordLevelUps(int previous, int current, DateTime now) =>
      LearningData(
        entries,
        days,
        visits,
        interests,
        challengePasses,
        reviewDays,
        questClaims,
        levelXpOffset,
        reviewGoal,
        allowance,
        {
          ...levelUpDays,
          for (var level = previous + 1; level <= current; level++)
            level: levelUpDays[level] ?? dayKey(now),
        },
      );

  String encode() => jsonEncode({
    'schemaVersion': 1,
    if (allowance.practiceDay.isNotEmpty ||
        allowance.tickets != 0 ||
        allowance.adRewardDay.isNotEmpty)
      'practiceAllowance': allowance.toJson(),
    'levelBalanceVersion': 3,
    'levelXpOffset': levelXpOffset,
    if (levelUpDays.isNotEmpty)
      'levelUpDays': levelUpDays.map((level, day) => MapEntry('$level', day)),
    if (reviewGoal != defaultReviewGoal) 'reviewGoal': reviewGoal,
    'entries': entries.map((key, value) => MapEntry(key, value.toJson())),
    'days': days.map((key, value) => MapEntry(key, value.toJson())),
    'visits': visits.toList()..sort(),
    'interests': interests,
    'challengePasses': challengePasses.map(
      (key, value) => MapEntry(key, value.toJson()),
    ),
    if (reviewDays.isNotEmpty) 'reviewDays': reviewDays,
    if (questClaims.isNotEmpty) 'questClaims': questClaims.toList()..sort(),
  });
  static LearningData decode(String source) {
    final root = jsonDecode(source) as Map<String, dynamic>;
    if (root['schemaVersion'] != 1) {
      throw const FormatException('Unsupported progress schema');
    }
    final reviewGoal = root['reviewGoal'] ?? defaultReviewGoal;
    if (reviewGoal is! int || reviewGoal < 1) {
      throw const FormatException('Invalid review goal');
    }
    final result = <String, ProgressEntry>{};
    for (final e in (root['entries'] as Map<String, dynamic>).entries) {
      final v = e.value as Map<String, dynamic>;
      final attempts = v['attempts'] as int;
      final successes = v['successes'] as int;
      final needsReview = v['needsReview'];
      final reviewSuccesses = v['reviewSuccesses'] ?? 0;
      if (attempts < 1 || successes < 0 || successes > attempts) {
        throw const FormatException('Invalid counters');
      }
      if (needsReview is! bool ||
          reviewSuccesses is! int ||
          reviewSuccesses < 0 ||
          reviewSuccesses > successes ||
          (needsReview && reviewSuccesses >= reviewGoal)) {
        throw const FormatException('Invalid review progress');
      }
      final lastStudied = DateTime.parse(v['lastStudied'] as String);
      final firstClearDay = v['firstClearDay'] as String?;
      if (firstClearDay != null) {
        parseDay(firstClearDay);
        if (successes == 0) throw const FormatException('Invalid first clear');
      }
      result[e.key] = ProgressEntry(
        attempts: attempts,
        successes: successes,
        needsReview: needsReview,
        reviewSuccesses: reviewSuccesses,
        lastStudied: lastStudied,
        firstClearDay: firstClearDay,
      );
    }
    final days = <String, DailyActivity>{};
    for (final entry
        in ((root['days'] ?? <String, dynamic>{}) as Map<String, dynamic>)
            .entries) {
      parseDay(entry.key);
      days[entry.key] = DailyActivity.decode(
        entry.value as Map<String, dynamic>,
      );
    }
    final visits = <String>{};
    for (final key in ((root['visits'] ?? <String>[]) as List)) {
      parseDay(key as String);
      visits.add(key);
    }
    final passes = <String, ChallengePass>{};
    final rawPasses = root['challengePasses'] ?? <String, dynamic>{};
    if (rawPasses is! Map<String, dynamic>) {
      throw const FormatException('Invalid challenge passes');
    }
    for (final e in rawPasses.entries) {
      final parts = e.key.split('|');
      if (parts.length != 2 || challengeKey(parts[0], parts[1]) != e.key) {
        throw const FormatException('Invalid challenge key');
      }
      passes[e.key] = ChallengePass.decode(e.value);
    }
    final reviewDays = <String, int>{};
    final rawReviews = root['reviewDays'] ?? <String, dynamic>{};
    if (rawReviews is! Map<String, dynamic>) {
      throw const FormatException('Invalid review days');
    }
    for (final entry in rawReviews.entries) {
      parseDay(entry.key);
      if (entry.value is! int ||
          (entry.value as int) < 0 ||
          (entry.value as int) > (days[entry.key]?.questions ?? 0)) {
        throw const FormatException('Invalid review count');
      }
      reviewDays[entry.key] = entry.value as int;
    }
    final claims = <String>{};
    final rawClaims = root['questClaims'] ?? <String>[];
    if (rawClaims is! List) throw const FormatException('Invalid quest claims');
    for (final key in rawClaims) {
      if (key is! String || !claims.add(key)) {
        throw const FormatException('Repeated or invalid quest claim');
      }
      rewardForClaim(key);
    }
    final hasBalance = root.containsKey('levelBalanceVersion');
    final balanceVersion = root['levelBalanceVersion'];
    final savedOffset = root['levelXpOffset'];
    if ((hasBalance &&
            ((balanceVersion != 2 && balanceVersion != 3) ||
                savedOffset is! int ||
                (balanceVersion == 2 && savedOffset < 0))) ||
        (!hasBalance && root.containsKey('levelXpOffset'))) {
      throw const FormatException('Invalid level balance');
    }
    final levelUpDays = <int, String>{};
    final rawLevelUpDays = root['levelUpDays'] ?? <String, dynamic>{};
    if (rawLevelUpDays is! Map<String, dynamic>) {
      throw const FormatException('Invalid level history');
    }
    for (final entry in rawLevelUpDays.entries) {
      final level = int.tryParse(entry.key);
      final day = entry.value;
      if (level == null ||
          level < 2 ||
          '$level' != entry.key ||
          day is! String) {
        throw const FormatException('Invalid level history entry');
      }
      parseDay(day);
      levelUpDays[level] = day;
    }
    final earnedXp =
        result.values.fold<int>(
          0,
          (sum, e) => sum + e.successes * 10 + (e.attempts - e.successes) * 5,
        ) +
        claims.fold<int>(0, (sum, key) => sum + rewardForClaim(key));
    final savedLevelXp =
        earnedXp + (hasBalance ? savedOffset as int : earnedXp * 2);
    if (savedLevelXp < 0) throw const FormatException('Invalid level EXP');
    final levelXp = balanceVersion == 3
        ? savedLevelXp
        : migrateLevelXp(savedLevelXp);
    return LearningData(
      result,
      days,
      visits,
      validateInterests(root['interests']),
      passes,
      reviewDays,
      claims,
      levelXp - earnedXp,
      reviewGoal,
      PracticeAllowance.fromJson(root['practiceAllowance']),
      levelUpDays,
    );
  }
}

String categoryForQuestion(Question question) {
  if (question.category.isNotEmpty) return question.category;
  // Existing records stay byte-for-byte unchanged; their IDs determine stable legacy categories.
  if (question.scene == '旅行') return 'travel';
  if (question.scene == '仕事') return 'business';
  const legacy = <String, String>{
    'daily-b-025': 'health',
    'daily-b-026': 'health',
    'daily-i-025': 'health',
    'daily-i-026': 'health',
    'daily-a-025': 'health',
    'daily-a-026': 'health',
    'daily-b-030': 'entertainment',
    'daily-i-028': 'entertainment',
    'daily-b-003': 'food',
    'daily-b-008': 'fashion',
    'daily-b-011': 'fashion',
    'daily-i-006': 'fashion',
  };
  return legacy[question.id] ?? 'lifestyle';
}

List<Question> selectInterestQuestions(
  List<Question> catalog,
  String category, {
  String? level,
}) => catalog
    .where(
      (q) =>
          !q.isGrammar &&
          categoryForQuestion(q) == category &&
          (level == null || q.level == level),
    )
    .toList();

List<Question> selectQuestions(
  List<Question> catalog,
  LearningData data, {
  String? level,
  String? scene,
  bool reviewOnly = false,
}) => catalog
    .where(
      (q) =>
          (level == null || q.level == level) &&
          (scene == null || q.scene == scene) &&
          (!reviewOnly || (data.entries[q.id]?.needsReview ?? false)),
    )
    .toList();

List<Question> createSession(
  List<Question> candidates, {
  Random? random,
  int limit = 10,
}) {
  final copy = [...candidates]..shuffle(random);
  return copy.take(limit).toList(growable: false);
}
