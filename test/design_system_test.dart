import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spy/design/theme.dart';
import 'package:spy/l10n/strings.dart';

/// The design system's claims, enforced.
///
/// The contrast figures in the spec are computed numbers, not intentions - so
/// they are computed here too, against the same tokens, and fail the build if
/// a colour is ever nudged past its floor.
void main() {
  double channel(double c) =>
      c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

  double luminance(Color c) =>
      0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);

  double contrast(Color a, Color b) {
    final la = luminance(a);
    final lb = luminance(b);
    final hi = math.max(la, lb);
    final lo = math.min(la, lb);
    return (hi + 0.05) / (lo + 0.05);
  }

  group('contrast', () {
    for (final theme in [
      (name: 'noir', c: SpyColors.noir),
      (name: 'daylight', c: SpyColors.daylight),
    ]) {
      final c = theme.c;
      final pairs = <({String label, Color fg, Color bg, double min})>[
        (label: 'body text on background', fg: c.text, bg: c.bg, min: 4.5),
        (label: 'muted text on background', fg: c.textMuted, bg: c.bg, min: 4.5),
        (label: 'faint text on background', fg: c.textFaint, bg: c.bg, min: 4.5),
        (label: 'accent text on surface', fg: c.accentText, bg: c.surface, min: 4.5),
        (label: 'text on the primary button', fg: c.textOnAccent, bg: c.accent, min: 4.5),
        (label: 'primary fill vs background', fg: c.accent, bg: c.bg, min: 3),
        (label: 'spy crimson on background', fg: c.spy, bg: c.bg, min: 4.5),
        (label: 'steel notice on background', fg: c.notice, bg: c.bg, min: 4.5),
        (label: 'countdown digits (large)', fg: c.text, bg: c.bg, min: 3),
        (label: 'focus ring on background', fg: c.accentHover, bg: c.bg, min: 3),
      ];

      for (final pair in pairs) {
        test('${theme.name}: ${pair.label}', () {
          final ratio = contrast(pair.fg, pair.bg);
          expect(
            ratio,
            greaterThanOrEqualTo(pair.min),
            reason: '${pair.label} is ${ratio.toStringAsFixed(1)}:1, '
                'below the ${pair.min}:1 floor',
          );
        });
      }

      test('${theme.name}: the redaction slab is the darkest thing on screen',
          () {
        expect(luminance(c.redact), lessThanOrEqualTo(luminance(c.bg)));
        expect(luminance(c.redact), lessThanOrEqualTo(luminance(c.surfaceSunken)));
      });

      test('${theme.name}: the word is legible on the redaction slab', () {
        // White-on-black regardless of theme - the slab is not a themed
        // surface, so this pair is identical in Noir and Daylight.
        expect(
          contrast(SpyPrimitives.neutral1000, c.redact),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrast(SpyPrimitives.crimson300, c.redact),
          greaterThanOrEqualTo(4.5),
        );
      });
    }
  });

  group('tokens are the API', () {
    late Map<String, dynamic> json;

    setUpAll(() {
      json = jsonDecode(File('tokens.json').readAsStringSync())
          as Map<String, dynamic>;
    });

    test('the generated scale matches tokens.json', () {
      final space = json['space'] as Map<String, dynamic>;
      expect(SpyPrimitives.s5, _px(space['5']));
      expect(SpyPrimitives.s7, _px(space['7']));

      final radius = json['radius'] as Map<String, dynamic>;
      expect(SpyPrimitives.rLg, _px(radius['lg']));
      expect(SpyPrimitives.rXl, _px(radius['xl']));

      final layout = json['layout'] as Map<String, dynamic>;
      expect(SpyPrimitives.tapMin, _px(layout['tapMin']));
      expect(SpyPrimitives.contentMax, _px(layout['contentMax']));
    });

    test('the generated motion matches tokens.json', () {
      final durations = json['motion']['duration'] as Map<String, dynamic>;
      expect(SpyPrimitives.dSeal.inMilliseconds, _ms(durations['seal']));
      expect(SpyPrimitives.dReveal.inMilliseconds, _ms(durations['reveal']));
      expect(SpyPrimitives.dVerdict.inMilliseconds, _ms(durations['verdict']));
    });

    test('both themes declare every semantic alias', () {
      final noir = (json['theme']['noir'] as Map<String, dynamic>).keys.toList();
      final daylight =
          (json['theme']['daylight'] as Map<String, dynamic>).keys.toList();
      expect(noir, daylight,
          reason: 'a token in one theme and not the other is a broken theme');
    });

    test('the primitive ramps survive the round trip to Dart', () {
      final brass = json['color']['brass'] as Map<String, dynamic>;
      expect(SpyPrimitives.brass400, _color(brass['400']));
      expect(SpyPrimitives.brass700, _color(brass['700']));
      final crimson = json['color']['crimson'] as Map<String, dynamic>;
      expect(SpyPrimitives.crimson400, _color(crimson['400']));
      expect(SpyPrimitives.ink, const Color(0xFF05070A));
    });
  });

  group('voice', () {
    late String source;

    setUpAll(() {
      source = File('lib/l10n/strings.dart').readAsStringSync();
    });

    test('zero exclamation marks anywhere', () {
      // "It's Sara's turn! 🕵️" is exactly the voice this product refuses.
      for (final literal in _stringLiterals(source)) {
        expect(literal, isNot(contains('!')),
            reason: 'exclamation marks are banned in every string');
      }
    });

    test('no emoji in user-facing copy', () {
      final emoji = RegExp(
        r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]',
        unicode: true,
      );
      for (final literal in _stringLiterals(source)) {
        expect(emoji.hasMatch(literal), isFalse, reason: 'found in "$literal"');
      }
    });

    test('the refused vocabulary stays refused', () {
      // "Civilian", not "innocent" - nobody at this table is innocent, they
      // just do not have the job.
      const refused = [
        'imposter', 'impostor', 'undercover agent', 'mission', 'player card',
        'game master', 'lobby', 'streak', 'villager', 'innocent',
      ];
      final lower = source.toLowerCase();
      for (final word in refused) {
        expect(lower, isNot(contains(word)), reason: '"$word" is off the list');
      }
    });
  });

  group('data formatting', () {
    const en = SpyStringsEn();
    const fa = SpyStringsFa();

    test('the big clock keeps two-digit minutes so digits do not jump', () {
      expect(en.clockTime(const Duration(minutes: 5, seconds: 42)), '05:42');
      expect(en.clockTime(const Duration(seconds: 47)), '00:47');
      expect(en.clockTime(Duration.zero), '00:00');
    });

    test('a clock never runs backwards past zero', () {
      expect(en.clockTime(const Duration(seconds: -30)), '00:00');
    });

    test('Persian numerals are used throughout, including the clock', () {
      expect(fa.clockTime(const Duration(minutes: 5, seconds: 42)), '۰۵:۴۲');
      expect(fa.number(7), '۷');
      expect(fa.playerDefault(4), 'بازیکن ۴');
    });

    test('the round length drops the leading zero, the big clock does not', () {
      expect(en.roundLength(const Duration(minutes: 8)), '8:00');
      expect(en.clockTime(const Duration(minutes: 8)), '08:00');
    });

    test('counts always carry the noun and switch on plural', () {
      expect(en.packsCount(1), '1 word');
      expect(en.packsCount(180), '180 words');
      expect(en.verdictTheSpiesWere(1), 'The spy was');
      expect(en.verdictTheSpiesWere(2), 'The spies were');
    });

    test('the case label looks like a filing system', () {
      expect(en.handoffCase(4, 2), 'Case 04 · Round 2');
      expect(en.handoffCase(11, 10), 'Case 11 · Round 10');
    });

    test('default player names start at one and are never zero-padded', () {
      expect(en.playerDefault(1), 'Player 1');
      expect(en.playerDefault(4), 'Player 4');
    });
  });

  group('density', () {
    test('a 400dp phone at 1.6x text scale behaves like a compact device', () {
      expect(
        SpyDensity.of(400, const TextScaler.linear(1.6)),
        SpyDensity.compact,
        reason: 'measure the constraints, not the device',
      );
    });

    test('the reference layout sits between the breakpoints', () {
      expect(SpyDensity.of(390, TextScaler.noScaling), SpyDensity.standard);
      expect(SpyDensity.of(359, TextScaler.noScaling), SpyDensity.compact);
      expect(SpyDensity.of(430, TextScaler.noScaling), SpyDensity.wide);
    });
  });

  group('typography', () {
    test('Persian replaces Oswald and Inter alike', () {
      final fa = SpyType.forLocale(const Locale('fa'));
      for (final style in [fa.wordmark, fa.display, fa.body, fa.file, fa.clock]) {
        expect(style.fontFamily, SpyPrimitives.ffPersian);
      }
      expect(fa.uppercases, isFalse, reason: 'Persian has no case to apply');
    });

    test('Persian drops the display sizes one step and opens the leading', () {
      final en = SpyType.forLocale(const Locale('en'));
      final fa = SpyType.forLocale(const Locale('fa'));
      expect(fa.wordmark.fontSize, lessThan(en.wordmark.fontSize!));
      expect(fa.clock.fontSize, lessThan(en.clock.fontSize!));
      expect(fa.body.height, 1.75);
    });

    test('Persian carries no letter spacing', () {
      final fa = SpyType.forLocale(const Locale('fa'));
      for (final style in [fa.wordmark, fa.display, fa.title, fa.label]) {
        expect(style.letterSpacing, anyOf(isNull, 0.0),
            reason: 'tracking breaks Arabic-script joining');
      }
    });

    test('everything that changes in place is tabular', () {
      final en = SpyType.forLocale(const Locale('en'));
      for (final style in [en.clock, en.stepperValue]) {
        expect(
          style.fontFeatures?.map((f) => f.feature),
          contains('tnum'),
          reason: 'proportional digits make the clock jitter once a second',
        );
      }
    });
  });
}

double _px(dynamic token) =>
    double.parse((token[r'$value'] as String).replaceAll('px', ''));

int _ms(dynamic token) =>
    int.parse((token[r'$value'] as String).replaceAll('ms', ''));

Color _color(dynamic token) {
  final hex = (token[r'$value'] as String).replaceFirst('#', '');
  return Color(int.parse('FF$hex', radix: 16));
}

/// Every single-quoted literal in the source, with escapes left alone.
Iterable<String> _stringLiterals(String source) sync* {
  final pattern = RegExp(r"'((?:[^'\\\n]|\\.)*)'");
  for (final match in pattern.allMatches(source)) {
    final value = match[1]!;
    if (value.isEmpty) continue;
    yield value;
  }
}
