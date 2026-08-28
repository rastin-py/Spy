import 'package:flutter/material.dart';

import '../design/theme.dart';

enum SpyButtonKind {
  /// The lamp. Exactly one per screen.
  primary,
  secondary,
  ghost,

  /// Crimson-*outlined*, never crimson-filled: a filled crimson block is the
  /// spy card's visual language, and nothing but a spy should look like a spy.
  danger,
}

enum SpyButtonSize { large, medium, small }

/// The one button in the system.
///
/// Press is the *lamp* motion: scale 0.97 over 80 ms with a brass glow decaying
/// over 220 ms. That glow is the only glow in the product.
class SpyButton extends StatefulWidget {
  const SpyButton({
    required this.label,
    required this.onPressed,
    this.kind = SpyButtonKind.secondary,
    this.size = SpyButtonSize.medium,
    this.disabledReason,
    this.icon,
    super.key,
  });

  final String label;

  /// Null disables the button - and if it is disabled, say why in
  /// [disabledReason] or in help text beside it.
  final VoidCallback? onPressed;

  final SpyButtonKind kind;
  final SpyButtonSize size;

  /// Announced to a screen reader, because a disabled control that does not
  /// state its reason is not accessible - or, frankly, usable.
  final String? disabledReason;

  final Widget? icon;

  @override
  State<SpyButton> createState() => _SpyButtonState();
}

class _SpyButtonState extends State<SpyButton> with SingleTickerProviderStateMixin {
  late final AnimationController _lamp = AnimationController(
    vsync: this,
    duration: SpyPrimitives.dInstant,
    reverseDuration: SpyPrimitives.dBase,
  );

  @override
  void dispose() {
    _lamp.dispose();
    super.dispose();
  }

  bool get _enabled => widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    final c = context.spy;
    final t = context.type;
    final isLarge = widget.size == SpyButtonSize.large;

    final (Color fg, Color bg, Color border) = switch (widget.kind) {
      SpyButtonKind.primary => (c.textOnAccent, c.accent, c.accent),
      SpyButtonKind.secondary => (c.text, Colors.transparent, c.borderStrong),
      SpyButtonKind.ghost => (c.textMuted, Colors.transparent, Colors.transparent),
      SpyButtonKind.danger => (c.danger, Colors.transparent, c.danger),
    };

    final height = switch (widget.size) {
      SpyButtonSize.large => 52.0,
      SpyButtonSize.medium => 40.0,
      SpyButtonSize.small => 32.0,
    };

    final style = isLarge
        ? t.buttonLarge.copyWith(color: fg)
        : t.button.copyWith(
            color: fg,
            fontSize: widget.size == SpyButtonSize.small ? 11.5 : null,
          );

    // Uppercase is applied by the style, never typed into a string - and only
    // on the large primary-sized buttons.
    final label = isLarge && t.uppercases ? widget.label.toUpperCase() : widget.label;

    return Semantics(
      button: true,
      enabled: _enabled,
      hint: _enabled ? null : widget.disabledReason,
      child: AnimatedBuilder(
        animation: _lamp,
        builder: (context, child) {
          final v = _lamp.value;
          return Transform.scale(
            scale: 1 - 0.03 * v,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(
                  widget.size == SpyButtonSize.small
                      ? SpyPrimitives.rSm
                      : SpyPrimitives.rMd,
                ),
                boxShadow: widget.kind == SpyButtonKind.primary && v > 0
                    ? [
                        BoxShadow(
                          color: c.accent.withValues(alpha: 0.45 * v),
                          blurRadius: 18 * v,
                          spreadRadius: 2 * v,
                        ),
                      ]
                    : null,
              ),
              child: child,
            ),
          );
        },
        child: Opacity(
          opacity: _enabled ? 1 : 0.34,
          child: Material(
            color: bg,
            borderRadius: BorderRadius.circular(
              widget.size == SpyButtonSize.small
                  ? SpyPrimitives.rSm
                  : SpyPrimitives.rMd,
            ),
            child: InkWell(
              onTap: widget.onPressed,
              onTapDown: _enabled ? (_) => _lamp.forward() : null,
              onTapUp: _enabled ? (_) => _lamp.reverse() : null,
              onTapCancel: _enabled ? () => _lamp.reverse() : null,
              // A printed card does not ripple.
              splashFactory: NoSplash.splashFactory,
              highlightColor: c.surfaceRaised.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(
                widget.size == SpyButtonSize.small
                    ? SpyPrimitives.rSm
                    : SpyPrimitives.rMd,
              ),
              child: Container(
                height: height,
                constraints: const BoxConstraints(minWidth: SpyPrimitives.tapMin),
                padding: EdgeInsetsDirectional.symmetric(
                  horizontal: isLarge ? SpyPrimitives.s7 : SpyPrimitives.s5,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: border),
                  borderRadius: BorderRadius.circular(
                    widget.size == SpyButtonSize.small
                        ? SpyPrimitives.rSm
                        : SpyPrimitives.rMd,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[
                      IconTheme(
                        data: IconThemeData(color: fg, size: 18),
                        child: widget.icon!,
                      ),
                      const SizedBox(width: SpyPrimitives.s3),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        style: style,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A 40dp square inside a 44dp target, for the one icon action an app bar
/// ever carries.
class SpyIconButton extends StatelessWidget {
  const SpyIconButton({
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    super.key,
  });

  final Widget icon;
  final VoidCallback onPressed;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.spy;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(SpyPrimitives.rMd),
        splashFactory: NoSplash.splashFactory,
        child: SizedBox(
          width: SpyPrimitives.tapMin,
          height: SpyPrimitives.tapMin,
          child: Center(
            child: IconTheme(
              data: IconThemeData(color: c.textMuted, size: 20),
              child: icon,
            ),
          ),
        ),
      ),
    );
  }
}
