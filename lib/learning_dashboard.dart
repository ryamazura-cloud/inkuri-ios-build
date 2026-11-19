import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'activity.dart';
import 'achievements.dart';
import 'domain.dart';

const _teal = Color(0xFF176B61);

Future<void> showStudyShare(BuildContext context, List<PeriodTotal> totals) =>
    showSharePreview(
      context,
      title: '学習記録を共有',
      shareTitle: 'インクリの学習記録',
      text: shareSummary(totals),
    );

Future<void> showSharePreview(
  BuildContext context, {
  required String title,
  required String shareTitle,
  required String text,
  Uint8List? imageBytes,
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imageBytes != null) ...[
              Image.memory(imageBytes, semanticLabel: '今日の取り組みの共有画像'),
              const SizedBox(height: 16),
            ],
            SelectableText(text),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('閉じる'),
        ),
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: text));
            if (dialogContext.mounted) {
              ScaffoldMessenger.of(
                dialogContext,
              ).showSnackBar(const SnackBar(content: Text('共有文をコピーしました')));
            }
          },
          child: const Text('コピー'),
        ),
        Builder(
          builder: (buttonContext) => FilledButton.icon(
            onPressed: () async {
              final box = buttonContext.findRenderObject() as RenderBox?;
              try {
                await SharePlus.instance.share(
                  ShareParams(
                    text: text,
                    title: shareTitle,
                    files: imageBytes == null
                        ? null
                        : [XFile.fromData(imageBytes, mimeType: 'image/png')],
                    fileNameOverrides: imageBytes == null
                        ? null
                        : ['inkuri-study.png'],
                    sharePositionOrigin: box == null
                        ? null
                        : box.localToGlobal(Offset.zero) & box.size,
                  ),
                );
              } catch (_) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('共有先を開けませんでした。「コピー」からも共有できます。'),
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.ios_share),
            label: const Text('共有先を選ぶ'),
          ),
        ),
      ],
    ),
  );
}

class LearningDashboard extends StatefulWidget {
  const LearningDashboard({
    super.key,
    required this.data,
    required this.catalog,
    required this.now,
    this.tutorialChartKey,
  });
  final LearningData data;
  final List<Question> catalog;
  final DateTime now;
  final GlobalKey? tutorialChartKey;
  @override
  State<LearningDashboard> createState() => _LearningDashboardState();
}

class _LearningDashboardState extends State<LearningDashboard> {
  bool monthly = false;
  int badgePage = 0;
  static const badgesPerPage = 8;
  int offset = 0;
  @override
  Widget build(BuildContext context) {
    final totals = recentTotals(widget.data.days, widget.now);
    final anchor = monthly
        ? DateTime(widget.now.year, widget.now.month + offset * 12)
        : DateTime(
            widget.now.year,
            widget.now.month,
            widget.now.day + offset * 14,
          );
    final points = chartPeriods(widget.data.days, anchor, monthly: monthly);
    final badges = achievements(widget.data);
    final pageCount = (badges.length / badgesPerPage).ceil();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('学習の推移', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('日別'),
              selected: !monthly,
              onSelected: (_) => setState(() {
                monthly = false;
                offset = 0;
              }),
            ),
            ChoiceChip(
              label: const Text('月別'),
              selected: monthly,
              onSelected: (_) => setState(() {
                monthly = true;
                offset = 0;
              }),
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              tooltip: '前の期間',
              onPressed: () => setState(() => offset--),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                '${dayKey(points.first.start)} 〜 ${dayKey(DateTime(points.last.end.year, points.last.end.month, points.last.end.day - 1))}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            IconButton(
              tooltip: '次の期間',
              onPressed: offset < 0 ? () => setState(() => offset++) : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        Padding(
          key: widget.tutorialChartKey,
          padding: EdgeInsets.zero,
          child: ActivityChart(
            key: ValueKey('combined-$monthly-$offset'),
            points: points,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          '日別・月別の問題数と時間は、この機能の追加後から記録します。過去の学習回数は累計に残ります。日付の列をタップすると両方の値を確認できます。',
          style: TextStyle(fontSize: 12, height: 1.7),
        ),
        const SizedBox(height: 28),
        Text('今日も、一歩ずつ。', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        for (final total in totals)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  total.label,
                  style: const TextStyle(
                    color: _teal,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 24,
                  runSpacing: 8,
                  children: [
                    Text(
                      '学習問題数  ${total.questions}問',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text('学習時間  ${studyDuration(total.milliseconds)}'),
                  ],
                ),
              ],
            ),
          ),
        const Text(
          '問題数は自己評価した回数です（繰り返しを含みます）。学習時間は問題画面の表示中のみ計測し、背景・終了確認・保存待ちは除きます。週は月曜始まりです。',
          style: TextStyle(fontSize: 12, height: 1.7),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => showStudyShare(context, totals),
          icon: const Icon(Icons.ios_share),
          label: const Text('学習記録を共有'),
        ),
        const SizedBox(height: 28),
        Text(
          'バッジ  ${badges.where((b) => b.earned).length} / ${badges.length}',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          '現在 ${currentStreak(widget.data.visits, widget.now)}日連続  /  最長 ${bestStreak(widget.data.visits)}日連続',
          style: const TextStyle(color: _teal, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        const Text(
          'ログイン不要。アプリを開いた日を「起動日」として記録します。継続バッジは最長連続日数で判定し、クリアバッジは同じ問題を何度解いても1問です。',
          style: TextStyle(fontSize: 12, height: 1.7),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: '前のバッジページ',
              onPressed: badgePage == 0
                  ? null
                  : () => setState(() => badgePage--),
              icon: const Icon(Icons.chevron_left),
            ),
            Text('${badgePage + 1} / $pageCount'),
            IconButton(
              tooltip: '次のバッジページ',
              onPressed: badgePage + 1 == pageCount
                  ? null
                  : () => setState(() => badgePage++),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        for (final badge
            in badges.skip(badgePage * badgesPerPage).take(badgesPerPage))
          _badgeCard(badge),
      ],
    );
  }

  Widget _badgeCard(Achievement badge) {
    final date = badge.earnedDay == null ? null : parseDay(badge.earnedDay!);
    final status = badge.earned
        ? date == null
              ? '獲得済み・達成日不明'
              : '達成日 ${date.year}年${date.month}月${date.day}日'
        : '${badge.value} / ${badge.goal}';
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(top: 8),
      color: badge.earned ? const Color(0xFFE4EDE7) : const Color(0xFFECEEE8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              badge.earned
                  ? (badge.isVisit
                        ? Icons.local_fire_department_rounded
                        : Icons.workspace_premium_rounded)
                  : Icons.lock_outline,
              color: badge.earned ? _teal : Colors.grey,
              semanticLabel: badge.earned ? '獲得済み' : '未獲得',
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    badge.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(badge.description, style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    status,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ActivityChart extends StatefulWidget {
  const ActivityChart({super.key, required this.points});
  final List<PeriodTotal> points;
  @override
  State<ActivityChart> createState() => _ActivityChartState();
}

class _ActivityChartState extends State<ActivityChart> {
  int? selected;
  final _scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    final maxQuestions = math.max(
      1,
      points.map((p) => p.questions).reduce(math.max),
    );
    final maxMinutes = math.max(
      1.0,
      points.map((p) => p.milliseconds / 60000).reduce(math.max),
    );
    final index = (selected ?? points.length - 1).clamp(0, points.length - 1);
    final point = points[index];
    final textScale = MediaQuery.textScalerOf(context).scale(12) / 12;
    final labelHeight = 44.0 * math.max(1.0, textScale);
    final questions = points.fold<int>(0, (sum, p) => sum + p.questions);
    final milliseconds = points.fold<int>(0, (sum, p) => sum + p.milliseconds);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '学習問題数と学習時間',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              Text('▰ 問題数（棒・左軸）', style: TextStyle(color: _teal, fontSize: 12)),
              Text(
                '● 時間（折れ線・右軸）',
                style: TextStyle(color: _timeColor, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '期間合計  $questions問 / ${studyDuration(milliseconds)}',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 8),
          const Text(
            '左右の軸は別の目盛りです。',
            style: TextStyle(fontSize: 11, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          const Text(
            '左右にスクロール・日付をタップして詳細を表示',
            style: TextStyle(fontSize: 11, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _axis([
                '$maxQuestions問',
                (maxQuestions / 2).toStringAsFixed(1),
                '0',
              ]),
              Expanded(
                child: Scrollbar(
                  controller: _scroll,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _scroll,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(bottom: 14),
                    child: SizedBox(
                      width: math.max(
                        points.length * 64.0 * math.max(1.0, textScale),
                        MediaQuery.sizeOf(context).width - 220,
                      ),
                      height: 158 + labelHeight,
                      child: Stack(
                        children: [
                          Positioned(
                            left: 0,
                            right: 0,
                            top: 0,
                            height: 150,
                            child: CustomPaint(
                              painter: _StudyPainter(
                                points,
                                maxQuestions,
                                maxMinutes,
                                index,
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              for (var i = 0; i < points.length; i++)
                                Expanded(
                                  child: Semantics(
                                    button: true,
                                    selected: i == index,
                                    label:
                                        '${_periodLabel(points[i])}、${points[i].questions}問、${studyDuration(points[i].milliseconds)}',
                                    child: Tooltip(
                                      message:
                                          '${_periodLabel(points[i])}：${points[i].questions}問 / ${studyDuration(points[i].milliseconds)}',
                                      child: InkWell(
                                        onTap: () =>
                                            setState(() => selected = i),
                                        child: Column(
                                          children: [
                                            const SizedBox(height: 158),
                                            Container(
                                              height: labelHeight,
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 2,
                                                  ),
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                color: i == index
                                                    ? const Color(0xFFE8F3F0)
                                                    : null,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                points[i].end
                                                            .difference(
                                                              points[i].start,
                                                            )
                                                            .inDays >
                                                        1
                                                    ? '${points[i].start.month}月'
                                                    : '${points[i].start.day}\n${const ['月', '火', '水', '木', '金', '土', '日'][points[i].start.weekday - 1]}',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  height: 1.4,
                                                  color: i == index
                                                      ? _teal
                                                      : const Color(0xFF37474F),
                                                  fontWeight: i == index
                                                      ? FontWeight.w700
                                                      : FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              _axis([
                '${maxMinutes.toStringAsFixed(1)}分',
                (maxMinutes / 2).toStringAsFixed(1),
                '0',
              ]),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${_periodLabel(point)}：${point.questions}問 / ${studyDuration(point.milliseconds)}',
            style: const TextStyle(fontSize: 12),
            semanticsLabel:
                '選択した期間 ${_periodLabel(point)}、${point.questions}問、${studyDuration(point.milliseconds)}',
          ),
          if (questions == 0 && milliseconds == 0)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'この期間の記録はまだありません。',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
        ],
      ),
    );
  }

  Widget _axis(List<String> labels) => SizedBox(
    width: 44,
    height: 150,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final label in labels)
          FittedBox(child: Text(label, style: const TextStyle(fontSize: 10))),
      ],
    ),
  );

  String _periodLabel(PeriodTotal point) =>
      point.end.difference(point.start).inDays > 1
      ? '${point.start.year}年${point.start.month}月'
      : '${point.start.year}年${point.start.month}月${point.start.day}日（${const ['月', '火', '水', '木', '金', '土', '日'][point.start.weekday - 1]}）';
}

const _timeColor = Color(0xFFB56336);

class _StudyPainter extends CustomPainter {
  _StudyPainter(this.points, this.maxQuestions, this.maxMinutes, this.selected);
  final List<PeriodTotal> points;
  final int maxQuestions, selected;
  final double maxMinutes;
  @override
  void paint(Canvas canvas, Size size) {
    // Inset data marks so zero dots and maximum dots stay inside the plot.
    const inset = 5.0;
    final height = size.height - 2 * inset;
    final step = size.width / points.length;
    final grid = Paint()
      ..color = const Color(0xFFE4E8E3)
      ..strokeWidth = 1;
    for (final fraction in [0.0, 0.5, 1.0]) {
      final y = inset + height * fraction;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final line = Path();
    final dots = <Offset>[];
    for (var i = 0; i < points.length; i++) {
      final x = step * (i + 0.5);
      final barHeight = points[i].questions / maxQuestions * height;
      if (barHeight > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x - 8, inset + height - barHeight, 16, barHeight),
            const Radius.circular(4),
          ),
          Paint()..color = i == selected ? _teal : const Color(0xFF84B7A3),
        );
      }
      final dot = Offset(
        x,
        inset + height - (points[i].milliseconds / 60000 / maxMinutes) * height,
      );
      dots.add(dot);
      if (i == 0) {
        line.moveTo(dot.dx, dot.dy);
      } else {
        line.lineTo(dot.dx, dot.dy);
      }
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = _timeColor
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );
    for (var i = 0; i < dots.length; i++) {
      canvas.drawCircle(
        dots[i],
        i == selected ? 4 : 2.5,
        Paint()..color = _timeColor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StudyPainter oldDelegate) => true;
}
