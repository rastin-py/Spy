import 'package:flutter/material.dart';

import '../design/theme.dart';

/// The signature interaction.
///
/// Zero by default, always. Dragging burns the word through the redaction slab
/// 1:1 with the thumb - no easing, because easing would make the thumb feel
/// like it is dragging the word behind it. The moment the thumb is released it
/// springs back to zero and the word seals over 140 ms.
///
/// That asymmetry *is* the security model: revealing is directly manipulated,
/// hiding is automatic and fast. A slider that held its position would mean a
/// phone handed across the table with a word still on screen - the one failure
/// this app cannot recover from.
///
/// The documented exception is switch access, TalkBack/VoiceOver and keyboards:
/// there the value holds until focus leaves the card, because arrow keys and
/// swipe-adjust have no "release". [onFocusLost] is how the card seals it.
class RevealSlider extends StatelessWidget {
  const RevealSlider({
    required this.value,
    required this.onChanged,
    required this.onReleased,
    required this.focusNode,
    required this.semanticLabel,
    required this.formatValue,
    super.key,
  });

  /// 0..1.
  final double value;

  final ValueChanged<double> onChanged;

  /// Fired on pointer release only - never on an arrow key or a swipe-adjust.
  final VoidCallback onReleased;

  final FocusNode focusNode;
  final String semanticLabel;

  /// "40 percent revealed", in the locale's numerals.
  final String Function(int) formatValue;

  @override
  Widget build(BuildContext context) {
    final c = context.spy;
    return SizedBox(
      // A full-width 44dp band: deliberately oversized, because it is dragged
      // by somebody who is not looking straight at the screen.
      height: SpyPrimitives.tapMin,
      child: SliderTheme(
        data: SliderThemeData(
          trackHeight: 10,
          trackShape: _RedactionTrackShape(
            fill: c.accent,
            empty: c.surfaceSunken,
            border: c.border,
          ),
          thumbShape: _RedactionThumbShape(
            fill: c.accent,
            border: c.accentPress,
            shadow: c.shadow1,
          ),
          // Material's splash halo is wrong on something meant to look printed.
          overlayShape: SliderComponentShape.noOverlay,
          overlayColor: Colors.transparent,
          showValueIndicator: ShowValueIndicator.never,
        ),
        child: Slider(
          value: value,
          focusNode: focusNode,
          onChanged: onChanged,
          // Pointer release. Semantics and keyboard adjustments do not call
          // this, which is exactly the exception the design asks for.
          onChangeEnd: (_) => onReleased(),
          label: semanticLabel,
          semanticFormatterCallback: (v) => formatValue((v * 100).round()),
        ),
      ),
    );
  }
}

class _RedactionTrackShape extends SliderTrackShape with BaseSliderTrackShape {
  const _RedactionTrackShape({
    required this.fill,
    required this.empty,
    required this.border,
  });

  final Color fill;
  final Color empty;
  final Color border;

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
  }) {
    final rect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final canvas = context.canvas;
    final radius = Radius.circular(rect.height / 2);

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, radius),
      Paint()..color = empty,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(0.5), radius),
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // The brass fill grows from the leading edge - which is the right edge in
    // Persian, where zero sits on the right and the thumb drags leftward.
    final isLtr = textDirection == TextDirection.ltr;
    final filled = isLtr
        ? Rect.fromLTRB(rect.left, rect.top, thumbCenter.dx, rect.bottom)
        : Rect.fromLTRB(thumbCenter.dx, rect.top, rect.right, rect.bottom);
    if (filled.width > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(filled, radius),
        Paint()..color = fill,
      );
    }
  }
}

class _RedactionThumbShape extends SliderComponentShape {
  const _RedactionThumbShape({
    required this.fill,
    required this.border,
    required this.shadow,
  });

  final Color fill;
  final Color border;
  final BoxShadow shadow;

  static const _size = 30.0;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size.square(_size);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    final rect = Rect.fromCenter(center: center, width: _size, height: _size);
    // r-sm: nothing in this system is pill-shaped except chips and the switch.
    final rrect = RRect.fromRectAndRadius(
      rect,
      const Radius.circular(SpyPrimitives.rSm),
    );
    canvas.drawRRect(
      rrect.shift(shadow.offset),
      Paint()
        ..color = shadow.color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadow.blurRadius / 2),
    );
    canvas.drawRRect(rrect, Paint()..color = fill);
    canvas.drawRRect(
      rrect.deflate(0.5),
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }
}
