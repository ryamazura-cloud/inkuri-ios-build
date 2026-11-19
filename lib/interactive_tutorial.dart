import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

class TutorialWhenReady extends StatefulWidget {
  const TutorialWhenReady({
    super.key,
    required this.child,
    required this.onReady,
  });
  final Widget child;
  final Future<void> Function(BuildContext) onReady;
  @override
  State<TutorialWhenReady> createState() => _TutorialWhenReadyState();
}

class _TutorialWhenReadyState extends State<TutorialWhenReady> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(widget.onReady(context));
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class TutorialSpot {
  const TutorialSpot(this.key, this.value, this.label, {this.fraction});
  final GlobalKey key;
  final String value, label;
  final Rect? fraction;
}

/// Each tap closes the coach before the caller invokes the real screen action.
/// No simulated ratings, progress or interests are inserted by the guide.
class InteractiveTutorial {
  bool canceled = false;

  Future<String?> point(
    BuildContext context, {
    required String title,
    required String description,
    required List<TutorialSpot> spots,
    String? nextLabel,
    double alignment = .15,
  }) async {
    if (canceled || !context.mounted) return null;
    final animation = ModalRoute.of(context)?.animation;
    if (animation != null && animation.status == AnimationStatus.forward) {
      final ready = Completer<void>();
      void changed(AnimationStatus status) {
        if ((status == AnimationStatus.completed ||
                status == AnimationStatus.dismissed) &&
            !ready.isCompleted) {
          ready.complete();
        }
      }

      animation.addStatusListener(changed);
      try {
        await ready.future;
      } finally {
        animation.removeStatusListener(changed);
      }
    }
    if (!context.mounted) return null;
    await WidgetsBinding.instance.endOfFrame;
    if (!context.mounted) return null;
    final target = spots.first.key.currentContext;
    if (target == null) {
      canceled = true;
      return null;
    }
    await Scrollable.ensureVisible(
      target,
      alignment: alignment,
      duration: const Duration(milliseconds: 200),
    );
    if (!context.mounted) return null;
    final answer = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: Duration.zero,
      pageBuilder: (ctx, _, _) => _Coach(
        title: title,
        description: description,
        spots: spots,
        nextLabel: nextLabel,
      ),
    );
    if (answer == null) canceled = true;
    return answer;
  }
}

class _Coach extends StatelessWidget {
  const _Coach({
    required this.title,
    required this.description,
    required this.spots,
    this.nextLabel,
  });
  final String title, description;
  final List<TutorialSpot> spots;
  final String? nextLabel;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) Navigator.pop(context);
    },
    child: Material(
      type: MaterialType.transparency,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final screen = Offset.zero & constraints.biggest;
          final targets = <(TutorialSpot, Rect)>[];
          for (final spot in spots) {
            final box = spot.key.currentContext?.findRenderObject();
            if (box is! RenderBox || !box.hasSize || !box.attached) continue;
            var rect = box.localToGlobal(Offset.zero) & box.size;
            final part = spot.fraction;
            if (part != null) {
              rect = Rect.fromLTWH(
                rect.left + rect.width * part.left,
                rect.top + rect.height * part.top,
                rect.width * part.width,
                rect.height * part.height,
              );
            }
            rect = rect.inflate(5).intersect(screen.deflate(4));
            if (!rect.isEmpty) targets.add((spot, rect));
          }
          final bounds = targets.isEmpty
              ? Rect.zero
              : targets.map((t) => t.$2).reduce((a, b) => a.expandToInclude(b));
          final insets = MediaQuery.paddingOf(context);
          final belowSpace = screen.height - bounds.bottom - insets.bottom;
          final aboveSpace = bounds.top - insets.top;
          final below = targets.isEmpty || belowSpace >= aboveSpace;
          final panelHeight = math.min(
            screen.height * .45,
            math.max(100.0, (below ? belowSpace : aboveSpace) - 24),
          );
          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _Spotlight(targets.map((t) => t.$2).toList()),
                ),
              ),
              // Block unrelated controls while preserving explicitly guided actions.
              const Positioned.fill(
                child: ModalBarrier(
                  color: Colors.transparent,
                  dismissible: false,
                ),
              ),
              for (final (spot, rect) in targets)
                Positioned.fromRect(
                  rect: rect,
                  child: Semantics(
                    button: true,
                    label: '${spot.label}をタップ',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.pop(context, spot.value),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              Positioned(
                left: 12,
                right: 12,
                top: below ? null : MediaQuery.paddingOf(context).top + 12,
                bottom: below
                    ? MediaQuery.paddingOf(context).bottom + 12
                    : null,
                child: Material(
                  color: const Color(0xFFF1F7F1),
                  borderRadius: BorderRadius.circular(20),
                  elevation: 8,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: panelHeight),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        '操作ガイド',
                                        style: TextStyle(
                                          color: Color(0xFF176B61),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('スキップ'),
                                    ),
                                  ],
                                ),
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  description,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    height: 1.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                          child: SizedBox(
                            width: double.infinity,
                            child: nextLabel != null || targets.isEmpty
                                ? FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(context, 'next'),
                                    child: Text(nextLabel ?? '次へ'),
                                  )
                                : const Text(
                                    '枠で囲まれたところをタップしてください。',
                                    style: TextStyle(
                                      color: Color(0xFF176B61),
                                      fontSize: 12,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _Spotlight extends CustomPainter {
  _Spotlight(this.targets);
  final List<Rect> targets;
  @override
  void paint(Canvas canvas, Size size) {
    final shade = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size);
    for (final rect in targets) {
      shade.addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)));
    }
    canvas.drawPath(
      shade,
      Paint()..color = Colors.black.withValues(alpha: .62),
    );
    for (final rect in targets) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(12)),
        Paint()
          ..color = const Color(0xFFCFE999)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
  }

  @override
  bool shouldRepaint(_Spotlight oldDelegate) => oldDelegate.targets != targets;
}
