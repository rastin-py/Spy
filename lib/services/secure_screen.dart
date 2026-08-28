import 'package:flutter/foundation.dart';

import 'platform.dart';

/// Keeps a secret word out of screenshots and out of the app-switcher
/// thumbnail - on Handoff and Reveal only.
///
/// Off everywhere else: a game people want to screenshot should be
/// screenshottable, and a blanket flag would break the verdict screenshot that
/// is half the point of the evening.
abstract final class SecureScreen {
  static int _holders = 0;

  /// Ref-counted: Handoff pushes Reveal before it is popped, and the flag must
  /// not drop in the gap between them.
  static Future<void> acquire() async {
    _holders++;
    if (_holders == 1) await SpyPlatform.setSecure(true);
  }

  static Future<void> release() async {
    if (_holders == 0) return;
    _holders--;
    if (_holders == 0) await SpyPlatform.setSecure(false);
  }

  @visibleForTesting
  static void resetForTest() => _holders = 0;
}
