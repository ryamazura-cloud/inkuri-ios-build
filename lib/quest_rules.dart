import 'activity.dart';

const questRewardXp = <String, int>{
  'first-step': 10,
  'practice-ten': 30,
  'practice-thirty': 60,
  'review-one': 20,
  'weekly-three': 80,
  'weekly-five': 120,
  'daily-all': 0,
};

const weeklyQuestIds = {'weekly-three', 'weekly-five'};
const ticketQuestIds = {'daily-all', ...weeklyQuestIds};

int rewardForClaim(String key) {
  final parts = key.split('|');
  if (parts.length != 2 || !questRewardXp.containsKey(parts[1])) {
    throw const FormatException('Invalid quest claim');
  }
  final date = parseDay(parts[0]);
  if (weeklyQuestIds.contains(parts[1]) && date.weekday != DateTime.monday) {
    throw const FormatException('Invalid weekly quest date');
  }
  return questRewardXp[parts[1]]!;
}
