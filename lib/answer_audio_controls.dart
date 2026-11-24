import 'package:flutter/material.dart';

import 'speech.dart';

class AnswerAudioControls extends StatelessWidget {
  const AnswerAudioControls({
    super.key,
    required this.speech,
    required this.text,
    required this.enabled,
  });

  final SpeechController speech;
  final String text;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF176B61);
    final active = speech.activeText == text;
    final canPause = speech.playback != null;
    final playing = active && !speech.paused && !speech.preparing;
    final ready = enabled && !speech.preparing;
    final (icon, label) = switch ((
      playing,
      active,
      speech.preparing,
      canPause,
    )) {
      (true, _, _, true) => (Icons.pause_rounded, '一時停止'),
      (true, _, _, false) => (Icons.stop_rounded, '音声を停止'),
      (_, true, true, _) => (Icons.hourglass_empty, '音声を準備中'),
      (_, true, false, _) => (Icons.play_arrow_rounded, 'つづきから再生'),
      _ => (Icons.play_arrow_rounded, '音声を再生'),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: label,
          style: IconButton.styleFrom(
            backgroundColor: playing ? teal : const Color(0xFFE0EEE6),
            foregroundColor: playing ? Colors.white : teal,
            minimumSize: const Size.square(44),
            visualDensity: VisualDensity.compact,
          ),
          onPressed: ready ? () => speech.toggle(text) : null,
          icon: Icon(icon, size: 21),
        ),
        if (canPause) ...[
          const SizedBox(width: 4),
          PopupMenuButton<double>(
            tooltip: '再生速度',
            position: PopupMenuPosition.under,
            enabled: ready,
            initialValue: speech.rate,
            onSelected: speech.setRate,
            itemBuilder: (_) => [
              for (final rate in const [0.75, 1.0, 1.25])
                PopupMenuItem(
                  value: rate,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 24,
                        child: rate == speech.rate
                            ? const Icon(Icons.check, color: teal, size: 17)
                            : null,
                      ),
                      Text(rate.toString() + '×'),
                    ],
                  ),
                ),
            ],
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    speech.rate.toString() + '×',
                    style: const TextStyle(
                      color: teal,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Icon(Icons.expand_more, size: 15, color: teal),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class AnswerAudioProgress extends StatelessWidget {
  const AnswerAudioProgress({
    super.key,
    required this.speech,
    required this.text,
    required this.enabled,
  });

  final SpeechController speech;
  final String text;
  final bool enabled;

  String _time(Duration time) =>
      '${time.inMinutes}:${(time.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    if (speech.activeText != text ||
        speech.playback == null ||
        speech.duration <= Duration.zero) {
      return const SizedBox.shrink();
    }
    final fraction =
        speech.position.inMilliseconds / speech.duration.inMilliseconds;
    return Row(
      children: [
        Expanded(
          child: LinearProgressIndicator(
            value: fraction.clamp(0.0, 1.0).toDouble(),
            semanticsLabel: '音声の再生位置',
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Text(
            _time(speech.position) + ' / ' + _time(speech.duration),
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
        IconButton(
          tooltip: '最初から',
          onPressed: enabled ? () => speech.restart(text) : null,
          icon: const Icon(Icons.replay, size: 19),
        ),
      ],
    );
  }
}
