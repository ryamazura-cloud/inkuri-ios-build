import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'activity.dart';
import 'domain.dart';
import 'learning_dashboard.dart';

String todayShareText(LearningData data, DateTime now) {
  final today = data.days[dayKey(now)] ?? const DailyActivity();
  return 'インクリで、今日も英語をクリエイト！\n'
      '${dayKey(now)}\n'
      '今日の学習：${today.questions}問\n'
      '学習時間：${studyDuration(today.milliseconds)}\n'
      '連続学習：${currentStreak(data.visits, now)}日\n\n'
      '#インクリ #瞬間英作文 #英語学習\n\n'
      '日本語を見て、2秒で英語を考え始める練習。\n'
      '瞬間英作文アプリ「インクリ」\n'
      'https://encre.wisemap.biz/';
}

class TodayShareCard extends StatelessWidget {
  const TodayShareCard({
    super.key,
    required this.questions,
    required this.onShare,
  });

  final int questions;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFE8F3F0),
      border: Border.all(color: const Color(0xFFD7E4DF)),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Icons.verified_outlined,
              color: Color(0xFF176B61),
              size: 36,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '今日$questions問に挑戦！',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF172F35),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '今日のがんばりを残そう',
                    style: TextStyle(color: Color(0xFF172F35)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF176B61),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
          onPressed: onShare,
          icon: const Icon(Icons.ios_share, size: 20),
          label: const Text(
            '今日の取り組みをシェア',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

/// Render locally from saved activity; no SNS account or network is required.
Future<Uint8List> todayShareImage(LearningData data, DateTime now) async {
  const teal = Color(0xFF176B61), ink = Color(0xFF172F35);
  final today = data.days[dayKey(now)] ?? const DailyActivity();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawColor(const Color(0xFFF6F7F2), BlendMode.src);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(48, 48, 984, 984),
      const Radius.circular(40),
    ),
    Paint()..color = Colors.white,
  );
  void text(
    String value,
    double x,
    double y,
    double size,
    Color color, {
    bool bold = false,
    double width = 850,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontFamily: 'NotoSansJP',
          fontSize: size,
          color: color,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width);
    painter.paint(canvas, Offset(x, y));
    painter.dispose();
  }

  text('インクリ', 96, 90, 42, teal, bold: true);
  text(dayKey(now), 96, 165, 28, ink);
  text('今日の取り組み', 96, 232, 54, ink, bold: true);
  text('${today.questions}', 96, 340, 124, teal, bold: true, width: 520);
  text('問に挑戦！', 100, 510, 44, ink, bold: true);

  final category = data.interests.firstOrNull ?? 'lifestyle';
  final bytes = await rootBundle.load(
    'assets/characters/$category/stage-1.jpg',
  );
  final codec = await ui.instantiateImageCodec(
    bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    targetWidth: 360,
  );
  final frame = await codec.getNextFrame();
  try {
    canvas.drawImageRect(
      frame.image,
      Rect.fromLTWH(
        0,
        0,
        frame.image.width.toDouble(),
        frame.image.height.toDouble(),
      ),
      const Rect.fromLTWH(650, 320, 300, 300),
      Paint(),
    );
  } finally {
    frame.image.dispose();
    codec.dispose();
  }
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(96, 654, 888, 202),
      const Radius.circular(24),
    ),
    Paint()..color = const Color(0xFFE8F3F0),
  );
  text('学習時間　${studyDuration(today.milliseconds)}', 128, 688, 34, ink);
  text('連続学習　${currentStreak(data.visits, now)}日', 128, 768, 34, ink);
  text('今日の一歩が、使える英語に。', 96, 906, 36, teal, bold: true);
  text('#インクリ  #瞬間英作文  #英語学習', 96, 968, 25, ink);
  final picture = recorder.endRecording();
  final image = await picture.toImage(1080, 1080);
  try {
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    if (png == null) throw StateError('Could not render study image');
    return png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
  } finally {
    image.dispose();
    picture.dispose();
  }
}

Future<void> showTodayShare(
  BuildContext context, {
  required LearningData data,
  required DateTime now,
}) async {
  Uint8List? imageBytes;
  try {
    imageBytes = await todayShareImage(data, now);
  } catch (_) {
    // Text sharing remains available if image creation fails on a device.
  }
  if (!context.mounted) return;
  await showSharePreview(
    context,
    title: '今日の取り組みをシェア',
    shareTitle: 'インクリの今日の取り組み',
    text: todayShareText(data, now),
    imageBytes: imageBytes,
  );
}
