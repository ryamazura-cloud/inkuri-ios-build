import 'dart:math' as math;
import 'domain.dart';
import 'interests.dart';
import 'challenge.dart';
import 'course_levels.dart';
import 'stages.dart';
import 'level_curve.dart';

class AdventurerRole {
  const AdventurerRole(this.minLevel, this.title);
  final int minLevel;
  final String title;
}

const adventurerRoles = [
  AdventurerRole(1, 'ことばの旅人'),
  AdventurerRole(5, '会話の見習い'),
  AdventurerRole(10, 'フレーズの使い手'),
  AdventurerRole(15, '対話の冒険者'),
  AdventurerRole(20, '表現の騎士'),
  AdventurerRole(30, 'ことばの魔導士'),
  AdventurerRole(40, '会話の賢者'),
  AdventurerRole(50, '世界をつなぐ語り部'),
  AdventurerRole(60, 'ことばの大魔導士'),
  AdventurerRole(70, '対話の導き手'),
  AdventurerRole(80, '世界を結ぶ賢者'),
  AdventurerRole(90, 'ことばの英雄'),
  AdventurerRole(100, '伝説のことばの創造主'),
];

/// Saved ratings plus claimed quest rewards; upgrading retains all earned EXP.
class GrowthProgress {
  GrowthProgress(LearningData data)
    : xp = data.earnedXp,
      _levelXp = data.earnedXp + data.levelXpOffset;
  final int xp;
  final int _levelXp;
  static int threshold(int level) => levelThreshold(level);

  int get level => levelForXp(_levelXp);

  int get current => _levelXp - threshold(level);
  int get required => threshold(level + 1) - threshold(level);
  int get remaining => threshold(level + 1) - _levelXp;
  double get fraction => current / required;
  AdventurerRole get role =>
      adventurerRoles.lastWhere((r) => level >= r.minLevel);
  AdventurerRole? get nextRole {
    final index = adventurerRoles.indexOf(role) + 1;
    return index < adventurerRoles.length ? adventurerRoles[index] : null;
  }

  String get title => role.title;
  String titleFor(AdventurerRole candidate) =>
      level >= candidate.minLevel ? candidate.title : hiddenTitle;
}

class LearningSkill {
  const LearningSkill({
    required this.scene,
    required this.level,
    required this.total,
    required this.cleared,
    required this.unlocked,
    this.categoryId,
    this.challengePassed = false,
  });
  final String scene, level;
  final int total, cleared;
  final bool unlocked;
  final String? categoryId;
  final bool challengePassed;
  int get challengeGoal => eightyPercent(total);
  int get challengeCount => math.min(5, total);
  bool get challengeUnlocked =>
      unlocked && total > 0 && (challengePassed || cleared >= challengeGoal);
  int get firstGoal => math.min(5, (total / 3).ceil());
  int get secondGoal => math.min(
    total,
    math.min(15, math.max(firstGoal + 1, (total * 2 / 3).ceil())),
  );
  int get rank => total == 0
      ? 0
      : cleared >= total
      ? 3
      : cleared >= secondGoal
      ? 2
      : cleared >= firstGoal
      ? 1
      : 0;
  int get nextGoal => rank == 0
      ? firstGoal
      : rank == 1
      ? secondGoal
      : total;
  String get displayLabel => isCourseLevel(level)
      ? 'レベル${courseLevel(level).number} ${unlocked ? courseLevel(level, category: categoryId).name : hiddenTitle}'
      : level;
  String get name => isCourseLevel(level)
      ? '$scene・$displayLabel'
      : level == '初級'
      ? '$sceneの第一歩'
      : level == '中級'
      ? '$sceneの広がり'
      : '$sceneの挑戦';
}

List<LearningSkill> interestSkills(List<Question> catalog, LearningData data) {
  final result = <LearningSkill>[];
  for (final category in data.interests) {
    final groups = categoryStages(catalog, category);
    var unlocked = true;
    for (final stage in courseLevels) {
      final level = stage.key;
      final questions = groups[level]!;
      final cleared = questions
          .where((q) => (data.entries[q.id]?.successes ?? 0) > 0)
          .length;
      final skill = LearningSkill(
        scene: interestLabel(category),
        categoryId: category,
        level: level,
        total: questions.length,
        cleared: cleared,
        unlocked: unlocked && questions.isNotEmpty,
        challengePassed: data.challengePasses.containsKey(
          challengeKey(category, level),
        ),
      );
      result.add(skill);
      unlocked = skill.unlocked && skill.challengePassed;
    }
  }
  return result;
}

List<LearningSkill> learningSkills(List<Question> catalog, LearningData data) {
  final result = <LearningSkill>[];
  for (final scene in scenes) {
    var unlocked = true;
    for (final level in levels) {
      final questions = catalog
          .where((q) => !q.isGrammar && q.scene == scene && q.level == level)
          .toList();
      final cleared = questions
          .where((q) => (data.entries[q.id]?.successes ?? 0) > 0)
          .length;
      final skill = LearningSkill(
        scene: scene,
        level: level,
        total: questions.length,
        cleared: cleared,
        unlocked: (unlocked || cleared > 0) && questions.isNotEmpty,
      );
      result.add(skill);
      unlocked = skill.total > 0 && cleared >= math.min(5, skill.total);
    }
  }
  return result;
}
