import 'platform.dart';

/// The tick and the bell.
///
/// The player lives on the platform side: one pre-loaded looping sample rather
/// than a new player per tick, which leaks handles and drifts audibly within
/// two minutes. The session is ambient and mixes with others, so the tick
/// respects the iOS ringer switch and Android DND and leaves the user's music
/// alone.
///
/// Everything the sound says is also on screen: a player with the sound off,
/// or a deaf player, loses nothing but atmosphere.
class SpyAudio {
  SpyAudio._();

  static final SpyAudio instance = SpyAudio._();

  bool _ticking = false;

  Future<void> warmUp() async {}

  Future<void> startTicking() async {
    if (_ticking) return;
    _ticking = true;
    await SpyPlatform.startTicking();
  }

  Future<void> stopTicking() async {
    if (!_ticking) return;
    _ticking = false;
    await SpyPlatform.stopTicking();
  }

  Future<void> strikeBell() => SpyPlatform.strikeBell();
}
