import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Haptics carry the second channel for three states, so they are never the
/// only signal - the spy card also says "You are the spy" and draws a crimson
/// border, and the last ten seconds also breathe on screen.
abstract final class SpyHaptics {
  static bool enabled = true;

  static Future<void> _fire(Future<void> Function() f) async {
    if (!enabled) return;
    try {
      await f();
    } catch (_) {
      // A phone with no vibrator is not an error worth telling anyone about.
    }
  }

  /// The slider crossing into legible territory.
  static Future<void> reveal() => _fire(HapticFeedback.selectionClick);

  /// Heavier, because the card underneath says something different.
  static Future<void> spyReveal() => _fire(HapticFeedback.heavyImpact);

  /// One per second, in the last ten.
  static Future<void> tick() => _fire(HapticFeedback.lightImpact);

  /// The verdict stamp landing.
  static Future<void> stamp() => _fire(HapticFeedback.heavyImpact);

  @visibleForTesting
  static void resetForTest() => enabled = true;
}
