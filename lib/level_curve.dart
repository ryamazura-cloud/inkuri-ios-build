import 'dart:math' as math;

const levelStepXp = 40;
const previousLevelStepXp = 75;
const _firstLevelXp = 150;

int levelThreshold(int level, {int stepXp = levelStepXp}) {
  if (level < 1) throw ArgumentError.value(level, 'level');
  final steps = level - 1;
  return _firstLevelXp * steps + stepXp * steps * (steps - 1) ~/ 2;
}

int levelForXp(int xp, {int stepXp = levelStepXp}) {
  final linear = 2 * _firstLevelXp - stepXp;
  var level =
      ((math.sqrt(linear * linear + 8.0 * stepXp * xp) - linear) / (2 * stepXp))
          .floor() +
      1;
  while (levelThreshold(level + 1, stepXp: stepXp) <= xp) {
    level++;
  }
  while (levelThreshold(level, stepXp: stepXp) > xp) {
    level--;
  }
  return level;
}

/// Converts the old progress bar without changing the earned level or title.
int migrateLevelXp(int previousXp) {
  final level = levelForXp(previousXp, stepXp: previousLevelStepXp);
  final oldStart = levelThreshold(level, stepXp: previousLevelStepXp);
  final oldRequired =
      levelThreshold(level + 1, stepXp: previousLevelStepXp) - oldStart;
  final newStart = levelThreshold(level);
  final newRequired = levelThreshold(level + 1) - newStart;
  return newStart + (previousXp - oldStart) * newRequired ~/ oldRequired;
}
