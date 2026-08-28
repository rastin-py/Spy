import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// The nine icons that cover the whole app.
///
/// Outline only, on a 24 grid with a 1.75 stroke and round caps - a filled icon
/// beside an outline one reads as "selected". There is no icon for anything
/// that already has a word, which is why the list stops at nine.
enum SpyIconData { settings, back, clock, sound, muted, haptic, spy, redact, again }

class SpyIcon extends StatelessWidget {
  const SpyIcon(this.icon, {this.size = 24, this.color, this.semanticLabel, super.key});

  final SpyIconData icon;
  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? DefaultTextStyle.of(context).style.color!;
    // `back` is the one glyph that mirrors; the rest are direction-neutral.
    final flip = icon == SpyIconData.back &&
        Directionality.of(context) == TextDirection.rtl;
    Widget painted = CustomPaint(
      size: Size.square(size),
      painter: _SpyIconPainter(icon, resolved, size),
    );
    if (flip) {
      painted = Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()..scaleByDouble(-1, 1, 1, 1),
        child: painted,
      );
    }
    return semanticLabel == null
        ? painted
        : Semantics(label: semanticLabel, child: painted);
  }
}

class _SpyIconPainter extends CustomPainter {
  const _SpyIconPainter(this.icon, this.color, this.size);

  final SpyIconData icon;
  final Color color;
  final double size;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final scale = canvasSize.width / 24;
    canvas.save();
    canvas.scale(scale);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.75
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (icon) {
      case SpyIconData.settings:
        // A gear with eight teeth, cut rather than suggested. Eight ticks
        // radiating off a circle is a sun, or a brightness control - it is not
        // a settings icon, whatever the spacing.
        {
          const teeth = 8;
          const step = 2 * math.pi / teeth;
          // Half the angular width of a tooth, and the angle the diagonal
          // flank eats on each side of it. Together they set how deep the
          // valleys cut - equal arc lengths top and bottom at these radii.
          const toothHalf = 0.13;
          const flank = 0.11;
          const centre = Offset(12, 12);
          final crown = Rect.fromCircle(center: centre, radius: 9.1);
          final valley = Rect.fromCircle(center: centre, radius: 6.5);

          final gear = Path();
          for (var i = 0; i < teeth; i++) {
            final at = i * step;
            // The tooth, then the gap. `forceMoveTo: false` draws the line
            // between them, which is the flank.
            gear.arcTo(crown, at - toothHalf, toothHalf * 2, i == 0);
            gear.arcTo(
              valley,
              at + toothHalf + flank,
              step - 2 * (toothHalf + flank),
              false,
            );
          }
          // The closing line is the last flank.
          gear.close();
          canvas.drawPath(gear, stroke);
          canvas.drawCircle(centre, 3.1, stroke);
        }
      case SpyIconData.back:
        canvas.drawPath(
          Path()
            ..moveTo(15, 4)
            ..lineTo(7, 12)
            ..lineTo(15, 20),
          stroke,
        );
      case SpyIconData.clock:
        canvas.drawCircle(const Offset(12, 12), 9, stroke);
        canvas.drawPath(
          Path()
            ..moveTo(12, 7)
            ..lineTo(12, 12)
            ..lineTo(15.5, 14),
          stroke,
        );
      case SpyIconData.sound:
        canvas.drawPath(_speakerBody(), stroke);
        // one arc - the second would make it a broadcast tower
        canvas.drawArc(
          Rect.fromCircle(center: const Offset(15.4, 12), radius: 2.6),
          -math.pi / 3,
          2 * math.pi / 3,
          false,
          stroke,
        );
      case SpyIconData.muted:
        canvas.drawPath(_speakerBody(), stroke);
        canvas.drawLine(const Offset(17, 10), const Offset(21, 14), stroke);
        canvas.drawLine(const Offset(21, 10), const Offset(17, 14), stroke);
      case SpyIconData.haptic:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(7, 3, 10, 18),
            const Radius.circular(2),
          ),
          stroke,
        );
        canvas.drawLine(const Offset(3.5, 9), const Offset(3.5, 15), stroke);
        canvas.drawLine(const Offset(20.5, 9), const Offset(20.5, 15), stroke);
      case SpyIconData.spy:
        // Spectacles over a brim: a redaction wearing a disguise, not a fedora.
        canvas.drawLine(const Offset(3, 11), const Offset(21, 11), stroke);
        canvas.drawCircle(const Offset(7.5, 14.5), 3, stroke);
        canvas.drawCircle(const Offset(16.5, 14.5), 3, stroke);
        canvas.drawPath(
          Path()
            ..moveTo(9, 8.5)
            ..lineTo(12, 6)
            ..lineTo(15, 8.5),
          stroke,
        );
      case SpyIconData.redact:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(3, 10, 18, 5),
            const Radius.circular(1),
          ),
          stroke,
        );
        // the ascender escaping above the bar - the mark, at icon size
        canvas.drawPath(
          Path()
            ..moveTo(9.5, 10)
            ..lineTo(9.5, 7)
            ..arcToPoint(const Offset(14.5, 7),
                radius: const Radius.circular(2.5), clockwise: true)
            ..lineTo(14.5, 10),
          stroke,
        );
      case SpyIconData.again:
        canvas.drawArc(
          Rect.fromCircle(center: const Offset(12, 12), radius: 8),
          -math.pi / 5,
          1.75 * math.pi,
          false,
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(20, 4)
            ..lineTo(20, 9)
            ..lineTo(15, 9),
          stroke,
        );
    }
    canvas.restore();
  }

  Path _speakerBody() => Path()
    ..moveTo(4, 9)
    ..lineTo(4, 15)
    ..lineTo(8, 15)
    ..lineTo(13, 19)
    ..lineTo(13, 5)
    ..lineTo(8, 9)
    ..close();

  @override
  bool shouldRepaint(_SpyIconPainter old) =>
      old.icon != icon || old.color != color || old.size != size;
}

/// The identity mark: a brass redaction bar with the ascender of a hidden
/// letter escaping above it. Never rotated, never crimson, never over a photo.
class SpyMark extends StatelessWidget {
  const SpyMark({required this.color, this.size = 32, super.key});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(size),
        painter: _MarkPainter(color),
      );
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 32);
    final fill = Paint()..color = color;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(6, 13, 20, 6),
        const Radius.circular(1),
      ),
      fill,
    );
    canvas.drawPath(
      Path()
        ..moveTo(13, 13)
        ..lineTo(13, 9.5)
        ..arcToPoint(const Offset(19, 9.5),
            radius: const Radius.circular(3), clockwise: true)
        ..lineTo(19, 13),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.color != color;
}
