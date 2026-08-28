import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/theme.dart';
import '../services/haptics.dart';

/// The spy's name, landing like a case stamp.
///
/// The only bouncy thing in the product, and the only place `eStamp` appears in
/// the codebase - grep for it in review. Every stamp lands at its own angle so
/// a row of them reads as a hand slapping ink on paper rather than as the same
/// asset pasted twice.
class VerdictStamp extends StatefulWidget {
  const VerdictStamp({
    required this.name,
    required this.index,
    super.key,
  });

  final String name;

  /// Seeds the tilt, and staggers the landings.
  final int index;

  @override
  State<VerdictStamp> createState() => _VerdictStampState();
}

class _VerdictStampState extends State<VerdictStamp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: SpyPrimitives.dStamp,
  );

  /// The angle this stamp lands at, in radians.
  ///
  /// Hashed from the name and the position rather than drawn from a
  /// [math.Random]: a stamp that re-tilts on every rebuild - a theme change, a
  /// rotation, a rebuilt route - is a wobble, not a stamp. Same spy, same
  /// angle, every time; two spies, two different angles.
  late final double _tilt = _tiltFor(widget.name, widget.index);

  static double _tiltFor(String name, int index) {
    // FNV-1a over the name, seeded with the position so two players called
    // the same thing still land differently.
    var h = 0x811C9DC5 ^ (index * 0x9E3779B1);
    for (final unit in name.codeUnits) {
      h = ((h ^ unit) * 0x01000193) & 0x7FFFFFFF;
    }
    // Under about 2 degrees it looks like a printing error rather than a
    // stamp; over about 9 it looks like a mistake. Both signs, either way.
    final magnitude = 2.0 + (h % 701) / 100;
    final sign = (h >> 11).isEven ? -1 : 1;
    return sign * magnitude * math.pi / 180;
  }

  @override
  void initState() {
    super.initState();
    // Late, after the word has landed - it is the punchline, not the setup.
    Future.delayed(
      SpyPrimitives.dVerdict + Duration(milliseconds: 120 * widget.index),
      () {
        if (!mounted) return;
        SpyHaptics.stamp();
        _controller.forward();
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spy;
    final t = context.type;

    final stamp = Container(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 5, 14, 4),
      decoration: BoxDecoration(
        border: Border.all(color: c.spy, width: 3),
        borderRadius: BorderRadius.circular(SpyPrimitives.rXs),
      ),
      child: Text(
        // A name, as typed. Never uppercased, even here.
        widget.name,
        style: t.title.copyWith(
          color: c.spy,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
        maxLines: 2,
        textAlign: TextAlign.center,
      ),
    );

    // Reduced motion: it appears at final size and keeps the haptic.
    if (context.reducedMotion) {
      return Opacity(
        opacity: 0.92,
        child: Transform.rotate(angle: _tilt, child: stamp),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final v = SpyPrimitives.eStamp.transform(
          _controller.value.clamp(0.0, 1.0),
        );
        return Opacity(
          opacity: (_controller.value * 3).clamp(0.0, 0.92),
          child: Transform.rotate(
            angle: _tilt,
            child: Transform.scale(scale: 1.35 - 0.35 * v, child: child),
          ),
        );
      },
      child: stamp,
    );
  }
}
