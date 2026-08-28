import 'package:flutter/material.dart';

import 'tokens.g.dart';

export 'tokens.g.dart';

/// How wide the screen is *after* text scale is taken into account.
///
/// Measure the constraints, not the device: a 400dp phone at 1.6x text scale
/// behaves like a compact device and gets the compact layout. This is what
/// keeps the clock and the secret word from ever needing to shrink - the
/// layout mode absorbs the scale instead.
enum SpyDensity {
  compact,
  standard,
  wide;

  static SpyDensity of(double width, TextScaler scaler) {
    final effective = width / scaler.scale(10) * 10;
    if (effective < SpyPrimitives.bpCompact) return SpyDensity.compact;
    if (effective >= SpyPrimitives.bpWide) return SpyDensity.wide;
    return SpyDensity.standard;
  }

  bool get isCompact => this == SpyDensity.compact;
}

/// Carries the resolved [SpyDensity] down the tree. Set once per screen by
/// [SpyScaffold] from a `LayoutBuilder`, never from `MediaQuery.size`.
class SpyDensityScope extends InheritedWidget {
  const SpyDensityScope({required this.density, required super.child, super.key});

  final SpyDensity density;

  static SpyDensity of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SpyDensityScope>()?.density ??
      SpyDensity.standard;

  @override
  bool updateShouldNotify(SpyDensityScope oldWidget) => density != oldWidget.density;
}

/// The type scale, resolved for a locale.
///
/// Persian is not a translation layer: Vazirmatn replaces Oswald *and* Inter,
/// and the hierarchy is rebuilt with weight (900/700/400) because no condensed
/// Persian display face exists at this quality. Tracking goes to zero - letter
/// spacing breaks Arabic-script joining - and the leading opens to 1.75.
@immutable
class SpyType extends ThemeExtension<SpyType> {
  const SpyType({
    required this.wordmark,
    required this.display,
    required this.clock,
    required this.title,
    required this.appBar,
    required this.body,
    required this.button,
    required this.buttonLarge,
    required this.label,
    required this.caption,
    required this.file,
    required this.stepperValue,
  });

  /// SPY.
  final TextStyle wordmark;

  /// The secret word.
  final TextStyle display;

  /// 05:42. Tabular, always.
  final TextStyle clock;

  /// A player's name. Not uppercased - see [SpyType.forLocale].
  final TextStyle title;
  final TextStyle appBar;
  final TextStyle body;
  final TextStyle button;
  final TextStyle buttonLarge;
  final TextStyle label;
  final TextStyle caption;

  /// CASE 04 - ROUND 2. Courier Prime, small sizes in wide-tracked caps only.
  final TextStyle file;
  final TextStyle stepperValue;

  static const _tabular = [FontFeature.tabularFigures()];

  factory SpyType.forLocale(Locale locale) =>
      locale.languageCode == 'fa' ? _persian : _latin;

  static const _latinFallback = <String>[SpyPrimitives.ffPersian];

  static const _latin = SpyType(
    wordmark: TextStyle(
      fontFamily: SpyPrimitives.ffDisplay,
      fontFamilyFallback: _latinFallback,
      fontSize: SpyPrimitives.fsWordmark,
      fontWeight: FontWeight.w700,
      letterSpacing: SpyPrimitives.fsWordmark * 0.18,
      height: 1.0,
    ),
    display: TextStyle(
      fontFamily: SpyPrimitives.ffDisplay,
      fontFamilyFallback: _latinFallback,
      fontSize: SpyPrimitives.fsDisplay,
      fontWeight: FontWeight.w700,
      letterSpacing: SpyPrimitives.fsDisplay * 0.04,
      height: 1.05,
    ),
    clock: TextStyle(
      fontFamily: SpyPrimitives.ffDisplay,
      fontFamilyFallback: _latinFallback,
      fontSize: SpyPrimitives.fsClock,
      fontWeight: FontWeight.w600,
      letterSpacing: SpyPrimitives.fsClock * 0.02,
      height: 1.0,
      fontFeatures: _tabular,
    ),
    title: TextStyle(
      fontFamily: SpyPrimitives.ffDisplay,
      fontFamilyFallback: _latinFallback,
      fontSize: SpyPrimitives.fsTitle,
      fontWeight: FontWeight.w600,
      letterSpacing: SpyPrimitives.fsTitle * 0.06,
      height: 1.2,
    ),
    appBar: TextStyle(
      fontFamily: SpyPrimitives.ffDisplay,
      fontFamilyFallback: _latinFallback,
      fontSize: SpyPrimitives.fsAppbar,
      fontWeight: FontWeight.w600,
      letterSpacing: SpyPrimitives.fsAppbar * 0.12,
      height: 1.2,
    ),
    body: TextStyle(
      fontFamily: SpyPrimitives.ffUi,
      fontFamilyFallback: _latinFallback,
      fontSize: SpyPrimitives.fsBody,
      fontWeight: FontWeight.w400,
      height: 1.5,
    ),
    button: TextStyle(
      fontFamily: SpyPrimitives.ffUi,
      fontFamilyFallback: _latinFallback,
      fontSize: SpyPrimitives.fsButton,
      fontWeight: FontWeight.w700,
      letterSpacing: SpyPrimitives.fsButton * 0.02,
      height: 1.1,
    ),
    buttonLarge: TextStyle(
      fontFamily: SpyPrimitives.ffDisplay,
      fontFamilyFallback: _latinFallback,
      fontSize: 15,
      fontWeight: FontWeight.w600,
      letterSpacing: 15 * 0.06,
      height: 1.1,
    ),
    label: TextStyle(
      fontFamily: SpyPrimitives.ffUi,
      fontFamilyFallback: _latinFallback,
      fontSize: SpyPrimitives.fsLabel,
      fontWeight: FontWeight.w700,
      letterSpacing: SpyPrimitives.fsLabel * 0.16,
      height: 1.2,
    ),
    caption: TextStyle(
      fontFamily: SpyPrimitives.ffUi,
      fontFamilyFallback: _latinFallback,
      fontSize: SpyPrimitives.fsCaption,
      fontWeight: FontWeight.w400,
      height: 1.5,
    ),
    file: TextStyle(
      fontFamily: SpyPrimitives.ffFile,
      fontFamilyFallback: _latinFallback,
      fontSize: SpyPrimitives.fsFile,
      fontWeight: FontWeight.w400,
      letterSpacing: SpyPrimitives.fsFile * 0.14,
      height: 1.4,
    ),
    stepperValue: TextStyle(
      fontFamily: SpyPrimitives.ffDisplay,
      fontFamilyFallback: _latinFallback,
      fontSize: 26,
      fontWeight: FontWeight.w600,
      height: 1.0,
      fontFeatures: _tabular,
    ),
  );

  /// Same px, weight instead of width, tracking off, leading at 1.75.
  /// Display sizes drop one step: wordmark 44 -> 38, clock 76 -> 68.
  static const _persian = SpyType(
    wordmark: TextStyle(
      fontFamily: SpyPrimitives.ffPersian,
      fontSize: 38,
      fontWeight: FontWeight.w900,
      height: 1.3,
    ),
    display: TextStyle(
      fontFamily: SpyPrimitives.ffPersian,
      fontSize: 30,
      fontWeight: FontWeight.w900,
      height: 1.4,
    ),
    clock: TextStyle(
      fontFamily: SpyPrimitives.ffPersian,
      fontSize: 68,
      fontWeight: FontWeight.w700,
      height: 1.1,
      fontFeatures: _tabular,
    ),
    title: TextStyle(
      fontFamily: SpyPrimitives.ffPersian,
      fontSize: SpyPrimitives.fsTitle,
      fontWeight: FontWeight.w900,
      height: 1.5,
    ),
    appBar: TextStyle(
      fontFamily: SpyPrimitives.ffPersian,
      fontSize: SpyPrimitives.fsAppbar,
      fontWeight: FontWeight.w700,
      height: 1.5,
    ),
    body: TextStyle(
      fontFamily: SpyPrimitives.ffPersian,
      fontSize: SpyPrimitives.fsBody,
      fontWeight: FontWeight.w400,
      height: 1.75,
    ),
    button: TextStyle(
      fontFamily: SpyPrimitives.ffPersian,
      fontSize: SpyPrimitives.fsButton,
      fontWeight: FontWeight.w700,
      height: 1.4,
    ),
    buttonLarge: TextStyle(
      fontFamily: SpyPrimitives.ffPersian,
      fontSize: 15,
      fontWeight: FontWeight.w900,
      height: 1.4,
    ),
    label: TextStyle(
      fontFamily: SpyPrimitives.ffPersian,
      fontSize: SpyPrimitives.fsCaption,
      fontWeight: FontWeight.w700,
      height: 1.5,
    ),
    caption: TextStyle(
      fontFamily: SpyPrimitives.ffPersian,
      fontSize: SpyPrimitives.fsCaption,
      fontWeight: FontWeight.w400,
      height: 1.75,
    ),
    file: TextStyle(
      fontFamily: SpyPrimitives.ffPersian,
      fontSize: SpyPrimitives.fsCaption,
      fontWeight: FontWeight.w500,
      height: 1.5,
    ),
    stepperValue: TextStyle(
      fontFamily: SpyPrimitives.ffPersian,
      fontSize: 26,
      fontWeight: FontWeight.w700,
      height: 1.2,
      fontFeatures: _tabular,
    ),
  );

  /// Uppercase is applied by the style, never typed into a string - and never
  /// at all in Persian, which has no case.
  bool get uppercases => wordmark.fontFamily != SpyPrimitives.ffPersian;

  @override
  SpyType copyWith() => this;

  @override
  SpyType lerp(SpyType? other, double t) {
    if (other == null) return this;
    return SpyType(
      wordmark: TextStyle.lerp(wordmark, other.wordmark, t)!,
      display: TextStyle.lerp(display, other.display, t)!,
      clock: TextStyle.lerp(clock, other.clock, t)!,
      title: TextStyle.lerp(title, other.title, t)!,
      appBar: TextStyle.lerp(appBar, other.appBar, t)!,
      body: TextStyle.lerp(body, other.body, t)!,
      button: TextStyle.lerp(button, other.button, t)!,
      buttonLarge: TextStyle.lerp(buttonLarge, other.buttonLarge, t)!,
      label: TextStyle.lerp(label, other.label, t)!,
      caption: TextStyle.lerp(caption, other.caption, t)!,
      file: TextStyle.lerp(file, other.file, t)!,
      stepperValue: TextStyle.lerp(stepperValue, other.stepperValue, t)!,
    );
  }
}

abstract final class SpyTheme {
  static ThemeData build({required SpyColors colors, required Locale locale}) {
    final type = SpyType.forLocale(locale);
    return ThemeData(
      useMaterial3: true,
      brightness: colors == SpyColors.noir ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: colors.bg,
      canvasColor: colors.bg,
      splashFactory: NoSplash.splashFactory,
      // A printed card does not ripple.
      highlightColor: Colors.transparent,
      colorScheme: ColorScheme(
        brightness: colors == SpyColors.noir ? Brightness.dark : Brightness.light,
        primary: colors.accent,
        onPrimary: colors.textOnAccent,
        secondary: colors.accentText,
        onSecondary: colors.textOnAccent,
        error: colors.danger,
        onError: colors.textOnSpy,
        surface: colors.surface,
        onSurface: colors.text,
        outline: colors.border,
      ),
      extensions: [colors, type],
      textTheme: TextTheme(
        bodyMedium: type.body.copyWith(color: colors.text),
        bodySmall: type.caption.copyWith(color: colors.textMuted),
        labelSmall: type.label.copyWith(color: colors.textFaint),
        titleMedium: type.title.copyWith(color: colors.text),
      ),
    );
  }
}

extension SpyContext on BuildContext {
  /// The only colour surface a widget may read.
  SpyColors get spy => Theme.of(this).extension<SpyColors>()!;

  SpyType get type => Theme.of(this).extension<SpyType>()!;

  SpyDensity get density => SpyDensityScope.of(this);

  /// True when the platform asked for less movement. *develop* ignores this -
  /// direct manipulation is not animation - but *seal* becomes a cut.
  bool get reducedMotion => MediaQuery.disableAnimationsOf(this);

  bool get isRtl => Directionality.of(this) == TextDirection.rtl;
}
