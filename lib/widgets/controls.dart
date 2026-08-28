import 'package:flutter/material.dart';

import '../design/theme.dart';

/// On / off, with the literal words carried by whatever labels it - colour is
/// never the only channel.
class SpySwitch extends StatelessWidget {
  const SpySwitch({
    required this.value,
    required this.onChanged,
    this.disabledReason,
    this.semanticLabel,
    super.key,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  /// A disabled switch always states why, and is not focusable.
  final String? disabledReason;

  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.spy;
    final enabled = onChanged != null;
    return Semantics(
      toggled: value,
      label: semanticLabel,
      hint: enabled ? null : disabledReason,
      enabled: enabled,
      child: ExcludeSemantics(
        child: Opacity(
          opacity: enabled ? 1 : 0.34,
          child: GestureDetector(
            onTap: enabled ? () => onChanged!(!value) : null,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: SpyPrimitives.tapMin,
              height: SpyPrimitives.tapMin,
              child: Center(
                child: AnimatedContainer(
                  duration: SpyPrimitives.dFast,
                  curve: SpyPrimitives.eStandard,
                  width: 44,
                  height: 26,
                  decoration: BoxDecoration(
                    color: value ? c.accent : c.borderStrong,
                    borderRadius: BorderRadius.circular(SpyPrimitives.rFull),
                  ),
                  child: AnimatedAlign(
                    duration: SpyPrimitives.dFast,
                    curve: SpyPrimitives.eStandard,
                    alignment: value
                        ? AlignmentDirectional.centerEnd
                        : AlignmentDirectional.centerStart,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.symmetric(horizontal: 3),
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: value ? c.textOnAccent : c.surface,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The player and spy counter.
///
/// Announces as one adjustable rather than two buttons, and the ceiling always
/// states its reason rather than just greying out.
class CountStepper extends StatelessWidget {
  const CountStepper({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.semanticLabel,
    required this.format,
    super.key,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final String semanticLabel;

  /// Locale numerals - Persian-Indic in Persian, including here.
  final String Function(int) format;

  @override
  Widget build(BuildContext context) {
    final c = context.spy;
    final t = context.type;
    return Semantics(
      slider: true,
      label: semanticLabel,
      value: format(value),
      increasedValue: value < max ? format(value + 1) : null,
      decreasedValue: value > min ? format(value - 1) : null,
      onIncrease: value < max ? () => onChanged(value + 1) : null,
      onDecrease: value > min ? () => onChanged(value - 1) : null,
      child: ExcludeSemantics(
        child: Container(
          decoration: BoxDecoration(
            color: c.surfaceSunken,
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(SpyPrimitives.rMd),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              _StepButton(
                glyph: '−',
                onPressed: value > min ? () => onChanged(value - 1) : null,
              ),
              Expanded(
                child: Text(
                  format(value),
                  textAlign: TextAlign.center,
                  style: t.stepperValue.copyWith(color: c.text),
                ),
              ),
              _StepButton(
                glyph: '+',
                onPressed: value < max ? () => onChanged(value + 1) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.glyph, required this.onPressed});

  final String glyph;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.spy;
    return InkWell(
      onTap: onPressed,
      splashFactory: NoSplash.splashFactory,
      child: Opacity(
        opacity: onPressed == null ? 0.3 : 1,
        child: SizedBox(
          // 46, not 44: it is pressed repeatedly and often without looking.
          width: 46,
          height: 46,
          child: Center(
            child: Text(
              glyph,
              style: TextStyle(
                fontFamily: SpyPrimitives.ffUi,
                fontSize: 20,
                height: 1,
                color: c.text,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Round length. Wraps to two rows in compact rather than shrinking.
class SpySegmented<T> extends StatelessWidget {
  const SpySegmented({
    required this.options,
    required this.selected,
    required this.onChanged,
    required this.labelOf,
    super.key,
  });

  final List<T> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final String Function(T) labelOf;

  @override
  Widget build(BuildContext context) {
    final c = context.spy;
    final t = context.type;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final option in options)
          Semantics(
            button: true,
            selected: option == selected,
            child: InkWell(
              onTap: () => onChanged(option),
              borderRadius: BorderRadius.circular(SpyPrimitives.rMd),
              splashFactory: NoSplash.splashFactory,
              child: AnimatedContainer(
                duration: SpyPrimitives.dBase,
                curve: SpyPrimitives.eStandard,
                constraints: BoxConstraints(
                  minWidth: context.density.isCompact ? 44 : 56,
                  minHeight: SpyPrimitives.tapMin,
                ),
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: option == selected ? c.accentQuiet : Colors.transparent,
                  border: Border.all(
                    color: option == selected ? c.accent : c.border,
                  ),
                  borderRadius: BorderRadius.circular(SpyPrimitives.rMd),
                ),
                child: Text(
                  labelOf(option),
                  style: t.buttonLarge.copyWith(
                    fontSize: context.density.isCompact ? 13 : 15,
                    fontWeight: FontWeight.w500,
                    color: option == selected ? c.accentText : c.textMuted,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Used only for optional player names.
class SpyTextField extends StatelessWidget {
  const SpyTextField({
    required this.controller,
    required this.hint,
    this.onSubmitted,
    this.textInputAction,
    super.key,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    final c = context.spy;
    final t = context.type;
    return TextField(
      controller: controller,
      onSubmitted: onSubmitted,
      textInputAction: textInputAction,
      style: t.body.copyWith(color: c.text),
      cursorColor: c.accent,
      // Names are stored and shown as typed - never uppercased, never
      // title-cased. "Amir-Hossein" is not "AMIR-HOSSEIN".
      textCapitalization: TextCapitalization.none,
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: t.body.copyWith(color: c.textFaint),
        filled: true,
        fillColor: c.surfaceSunken,
        contentPadding: const EdgeInsetsDirectional.fromSTEB(13, 11, 13, 11),
        constraints: const BoxConstraints(minHeight: SpyPrimitives.tapMin),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SpyPrimitives.rMd),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SpyPrimitives.rMd),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SpyPrimitives.rMd),
          borderSide: BorderSide(color: c.accent, width: 2),
        ),
      ),
    );
  }
}
