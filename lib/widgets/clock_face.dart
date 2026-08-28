import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../design/theme.dart';
import '../l10n/strings.dart';
import '../services/haptics.dart';

/// The clock.
///
/// Time pressure is carried by brass, contrast and rhythm - never by a red
/// clock. Crimson is spoken for: it means one person, the spy.
///
/// Only the digits rebuild, never the screen. The value is always derived from
/// the wall clock upstream, so this widget cannot drift.
class ClockFace extends StatefulWidget {
  const ClockFace({
    required this.remaining,
    required this.total,
    required this.label,
    required this.paused,
    required this.hapticsInLastTen,
    super.key,
  });

  final ValueListenable<Duration> remaining;
  final Duration total;

  /// "7 players · 2 spies · Places" - the round's shape, readable at a metre.
  final String label;

  final bool paused;
  final bool hapticsInLastTen;

  @override
  State<ClockFace> createState() => _ClockFaceState();
}

class _ClockFaceState extends State<ClockFace> with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  int _lastSecond = -1;

  /// A screen reader that announced every second would make the app unusable.
  /// These four are the only ones worth interrupting for.
  static const _announceAt = {300, 60, 30, 0};
  final _announced = <int>{};

  @override
  void initState() {
    super.initState();
    widget.remaining.addListener(_onTick);
  }

  @override
  void dispose() {
    widget.remaining.removeListener(_onTick);
    _breath.dispose();
    super.dispose();
  }

  void _onTick() {
    if (!mounted) return;
    final seconds = widget.remaining.value.inSeconds;
    if (seconds == _lastSecond) return;
    _lastSecond = seconds;

    if (seconds <= 60 && seconds > 0 && !context.reducedMotion) {
      // The digits breathe once on the second. Under a minute only.
      _breath.forward(from: 0).then((_) {
        if (mounted) _breath.reverse();
      });
    }
    if (seconds <= 10 && seconds > 0 && widget.hapticsInLastTen) {
      SpyHaptics.tick();
    }
    if (_announceAt.contains(seconds) && _announced.add(seconds)) {
      final s = SpyStrings.of(context);
      SemanticsService.sendAnnouncement(
        View.of(context),
        s.a11yTimeLeft(s.clockTime(widget.remaining.value)),
        Directionality.of(context),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spy;
    final t = context.type;
    final s = SpyStrings.of(context);
    final density = context.density;

    final size = switch (density) {
      SpyDensity.compact => 60.0,
      SpyDensity.standard => t.clock.fontSize!,
      SpyDensity.wide => 92.0,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ValueListenableBuilder<Duration>(
          valueListenable: widget.remaining,
          builder: (context, remaining, _) {
            final isLate = remaining.inSeconds <= 60;
            final text = s.clockTime(remaining);
            final parts = text.split(':');
            // The colon steps on a 1 s step function, never a smooth fade.
            final colonOn = widget.paused ||
                remaining.inMilliseconds % 1000 >= 500;

            return AnimatedBuilder(
              animation: _breath,
              builder: (context, child) => Transform.scale(
                scale: 1 + 0.02 * _breath.value,
                child: child,
              ),
              child: ExcludeSemantics(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: parts.first),
                      TextSpan(
                        text: ':',
                        style: TextStyle(
                          color: (isLate ? c.accent : c.text)
                              .withValues(alpha: colonOn ? 1.0 : 0.25),
                        ),
                      ),
                      TextSpan(text: parts.last),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  // The clock face does not mirror.
                  textDirection: TextDirection.ltr,
                  style: t.clock.copyWith(
                    fontSize: size,
                    color: isLate ? c.accent : c.text,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: SpyPrimitives.s4),
        Text(
          t.uppercases ? widget.label.toUpperCase() : widget.label,
          textAlign: TextAlign.center,
          style: t.file.copyWith(color: c.textFaint, fontSize: 10),
        ),
        const SizedBox(height: SpyPrimitives.s5),
        _ProgressRule(remaining: widget.remaining, total: widget.total),
      ],
    );
  }
}

/// Drains from the leading edge - the right edge in Persian. It does not
/// mirror its direction of travel, because time does not.
class _ProgressRule extends StatelessWidget {
  const _ProgressRule({required this.remaining, required this.total});

  final ValueListenable<Duration> remaining;
  final Duration total;

  @override
  Widget build(BuildContext context) {
    final c = context.spy;
    return SizedBox(
      height: 3,
      child: ValueListenableBuilder<Duration>(
        valueListenable: remaining,
        builder: (context, value, _) {
          final fraction = total.inMilliseconds == 0
              ? 0.0
              : (value.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
          return ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Stack(
              children: [
                Positioned.fill(child: ColoredBox(color: c.surfaceSunken)),
                FractionallySizedBox(
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: fraction,
                  child: ColoredBox(color: c.accent),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
