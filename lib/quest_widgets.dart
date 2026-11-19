import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'activity.dart';
import 'domain.dart';
import 'growth.dart';
import 'quests.dart';

class QuestReceipt {
  const QuestReceipt(this.xp, this.before, this.after, {this.tickets = 0});
  final int tickets;
  final int xp;
  final GrowthProgress before, after;
}

class HomeLearningActions extends StatelessWidget {
  const HomeLearningActions({
    super.key,
    required this.weakCount,
    required this.claimable,
    required this.onReview,
    required this.onQuests,
    this.reviewKey,
  });
  final int weakCount, claimable;
  final VoidCallback? onReview;
  final VoidCallback onQuests;
  final GlobalKey? reviewKey;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final review = FilledButton.icon(
        key: reviewKey,
        onPressed: onReview,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF176B61),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFE1E8E5),
          disabledForegroundColor: const Color(0xFF687A77),
        ),
        icon: const Icon(Icons.replay),
        label: Text('復習（$weakCount問）'),
      );
      final quests = OutlinedButton.icon(
        onPressed: onQuests,
        icon: Badge(
          isLabelVisible: claimable > 0,
          label: Text('$claimable'),
          child: const Icon(Icons.emoji_events_outlined),
        ),
        label: const Text('クエスト'),
      );
      if (constraints.maxWidth < 340 ||
          MediaQuery.textScalerOf(context).scale(14) > 18) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [review, const SizedBox(height: 6), quests],
        );
      }
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 3, child: review),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: quests),
          ],
        ),
      );
    },
  );
}

class QuestPage extends StatefulWidget {
  const QuestPage({
    super.key,
    required this.data,
    required this.onClaim,
    this.ticketsEnabled = false,
    this.now,
  });
  final LearningData Function() data;
  final Future<QuestReceipt> Function(String key) onClaim;
  final bool ticketsEnabled;
  final DateTime Function()? now;
  @override
  State<QuestPage> createState() => _QuestPageState();
}

class _QuestPageState extends State<QuestPage> with WidgetsBindingObserver {
  bool busy = false;
  Timer? timer;
  late String currentDay;
  DateTime get now => (widget.now ?? DateTime.now)();
  @override
  void initState() {
    super.initState();
    currentDay = dayKey(now);
    WidgetsBinding.instance.addObserver(this);
    timer = Timer.periodic(const Duration(seconds: 30), (_) => _refreshDay());
  }

  void _refreshDay() {
    if (mounted && currentDay != dayKey(now)) {
      setState(() => currentDay = dayKey(now));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() => currentDay = dayKey(now));
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _claim(LearningQuest quest) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final receipt = await widget.onClaim(quest.key);
      if (!mounted) return;
      setState(() {});
      if (receipt.xp > 0 || receipt.tickets > 0) {
        await showDialog<void>(
          context: context,
          builder: (context) => _QuestCelebration(receipt: receipt),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('この報酬は受け取り済みです。')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('報酬を受け取れませんでした。日付と保存状態を確認して、もう一度お試しください。'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          currentDay = dayKey(now);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data(), date = now;
    final quests = learningQuests(
      data,
      date,
      ticketsEnabled: widget.ticketsEnabled,
    );
    final learningDays = studiedDays(data, date);
    final streak = currentStreak(learningDays, date);
    final week = questWeekStart(date);
    final growth = GrowthProgress(data);
    return Scaffold(
      appBar: AppBar(title: const Text('クエスト')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              '小さな一歩が、次のレベルへ。',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text('冒険も修行も、復習も。取り組んだ分だけクエストが進みます。達成したら報酬を受け取りましょう。'),
            const SizedBox(height: 16),
            Text(
              '共通 Lv. ${growth.level} ・ 累計 ${growth.xp} EXP',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFE4EDE7),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '今週の冒険　${date.month}月${date.day}日',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) => Wrap(
                      spacing: 6,
                      runSpacing: 8,
                      children: [
                        for (var i = 0; i < 7; i++)
                          _DayStamp(
                            width:
                                MediaQuery.textScalerOf(context).scale(14) > 18
                                ? 44
                                : ((constraints.maxWidth - 36) / 7)
                                      .clamp(28, 40)
                                      .toDouble(),
                            label: ['月', '火', '水', '木', '金', '土', '日'][i],
                            studied: learningDays.contains(
                              dayKey(
                                DateTime(week.year, week.month, week.day + i),
                              ),
                            ),
                            today:
                                dayKey(
                                  DateTime(week.year, week.month, week.day + i),
                                ) ==
                                dayKey(date),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    streak > 0
                        ? '$streak日連続で学習中。今日も一歩ずつ！'
                        : '1問学ぶと、今日の冒険に足あとがつきます。',
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '休んだ日があっても、獲得したEXPや役職はそのままです。',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '今日のクエスト',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            for (final quest in quests.where((q) => !q.weekly))
              _questCard(quest),
            const SizedBox(height: 16),
            const Text(
              '週間クエスト',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            for (final quest in quests.where((q) => q.weekly))
              _questCard(quest),
            const SizedBox(height: 16),
            const Text(
              '正解できた数ではなく、自己評価まで取り組んだ回数で進みます。報酬は各クエストにつき期間内に1回。日替わりは午前0時、週間は月曜日に切り替わります。復習の回数はこの機能の追加後から記録します。',
              style: TextStyle(fontSize: 13, height: 1.7),
            ),
          ],
        ),
      ),
    );
  }

  Widget _questCard(LearningQuest quest) {
    final hasTicket = widget.ticketsEnabled && quest.awardsTicket;
    final balanceFull = quest.ticketBalanceFull(
      widget.data(),
      ticketsEnabled: widget.ticketsEnabled,
    );
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 12,
              runSpacing: 6,
              children: [
                Text(
                  quest.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (quest.reward > 0)
                  Text(
                    '+${quest.reward} EXP',
                    style: const TextStyle(
                      color: Color(0xFF176B61),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (hasTicket) const Text('追加練習チケット +1枚'),
              ],
            ),
            const SizedBox(height: 8),
            Text(quest.description),
            if (quest.id == 'review-one' &&
                quest.value == 0 &&
                !widget.ticketsEnabled) ...[
              const SizedBox(height: 6),
              const Text(
                '復習する問題がない日は、ほかのクエストだけで大丈夫です。',
                style: TextStyle(fontSize: 12),
              ),
            ],
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: quest.fraction,
              minHeight: 7,
              borderRadius: BorderRadius.circular(5),
            ),
            const SizedBox(height: 8),
            Text(
              '${math.min(quest.value, quest.goal)} / ${quest.goal}${quest.weekly
                  ? '日'
                  : quest.id == 'daily-all'
                  ? '件'
                  : '問'}',
            ),
            if (quest.claimable && balanceFull)
              const Text('チケットが満杯です。1枚使うと報酬を受け取れます。'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: busy || !quest.claimable || balanceFull
                  ? null
                  : () => _claim(quest),
              icon: Icon(
                quest.claimed
                    ? Icons.check_circle_outline
                    : Icons.redeem_outlined,
              ),
              label: Text(
                quest.claimed
                    ? '受け取り済み'
                    : quest.complete
                    ? '報酬を受け取る'
                    : '学習して挑戦',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayStamp extends StatelessWidget {
  const _DayStamp({
    required this.label,
    required this.studied,
    required this.today,
    required this.width,
  });
  final String label;
  final bool studied, today;
  final double width;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label曜日 ${studied ? '学習済み' : 'これから'}${today ? ' 今日' : ''}',
    child: Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: studied ? const Color(0xFF176B61) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: today
            ? Border.all(color: const Color(0xFFB78026), width: 2)
            : null,
      ),
      child: Column(
        children: [
          Icon(
            studied ? Icons.auto_awesome : Icons.circle_outlined,
            size: 19,
            color: studied ? Colors.white : Colors.grey,
          ),
          Text(
            label,
            style: TextStyle(color: studied ? Colors.white : Colors.black87),
          ),
        ],
      ),
    ),
  );
}

class _QuestCelebration extends StatelessWidget {
  const _QuestCelebration({required this.receipt});
  final QuestReceipt receipt;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('クエスト達成！'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: .6, end: 1),
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutBack,
            builder: (_, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: const Icon(
              Icons.emoji_events_rounded,
              size: 72,
              color: Color(0xFFB78026),
            ),
          ),
          const SizedBox(height: 16),
          if (receipt.xp > 0)
            Text(
              '+${receipt.xp} EXP',
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
            ),
          const SizedBox(height: 12),
          Text(
            receipt.after.level > receipt.before.level
                ? 'レベルアップ！ Lv. ${receipt.before.level} → Lv. ${receipt.after.level}'
                : '共通 Lv. ${receipt.after.level} ・ 次のレベルまであと ${receipt.after.remaining} EXP',
          ),
          const SizedBox(height: 8),
          Text('役職：${receipt.after.title}'),
          if (receipt.tickets > 0) Text('追加練習チケット +${receipt.tickets}枚'),
          const SizedBox(height: 12),
          const Text('今日の一歩が、ことばの力になります。'),
        ],
      ),
    ),
    actions: [
      FilledButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('冒険を続ける'),
      ),
    ],
  );
}
