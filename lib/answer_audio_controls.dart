import 'package:flutter/material.dart';

import 'speech.dart';

class AnswerAudioControls extends StatelessWidget {
  const AnswerAudioControls({
    super.key,
    required this.speech,
    required this.text,
    required this.enabled,
    required this.showSpeed,
  });

  final SpeechController speech;
  final String text;
  final bool enabled, showSpeed;

  String _time(Duration time) =>
      '${time.inMinutes}:${(time.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final active = speech.activeText == text;
    final canPause = speech.playback != null;
    final ready = enabled && !speech.preparing;
    final label = !active
        ? '音声を再生'
        : speech.preparing
        ? '音声を準備中'
        : speech.paused
        ? 'つづきから再生'
        : canPause
        ? '一時停止'
        : '音声を停止';
    final icon = !active
        ? Icons.volume_up_outlined
        : speech.paused
        ? Icons.play_arrow
        : canPause
        ? Icons.pause
        : Icons.stop;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: ready ? () => speech.toggle(text) : null,
              icon: Icon(icon),
              label: Text(label),
            ),
            if (active && canPause)
              OutlinedButton.icon(
                onPressed: ready ? () => speech.restart(text) : null,
                icon: const Icon(Icons.replay),
                label: const Text('最初から'),
              ),
          ],
        ),
        if (active && canPause && speech.duration > Duration.zero) ...[
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value:
                (speech.position.inMilliseconds /
                        speech.duration.inMilliseconds)
                    .clamp(0.0, 1.0)
                    .toDouble(),
            semanticsLabel: '音声の再生位置',
          ),
          Text('${_time(speech.position)} / ${_time(speech.duration)}'),
        ],
        if (canPause && showSpeed) ...[
          const SizedBox(height: 8),
          const Text('再生速度', style: TextStyle(fontWeight: FontWeight.w600)),
          Wrap(
            spacing: 6,
            children: [
              for (final rate in [0.75, 1.0, 1.25])
                ChoiceChip(
                  selected: speech.rate == rate,
                  label: Text('$rate×'),
                  onSelected: ready ? (_) => speech.setRate(rate) : null,
                ),
            ],
          ),
        ],
      ],
    );
  }
}
