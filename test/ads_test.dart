import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spy/app.dart';
import 'package:spy/data/ads.dart';
import 'package:spy/data/game.dart';
import 'package:spy/data/pack_store.dart';
import 'package:spy/data/remote.dart';
import 'package:spy/data/settings.dart';
import 'package:spy/data/update_store.dart';
import 'package:spy/services/ad_network.dart';
import 'package:spy/services/api.dart';
import 'package:spy/services/telemetry.dart';

/// The advert rules.
///
/// This is the file to read before changing anything about adverts, and the
/// file that will fail if somebody ever makes one appear during a round.
void main() {
  final launched = DateTime(2026, 8, 22, 20, 00);

  AdsConfig live({
    Duration cooldown = const Duration(minutes: 20),
    Duration minGap = const Duration(seconds: 90),
    bool resetOnRestart = true,
    int quietRounds = 1,
  }) =>
      AdsConfig(
        enabled: true,
        provider: 'tapsell',
        cooldown: cooldown,
        minGap: minGap,
        resetOnRestart: resetOnRestart,
        quietRounds: quietRounds,
        placements: const {AdsConfig.homeStart: true},
        zones: const {AdsConfig.homeStart: 'zone-1'},
      );

  AdBlock? check({
    AdsConfig? config,
    bool adFree = false,
    bool gameIdle = true,
    int roundsPlayed = 5,
    DateTime? lastAdAt,
    DateTime? now,
    bool networkReady = true,
  }) =>
      AdGate.check(
        config: config ?? live(),
        placement: AdsConfig.homeStart,
        adFree: adFree,
        gameIdle: gameIdle,
        roundsPlayed: roundsPlayed,
        lastAdAt: lastAdAt,
        launchedAt: launched,
        now: now ?? launched.add(const Duration(minutes: 1)),
        networkReady: networkReady,
      );

  group('the gate', () {
    test('an advert never appears mid-game, whatever else is true', () {
      // The one rule with no exception. A full-screen advert pauses Flutter,
      // and a paused Flutter during a reveal seals the card and voids the
      // deal - this is not an annoyance, it is a destroyed round.
      expect(check(gameIdle: false), AdBlock.midGame);
      expect(
        check(gameIdle: false, adFree: true, roundsPlayed: 999),
        AdBlock.midGame,
        reason: 'mid-game is checked before anything that could override it',
      );
    });

    test('somebody who paid never sees one', () {
      expect(check(adFree: true), AdBlock.adFree);
    });

    test('adverts are off until a server switches them on', () {
      expect(check(config: AdsConfig.off), AdBlock.disabled);
      expect(
        check(config: const AdsConfig(enabled: true)),
        AdBlock.disabled,
        reason: 'enabled with no placement is still no placement',
      );
    });

    test('a network this build does not carry shows nothing', () {
      expect(check(networkReady: false), AdBlock.disabled);
    });

    test('a placement with no zone asks for nothing', () {
      final noZone = AdsConfig(
        enabled: true,
        provider: 'tapsell',
        placements: const {AdsConfig.homeStart: true},
        zones: const {},
      );
      expect(check(config: noZone), AdBlock.noZone);
    });

    test('the first rounds are quiet', () {
      expect(check(roundsPlayed: 0), AdBlock.quietRounds);
      expect(check(roundsPlayed: 1), isNull);
      expect(
        check(config: live(quietRounds: 3), roundsPlayed: 2),
        AdBlock.quietRounds,
      );
    });

    test('the very first eligible game shows one', () {
      expect(check(lastAdAt: null), isNull);
    });

    group('the cooldown', () {
      test('holds for twenty minutes inside one session', () {
        // Shown after launch, so this is the same run of the app.
        final shown = launched.add(const Duration(minutes: 5));
        expect(
          check(lastAdAt: shown, now: shown.add(const Duration(minutes: 19))),
          AdBlock.cooldown,
        );
      });

      test('lets go once twenty minutes have passed', () {
        final shown = launched.add(const Duration(minutes: 5));
        expect(
          check(lastAdAt: shown, now: shown.add(const Duration(minutes: 20))),
          isNull,
        );
      });

      test('is cleared by restarting the app', () {
        // Shown before this process started: a different session, a new
        // evening, and the cooldown does not carry over.
        final shown = launched.subtract(const Duration(minutes: 5));
        expect(
          check(lastAdAt: shown, now: launched.add(const Duration(minutes: 1))),
          isNull,
        );
      });

      test('is not cleared by a restart when the server says not to', () {
        final shown = launched.subtract(const Duration(minutes: 5));
        expect(
          check(
            config: live(resetOnRestart: false),
            lastAdAt: shown,
            now: launched.add(const Duration(minutes: 1)),
          ),
          AdBlock.cooldown,
        );
      });

      test('a restart cannot get under the floor', () {
        // Closing and reopening the app must not be a way to see an advert
        // every ten seconds. Whoever finds that out uninstalls.
        final shown = launched.subtract(const Duration(seconds: 30));
        expect(
          check(lastAdAt: shown, now: launched.add(const Duration(seconds: 5))),
          AdBlock.minGap,
        );
      });
    });
  });

  group('the controller', () {
    Future<({AdController ads, SettingsStore settings, SpyTelemetry counters})>
        build({
      AdsConfig? config,
      bool adFree = false,
      FakeAdNetwork? network,
      int roundsPlayed = 5,
      Duration budget = const Duration(seconds: 8),
    }) async {
      final settings = await SettingsStore.open(backend: MemorySettingsBackend());
      await settings.update(SpySettings(
        installId: 'test-install-id',
        roundsPlayed: roundsPlayed,
      ));
      final counters = SpyTelemetry(
        api: SpyApi(baseUrl: 'https://api.test', fetch: _nothing),
        installId: 'test-install-id',
        flushAfter: const Duration(minutes: 10),
      );
      addTearDown(counters.dispose);
      final ads = AdController(
        settings: settings,
        telemetry: counters,
        launchedAt: DateTime.now(),
        budget: budget,
        networkFactory: (_) => network ?? FakeAdNetwork(),
      );
      await ads.apply(_remote(ads: config ?? live(), adFree: adFree));
      return (ads: ads, settings: settings, counters: counters);
    }

    test('an advert is shown, and starts a cooldown', () async {
      final network = FakeAdNetwork();
      final harness = await build(network: network);

      await harness.ads.maybeShow(gameIdle: true);

      expect(network.shown, 1);
      expect(harness.settings.value.lastAdAt, isNotNull);
      expect(
        harness.counters.pending.map((e) => e.kind),
        containsAll(<String>['ad_requested', 'ad_shown']),
      );
    });

    test('a network with nothing to show does not start a cooldown', () async {
      final network = FakeAdNetwork(result: AdResult.unavailable);
      final harness = await build(network: network);

      await harness.ads.maybeShow(gameIdle: true);

      expect(
        harness.settings.value.lastAdAt,
        isNull,
        reason: 'an advert nobody saw must not buy twenty minutes of silence',
      );
      expect(harness.counters.pending.map((e) => e.kind), contains('ad_failed'));
    });

    test('a network that hangs does not hold up the game', () async {
      final network = FakeAdNetwork(hang: true);
      final harness = await build(
        network: network,
        budget: const Duration(milliseconds: 50),
      );

      final started = DateTime.now();
      await harness.ads.maybeShow(gameIdle: true);
      final waited = DateTime.now().difference(started);

      expect(waited, lessThan(const Duration(seconds: 2)));
      expect(harness.settings.value.lastAdAt, isNull);
    });

    test('a long advert is not cut short by the budget', () async {
      // The budget is for getting an advert on screen, not for how long
      // somebody looks at one. Cutting this short would start the game behind
      // a full-screen advert.
      final network = FakeAdNetwork()..watched = const Duration(milliseconds: 300);
      final harness = await build(
        network: network,
        budget: const Duration(milliseconds: 50),
      );

      await harness.ads.maybeShow(gameIdle: true);

      expect(harness.settings.value.lastAdAt, isNotNull);
      expect(
        harness.counters.pending.map((e) => e.kind),
        contains('ad_shown'),
      );
    });

    test('a network that throws does not hold up the game', () async {
      final harness = await build(network: FakeAdNetwork(explode: true));
      await harness.ads.maybeShow(gameIdle: true);
      expect(harness.settings.value.lastAdAt, isNull);
    });

    test('nothing is asked of a network while adverts are off', () async {
      final network = FakeAdNetwork();
      final harness = await build(config: AdsConfig.off, network: network);

      await harness.ads.maybeShow(gameIdle: true);

      expect(network.started, isFalse, reason: 'an SDK nobody needs is never started');
      expect(network.shown, 0);
    });

    test('a purchase is remembered, so a train journey stays quiet', () async {
      final network = FakeAdNetwork();
      final harness = await build(adFree: true, network: network);

      expect(harness.settings.value.adFree, isTrue);
      await harness.ads.maybeShow(gameIdle: true);
      expect(network.shown, 0);
      expect(network.started, isFalse);
    });

    test('a mid-game call is refused even if everything else is ready',
        () async {
      final network = FakeAdNetwork();
      final harness = await build(network: network);

      await harness.ads.maybeShow(gameIdle: false);

      expect(network.shown, 0);
      expect(
        harness.counters.pending
            .where((e) => e.kind == 'ad_suppressed')
            .map((e) => e.detail),
        contains('midGame'),
      );
    });
  });

  group('on screen', () {
    Future<({FakeAdNetwork network, SettingsStore settings})> pump(
      WidgetTester tester, {
      required bool hasPlayed,
      int roundsPlayed = 5,
      AdsConfig? config,
    }) async {
      final settings = await SettingsStore.open(backend: MemorySettingsBackend());
      await settings.update(SpySettings(
        players: 3,
        installId: 'test-install-id',
        roundsPlayed: roundsPlayed,
        lastPlayedAt: hasPlayed ? DateTime.now() : null,
      ));

      final api = SpyApi(baseUrl: 'https://api.test', fetch: _nothing);
      final network = FakeAdNetwork();
      final counters = SpyTelemetry(
        api: api,
        installId: 'test-install-id',
        flushAfter: const Duration(minutes: 10),
      );
      addTearDown(counters.dispose);
      final ads = AdController(
        settings: settings,
        telemetry: counters,
        networkFactory: (_) => network,
      );
      await ads.apply(_remote(ads: config ?? live()));

      await tester.pumpWidget(SpyApp(
        settings: settings,
        game: GameController(),
        packs: PackStore(vault: MemoryPackVault(), api: api),
        updates: UpdateStore(api: api),
        ads: ads,
        telemetry: counters,
      ));
      await tester.pumpAndSettle();
      return (network: network, settings: settings);
    }

    testWidgets('Same again shows an advert, then deals', (tester) async {
      final harness = await pump(tester, hasPlayed: true);

      await tester.tap(find.text('SAME AGAIN'));
      await tester.pumpAndSettle();

      expect(harness.network.shown, 1);
      // And the game still started - the advert is on the way to it, never
      // instead of it.
      expect(find.text('PASS THE PHONE TO'), findsOneWidget);
    });

    testWidgets('a first run never meets an advert', (tester) async {
      final harness = await pump(tester, hasPlayed: false, roundsPlayed: 0);

      expect(find.text('SET UP A GAME'), findsOneWidget);
      await tester.tap(find.text('SET UP A GAME'));
      await tester.pumpAndSettle();

      expect(
        harness.network.shown,
        0,
        reason: 'somebody who has not played yet meets the game, not a network',
      );
    });

    testWidgets('no second advert on the next game, twenty minutes not passed',
        (tester) async {
      final harness = await pump(tester, hasPlayed: true);

      await tester.tap(find.text('SAME AGAIN'));
      await tester.pumpAndSettle();
      expect(harness.network.shown, 1);

      // Back to Home the way somebody would: abandon, then deal again.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abandon'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('SAME AGAIN'));
      await tester.pumpAndSettle();

      expect(
        harness.network.shown,
        1,
        reason: 'two adverts inside one evening is how a game gets uninstalled',
      );
    });
  });

  group('the packs nudge', () {
    Future<void> pumpHome(
      WidgetTester tester, {
      required int roundsPlayed,
      DateTime? nudgedAt,
    }) async {
      final settings = await SettingsStore.open(backend: MemorySettingsBackend());
      await settings.update(SpySettings(
        installId: 'test-install-id',
        roundsPlayed: roundsPlayed,
        packsNudgedAt: nudgedAt,
        lastPlayedAt: roundsPlayed > 0 ? DateTime.now() : null,
      ));
      final api = SpyApi(baseUrl: 'https://api.test', fetch: _nothing);
      await tester.pumpWidget(SpyApp(
        settings: settings,
        game: GameController(),
        packs: PackStore(vault: MemoryPackVault(), api: api),
        updates: UpdateStore(api: api),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('nothing is said until somebody has actually played',
        (tester) async {
      await pumpHome(tester, roundsPlayed: 0);
      expect(find.text('There are more word packs than these'), findsNothing);
    });

    testWidgets('after a couple of rounds it offers, quietly', (tester) async {
      await pumpHome(tester, roundsPlayed: 2);
      expect(find.text('There are more word packs than these'), findsOneWidget);
      expect(find.text('Not now'), findsOneWidget);
      // Never in the way of the thing everybody came for.
      expect(find.text('SAME AGAIN'), findsOneWidget);
    });

    testWidgets('"not now" puts it away', (tester) async {
      await pumpHome(tester, roundsPlayed: 2);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(find.text('There are more word packs than these'), findsNothing);
    });

    testWidgets('a recent dismissal stays dismissed', (tester) async {
      await pumpHome(
        tester,
        roundsPlayed: 9,
        nudgedAt: DateTime.now().subtract(const Duration(hours: 2)),
      );
      expect(find.text('There are more word packs than these'), findsNothing);
    });
  });
}

RemoteConfig _remote({required AdsConfig ads, bool adFree = false}) =>
    RemoteConfig(
      latestBuild: 1,
      latestVersion: '1.0.0',
      minSupportedBuild: 1,
      updateUrl: '',
      ads: ads,
      adFree: adFree,
    );

/// A server that is not there. Every call fails the way a plane does.
Future<ApiResponse> _nothing(Uri uri, {String? body}) async =>
    ApiResponse(200, Uint8List.fromList(utf8.encode('{}')));

/// An advert network that does exactly what a test tells it to.
class FakeAdNetwork extends AdNetwork {
  FakeAdNetwork({
    this.result = AdResult.shown,
    this.hang = false,
    this.explode = false,
  });

  final AdResult result;

  /// Never completes - the case the controller's budget exists for.
  final bool hang;

  /// Throws instead of answering.
  final bool explode;

  bool started = false;
  int preloads = 0;
  int shown = 0;

  @override
  String get name => 'tapsell';

  @override
  Future<void> start(AdsConfig config) async => started = true;

  @override
  Future<void> preload(String zone) async => preloads++;

  /// How long the advert stays on screen once displayed. A person watching a
  /// fifteen-second advert must not have the game start underneath them.
  Duration watched = Duration.zero;

  @override
  Future<AdResult> show(String zone, {VoidCallback? onDisplayed}) async {
    if (explode) throw StateError('the network fell over');
    if (hang) return Completer<AdResult>().future;
    shown++;
    onDisplayed?.call();
    if (watched > Duration.zero) await Future<void>.delayed(watched);
    return result;
  }

  @override
  void dispose() {}
}
