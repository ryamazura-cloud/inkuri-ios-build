import 'dart:math' as math;

import 'activity.dart';

class PracticeAllowance {
  const PracticeAllowance({
    this.practiceDay = '',
    this.usedSets = 0,
    this.tickets = 0,
    this.adRewardDay = '',
  });

  static const dailySets = 3;
  static const ticketLimit = 3;

  final String practiceDay;
  final int usedSets;
  final int tickets;
  final String adRewardDay;

  int remaining(DateTime now) =>
      practiceDay == dayKey(now) ? dailySets - usedSets : dailySets;

  bool canWatchAd(DateTime now) =>
      remaining(now) == 0 && tickets == 0 && adRewardDay != dayKey(now);

  PracticeAllowance? startSet(DateTime now) {
    final left = remaining(now);
    if (left == 0 && tickets == 0) return null;
    return PracticeAllowance(
      practiceDay: dayKey(now),
      usedSets: left > 0 ? dailySets - left + 1 : dailySets,
      tickets: left > 0 ? tickets : tickets - 1,
      adRewardDay: adRewardDay,
    );
  }

  PracticeAllowance grantTickets(int amount) => PracticeAllowance(
    practiceDay: practiceDay,
    usedSets: usedSets,
    tickets: math.min(ticketLimit, tickets + amount),
    adRewardDay: adRewardDay,
  );

  PracticeAllowance grantAdTicket(DateTime now) => canWatchAd(now)
      ? PracticeAllowance(
          practiceDay: practiceDay,
          usedSets: usedSets,
          tickets: 1,
          adRewardDay: dayKey(now),
        )
      : this;

  Map<String, Object> toJson() => {
    'practiceDay': practiceDay,
    'usedSets': usedSets,
    'tickets': tickets,
    'adRewardDay': adRewardDay,
  };

  factory PracticeAllowance.fromJson(Object? value) {
    if (value == null) return const PracticeAllowance();
    if (value
        case {
          'practiceDay': final String practiceDay,
          'usedSets': final int usedSets,
          'tickets': final int tickets,
          'adRewardDay': final String adRewardDay,
        }
        when usedSets >= 0 &&
            usedSets <= dailySets &&
            tickets >= 0 &&
            tickets <= ticketLimit) {
      if (practiceDay.isNotEmpty) parseDay(practiceDay);
      if (adRewardDay.isNotEmpty) parseDay(adRewardDay);
      return PracticeAllowance(
        practiceDay: practiceDay,
        usedSets: usedSets,
        tickets: tickets,
        adRewardDay: adRewardDay,
      );
    }
    throw const FormatException('Invalid practice allowance');
  }
}
