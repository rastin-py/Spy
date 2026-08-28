import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tapsell_mediation/tapsell_mediation.dart';

import '../data/remote.dart';

/// What came of asking for an advert.
enum AdResult {
  /// It appeared, and the person has now dismissed it.
  shown,

  /// Nothing to show. Normal, and not an error - fill rates in this market are
  /// nowhere near 100%.
  unavailable,

  /// The network was asked and something went wrong.
  failed,
}

/// The seam every advert network plugs into.
///
/// Spy owns this interface rather than letting an SDK's types leak upwards, for
/// three reasons: the rules in `AdGate` stay testable with no SDK under them,
/// switching networks is one file, and - the one that matters - nothing but
/// this file is ever allowed to put something full-screen on the display.
abstract class AdNetwork {
  const AdNetwork();

  /// Matched against the provider name the server sends. A name this build
  /// does not recognise means no adverts, never a guess.
  String get name;

  /// Called once, after the server has switched adverts on. Never called on a
  /// build whose adverts are off.
  Future<void> start(AdsConfig config);

  /// Fetch ahead, so the tap that shows one is not the tap that downloads it.
  Future<void> preload(String zone);

  /// Show, and complete when the screen is clear again.
  ///
  /// [onDisplayed] fires the moment the advert is actually on screen. The
  /// caller's timeout runs until then and no further: once somebody is looking
  /// at an advert, how long they look is their business, and cutting the wait
  /// short would start the game behind it.
  Future<AdResult> show(String zone, {VoidCallback? onDisplayed});

  void dispose();
}

/// The one for a build with no adverts: it politely has nothing.
///
/// What every build uses until a server says otherwise, what tests run
/// against, and what a phone with no network gets. The app is fully playable
/// through it, which is the point.
class NoAdNetwork extends AdNetwork {
  const NoAdNetwork();

  @override
  String get name => 'none';

  @override
  Future<void> start(AdsConfig config) async {}

  @override
  Future<void> preload(String zone) async {}

  @override
  Future<AdResult> show(String zone, {VoidCallback? onDisplayed}) async =>
      AdResult.unavailable;

  @override
  void dispose() {}
}

/// Tapsell, which is the only network Spy carries.
///
/// The SDK initialises itself from `ir.tapsell.mediation.APPLICATION_KEY` in
/// the manifest - there is no Dart-side init - so an empty key in
/// `android/keys.properties` leaves it inert and every request comes back
/// with nothing. That is a working build, not a broken one.
///
/// Two rules hold this class together:
///
///  * **Only ever show what is already on the phone.** [show] never requests
///    inline. If nothing is preloaded it says so immediately and the game
///    starts. Requesting at the moment of the tap means either a stall or an
///    advert that lands seconds later, over a deal that has already begun.
///  * **One advert in flight at a time.** A second `requestInterstitialAd`
///    while the first is outstanding throws the first away and wastes a fill.
class TapsellNetwork extends AdNetwork {
  TapsellNetwork();

  /// The response id of an advert that is downloaded and waiting.
  String? _ready;

  Future<void>? _requesting;
  bool _showing = false;

  @override
  String get name => 'tapsell';

  @override
  Future<void> start(AdsConfig config) async {
    // Nothing to do: the SDK reads its key from the manifest and starts
    // itself. `Tapsell.setUserConsent` is deliberately not called - Spy does
    // not ask anybody for consent it would then have to honour, and the
    // default is what the SDK ships with.
  }

  @override
  Future<void> preload(String zone) {
    if (zone.isEmpty || _ready != null) return Future.value();
    return _requesting ??= _request(zone).whenComplete(() => _requesting = null);
  }

  Future<void> _request(String zone) async {
    try {
      final id = await Tapsell.requestInterstitialAd(zone);
      if (id != null && id.isNotEmpty) _ready = id;
    } catch (error) {
      // No fill, no network, a bad zone id. All the same to the caller, and
      // none of them are worth telling anybody about.
      debugPrint('Spy: no advert to fetch ($error)');
    }
  }

  @override
  Future<AdResult> show(String zone, {VoidCallback? onDisplayed}) async {
    final adId = _ready;
    if (adId == null || _showing) return AdResult.unavailable;

    _ready = null;
    _showing = true;

    final closed = Completer<AdResult>();
    void finish(AdResult result) {
      if (!closed.isCompleted) closed.complete(result);
    }

    try {
      await Tapsell.showInterstitialAd(
        adId,
        onAdImpression: () => onDisplayed?.call(),
        onAdFailed: (message) {
          debugPrint('Spy: advert failed to show ($message)');
          finish(AdResult.failed);
        },
        // Completed, skipped or unknown - all three mean it was on screen and
        // the person has finished with it.
        onAdClosed: (_) => finish(AdResult.shown),
      );
    } catch (error) {
      debugPrint('Spy: advert would not show ($error)');
      finish(AdResult.failed);
    }

    final result = await closed.future;
    _showing = false;
    return result;
  }

  @override
  void dispose() {
    _ready = null;
    _showing = false;
  }
}

/// Turns the server's provider name into something that can show an advert.
///
/// An unknown name - a network a later build supports, or a typo in the config
/// file - returns [NoAdNetwork]. Adverts switching themselves off is a fine
/// outcome; the app guessing is not.
AdNetwork adNetworkFor(String provider) => switch (provider) {
      'tapsell' => TapsellNetwork(),
      _ => const NoAdNetwork(),
    };
