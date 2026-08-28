import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/ad_network.dart';
import '../services/telemetry.dart';
import 'remote.dart';
import 'settings.dart';

/// Why an advert did not appear.
///
/// Every path through the gate has a name, because "no ad" with no reason is
/// impossible to debug in the field and impossible to count on the admin page.
enum AdBlock {
  /// A round is live, or a deal is in progress. The hard rule.
  midGame,

  /// Bought their way out.
  adFree,

  /// The server has not switched adverts on, or this build does not know the
  /// network it named.
  disabled,

  /// Nothing configured to ask for.
  noZone,

  /// Has not finished enough rounds yet.
  quietRounds,

  /// Inside the cooldown, and this is not a fresh launch.
  cooldown,

  /// Inside the floor that a relaunch cannot get under.
  minGap,
}

/// The whole advert policy, as one pure function.
///
/// Nothing in here touches an SDK, a clock or a store, which is the point: the
/// rules are the part that must be right, so they are the part that is trivial
/// to test. [AdController] does the arranging; this decides.
///
/// The rule that is not negotiable is [AdBlock.midGame]. A full-screen advert
/// launches its own activity, which pauses Flutter, which is exactly what
/// `DossierCard` treats as somebody walking off with the phone - it seals the
/// card and voids the deal. An advert during a reveal would not be annoying,
/// it would destroy the round. So the gate refuses before anything else is
/// even considered.
abstract final class AdGate {
  /// Null means an advert may be shown.
  static AdBlock? check({
    required AdsConfig config,
    required String placement,
    required bool adFree,
    required bool gameIdle,
    required int roundsPlayed,
    required DateTime? lastAdAt,
    required DateTime launchedAt,
    required DateTime now,
    required bool networkReady,
  }) {
    if (!gameIdle) return AdBlock.midGame;
    if (adFree) return AdBlock.adFree;
    if (!config.allows(placement)) return AdBlock.disabled;
    if (!networkReady) return AdBlock.disabled;
    if (config.zone(placement).isEmpty) return AdBlock.noZone;
    if (roundsPlayed < config.quietRounds) return AdBlock.quietRounds;

    if (lastAdAt == null) return null;
    final since = now.difference(lastAdAt);

    // The floor comes first, and a relaunch does not get under it. Otherwise
    // closing and reopening the app is a way to see an advert every ten
    // seconds, and the person who works that out uninstalls.
    if (since < config.minGap) return AdBlock.minGap;

    if (since >= config.cooldown) return null;

    // Inside the cooldown, but the app has been restarted since the last one.
    // A new evening should not be silent because somebody played earlier.
    if (config.resetOnRestart && lastAdAt.isBefore(launchedAt)) return null;

    return AdBlock.cooldown;
  }
}

/// Arranges what [AdGate] decides.
///
/// Holds the rules the server sent, asks the network, records when one was
/// shown, and counts what happened. It never throws and it never blocks a tap
/// for longer than [budget] - a game that will not start because an advert
/// server is slow is a broken game.
class AdController extends ChangeNotifier {
  AdController({
    required SettingsStore settings,
    required SpyTelemetry telemetry,
    AdNetwork Function(String provider)? networkFactory,
    DateTime? launchedAt,
    Duration budget = const Duration(seconds: 8),
  }) : this._(
          settings,
          telemetry,
          networkFactory ?? adNetworkFor,
          launchedAt ?? DateTime.now(),
          budget,
        );

  AdController._(
    this._settings,
    this._telemetry,
    this._networkFactory,
    this.launchedAt,
    this.budget,
  );

  final SettingsStore _settings;
  final SpyTelemetry _telemetry;

  /// The one place an advert SDK enters the app. Injected so the rules can be
  /// tested against a network that behaves however the test needs, and so
  /// swapping Tapsell for something else is one argument.
  final AdNetwork Function(String provider) _networkFactory;

  AdNetwork _network = const NoAdNetwork();

  /// This process started here. The cooldown is measured against it, which is
  /// what makes "or when they restart the app" true.
  final DateTime launchedAt;

  /// The longest a tap will ever wait for an advert to *appear*.
  ///
  /// It stops counting the moment one is on screen. How long somebody then
  /// looks at it is their business, and cutting that short would start the
  /// game behind the advert.
  final Duration budget;

  AdsConfig _config = AdsConfig.off;
  bool _adFree = false;
  bool _showing = false;

  AdsConfig get config => _config;

  /// True when the phone is owed no adverts - bought, or remembered as bought
  /// from a launch when the server was reachable.
  bool get adFree => _adFree || _settings.value.adFree;

  bool get showing => _showing;

  /// The server has spoken. Called after every successful config fetch.
  ///
  /// The network is only started once adverts are actually switched on, so a
  /// build whose adverts are off never initialises an SDK, never opens a
  /// socket, and never touches an advertising identifier.
  Future<void> apply(RemoteConfig remote) async {
    _config = remote.ads;
    _adFree = remote.adFree;

    // Remembered locally so a paying customer who opens the app on a train
    // still sees no adverts.
    if (remote.adFree && !_settings.value.adFree) {
      await _settings.edit((old) => old.copyWith(adFree: true));
    }

    if (adFree || !_config.enabled) {
      _network.dispose();
      _network = const NoAdNetwork();
      notifyListeners();
      return;
    }

    final wanted = _networkFactory(_config.provider);
    if (wanted.name != _network.name) {
      _network.dispose();
      _network = wanted;
    }
    await _network.start(_config);

    // Fetched now so the advert is on the phone before anybody presses the
    // button. A tap that waits for a download is a tap that feels broken.
    final zone = _config.zone(AdsConfig.homeStart);
    if (zone.isNotEmpty) unawaited(_network.preload(zone));

    notifyListeners();
  }

  /// The decision, without acting on it. Used by tests and by the debug row.
  AdBlock? inspect({required bool gameIdle, DateTime? now}) => AdGate.check(
        config: _config,
        placement: AdsConfig.homeStart,
        adFree: adFree,
        gameIdle: gameIdle,
        roundsPlayed: _settings.value.roundsPlayed,
        lastAdAt: _settings.value.lastAdAt,
        launchedAt: launchedAt,
        now: now ?? DateTime.now(),
        networkReady: _network.name != 'none',
      );

  /// Shows an advert if every rule allows it, and returns when the screen is
  /// clear again. Always returns - never leaves a caller waiting on a game.
  Future<void> maybeShow({required bool gameIdle}) async {
    if (_showing) return;

    final blocked = inspect(gameIdle: gameIdle);
    if (blocked != null) {
      // Worth counting: the ratio of these to shown adverts is how you tell a
      // cooldown that is too tight from a network with no inventory.
      if (blocked != AdBlock.adFree && blocked != AdBlock.disabled) {
        _telemetry.record('ad_suppressed', detail: blocked.name);
      }
      return;
    }

    final zone = _config.zone(AdsConfig.homeStart);
    _showing = true;
    notifyListeners();
    _telemetry
      ..record('ad_eligible', detail: AdsConfig.homeStart)
      ..record('ad_requested', detail: AdsConfig.homeStart);

    final displayed = Completer<void>();

    // The failure handler is attached here, before anything is awaited. If the
    // budget below gives up first, this future is still outstanding - and a
    // future that fails with nobody listening is an unhandled error in
    // release, which is a crash rather than a missed advert.
    final settled = _network
        .show(
          zone,
          onDisplayed: () {
            if (!displayed.isCompleted) displayed.complete();
          },
        )
        .catchError((Object error) {
      debugPrint('Spy: advert failed ($error)');
      return AdResult.failed;
    });

    AdResult result;
    try {
      // Whichever comes first: the advert reaching the screen, or the attempt
      // giving up. The budget covers only that; once somebody is looking at an
      // advert, how long they look is their business and the game must not
      // start underneath them.
      await Future.any([displayed.future, settled.then<void>((_) {})])
          .timeout(budget);
      result = await settled;
    } on TimeoutException {
      // Never made it to the screen. The tap gets on with the game.
      result = AdResult.unavailable;
    }

    _showing = false;

    if (result == AdResult.shown) {
      _telemetry.record('ad_shown', detail: AdsConfig.homeStart);
      // Written before the game starts, so a crash mid-round cannot lose it
      // and hand somebody a second advert straight away.
      await _settings.edit((old) => old.copyWith(lastAdAt: DateTime.now()));
    } else {
      _telemetry.record('ad_failed', detail: result.name);
    }

    // The next one starts loading now, not when somebody presses the button.
    if (zone.isNotEmpty) unawaited(_network.preload(zone));
    notifyListeners();
  }

  @override
  void dispose() {
    _network.dispose();
    super.dispose();
  }
}

/// Fire and forget, with the failure said out loud in debug rather than
/// vanishing into an unhandled rejection.
void unawaited(Future<void> future) {
  future.catchError((Object error) {
    debugPrint('Spy: background advert work failed ($error)');
  });
}
