import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The app's one channel to the platform.
///
/// Spy ships no third-party native code. Everything it needs from the phone -
/// keeping a word out of a screenshot, a wall clock ticking in the ambient
/// audio session, the screen staying awake, somewhere to put a settings file,
/// and handing a store link to the system - is a handful of calls, and owning
/// them outright is cheaper than five plugins and their transitive build
/// graphs. The network Spy does use is `dart:io` in this process, which is why
/// the About screen can still say exactly what leaves the phone.
///
/// Every method degrades to a no-op when the host does not implement it, so a
/// test host or a desktop build simply does without.
abstract final class SpyPlatform {
  static const _channel = MethodChannel('spy/platform');

  static Future<T?> _call<T>(String method, [Map<String, dynamic>? args]) async {
    if (kIsWeb) return null;
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null;
    } catch (error) {
      debugPrint('Spy: $method failed ($error)');
      return null;
    }
  }

  /// `FLAG_SECURE` on Android, the snapshot cover on iOS. Handoff and Reveal
  /// only - a game people want to screenshot should be screenshottable.
  static Future<void> setSecure(bool secure) =>
      _call<void>('setSecure', {'secure': secure});

  /// Null when the platform cannot say - iOS has no public API for the ringer
  /// switch, and a notice that appears at random is worse than none.
  static Future<bool?> isMuted() => _call<bool>('isMuted');

  /// Only ever true while the clock runs *and* the setting is on.
  static Future<void> setKeepAwake(bool awake) =>
      _call<void>('setKeepAwake', {'awake': awake});

  /// Where the settings file lives. Null means this run is memory-only.
  static Future<String?> storageDirectory() => _call<String>('storageDirectory');

  /// One looped one-second sample in the ambient session, started once.
  static Future<void> startTicking() => _call<void>('startTicking');

  static Future<void> stopTicking() => _call<void>('stopTicking');

  /// One strike at zero. Never repeated.
  static Future<void> strikeBell() => _call<void>('strikeBell');

  /// Hands a store link to the system and lets it decide.
  ///
  /// Spy never downloads or installs a build itself - Bazaar forbids it, and
  /// a party game that can install applications is a party game nobody should
  /// hand round a table. False means nothing on the phone could open it, and
  /// the banner stays put rather than pretending something happened.
  static Future<bool> openUrl(String url) async =>
      await _call<bool>('openUrl', {'url': url}) ?? false;
}
