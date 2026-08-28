import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spy/app.dart';
import 'package:spy/data/game.dart';
import 'package:spy/data/settings.dart';
import 'package:spy/screens/home.dart';
import 'package:spy/screens/timer.dart';
import 'package:spy/screens/verdict.dart';
import 'package:spy/widgets/dossier_card.dart';
import 'package:spy/widgets/rows.dart';

/// The 45-second test, walked end to end.
///
/// Open -> deal -> [handoff -> drag -> I've got it] x N -> the clock -> the
/// verdict. If this breaks, the app does not work, whatever the unit tests say.
void main() {
  Future<GameController> pumpApp(
    WidgetTester tester, {
    int players = 3,
  }) async {
    final store = await SettingsStore.open(backend: MemorySettingsBackend());
    await store.update(SpySettings(
      players: players,
      spies: 1,
      roundLength: const Duration(minutes: 8),
    ));
    final game = GameController();
    await tester.pumpWidget(SpyApp(settings: store, game: game));
    await tester.pumpAndSettle();
    return game;
  }

  /// One player's turn: confirm the name, drag the slider, confirm the card.
  ///
  /// [last] pumps fixed frames instead of settling, because confirming the
  /// last card lands on the clock - and a running clock schedules a frame
  /// every frame, so `pumpAndSettle` would spin there until it gave up.
  Future<void> takeTurn(WidgetTester tester, {bool last = false}) async {
    await tester.tap(find.textContaining("I'M "));
    await tester.pumpAndSettle();

    expect(find.byType(DossierCard), findsOneWidget);

    final slider = tester.getRect(find.byType(Slider));
    final gesture = await tester.startGesture(
      Offset(slider.left + slider.width * 0.9, slider.center.dy),
    );
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    await tester.tap(find.text("I'VE GOT IT"));
    if (last) {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    } else {
      await tester.pumpAndSettle();
    }
  }

  testWidgets('a first run opens on Home, with the rules one tap away',
      (tester) async {
    await pumpApp(tester);

    // Nothing stands between opening the app and dealing - not even on the
    // very first run.
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('SET UP A GAME'), findsOneWidget);

    await tester.tap(find.text('How to play'));
    await tester.pumpAndSettle();
    expect(find.text('HOW TO PLAY'), findsOneWidget);

    // And it closes back onto Home rather than routing anywhere.
    await tester.tap(find.text('GOT IT'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('a returning player leads with Same again', (tester) async {
    final store = await SettingsStore.open(backend: MemorySettingsBackend());
    await store.update(SpySettings(lastPlayedAt: DateTime.now()));
    await tester.pumpWidget(SpyApp(settings: store, game: GameController()));
    await tester.pumpAndSettle();

    expect(find.text('SAME AGAIN'), findsOneWidget);
    expect(find.text('CHANGE SETUP'), findsOneWidget);
    expect(find.text('SET UP A GAME'), findsNothing);
  });

  testWidgets('the whole loop runs: deal, three cards, clock, verdict',
      (tester) async {
    final game = await pumpApp(tester, players: 3);

    // Nothing played yet, so the primary action is setup.
    expect(find.text('SET UP A GAME'), findsOneWidget);
    await tester.tap(find.text('SET UP A GAME'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('DEAL THE CARDS'));
    await tester.pumpAndSettle();

    expect(game.phase, RoundPhase.dealing);
    expect(find.text('PASS THE PHONE TO'), findsOneWidget);

    await takeTurn(tester);
    expect(game.round!.dealtCount, 1);

    await takeTurn(tester);
    await takeTurn(tester, last: true);

    // Last card confirmed hands straight to the clock.
    expect(find.byType(TimerScreen), findsOneWidget);
    expect(game.phase, RoundPhase.running);
    expect(game.remaining.value.inMinutes, 7, reason: 'the clock is draining');

    await tester.tap(find.text('CALL IT — REVEAL'));
    await tester.pumpAndSettle();

    expect(find.byType(VerdictScreen), findsOneWidget);
    expect(game.phase, RoundPhase.verdict);
    // The word and exactly one spy stamp.
    expect(find.text('THE WORD WAS'), findsOneWidget);
    expect(find.text('THE SPY WAS'), findsOneWidget);
  });

  testWidgets('the deal queue cannot be walked backwards', (tester) async {
    final game = await pumpApp(tester, players: 3);
    await tester.tap(find.text('SET UP A GAME'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DEAL THE CARDS'));
    await tester.pumpAndSettle();

    await takeTurn(tester);
    final secondPlayer = game.round!.current.name;

    // Android back during the deal must not drop a player out of the queue.
    final popped = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(popped, isTrue);
    expect(find.text('ABANDON THE ROUND?'), findsOneWidget);

    await tester.tap(find.text('Keep playing'));
    await tester.pumpAndSettle();
    expect(game.round!.current.name, secondPlayer);
    expect(game.phase, RoundPhase.dealing);
  });

  testWidgets('abandoning from the deal returns to Home with no round',
      (tester) async {
    final game = await pumpApp(tester, players: 3);
    await tester.tap(find.text('SET UP A GAME'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DEAL THE CARDS'));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abandon'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(game.round, isNull);
    expect(game.phase, RoundPhase.idle);
  });

  testWidgets('dealing spends the word so the next round cannot repeat it',
      (tester) async {
    final store = await SettingsStore.open(backend: MemorySettingsBackend());
    await store.update(const SpySettings(
      players: 3,
      enabledPacks: {'places'},
    ));
    final game = GameController();
    await tester.pumpWidget(SpyApp(settings: store, game: game));
    await tester.pumpAndSettle();

    await tester.tap(find.text('SET UP A GAME'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DEAL THE CARDS'));
    await tester.pumpAndSettle();

    final word = game.round!.word;
    expect(store.value.playedWords['places'], contains(word));
    expect(store.value.lastPlayedAt, isNotNull);
  });

  testWidgets('a named player is greeted by name, as typed', (tester) async {
    final store = await SettingsStore.open(backend: MemorySettingsBackend());
    await store.update(const SpySettings(
      players: 3,
      playerNames: ['Amir-Hossein', '', 'Sara'],
    ));
    final game = GameController();
    await tester.pumpWidget(SpyApp(settings: store, game: game));
    await tester.pumpAndSettle();

    await tester.tap(find.text('SET UP A GAME'));
    await tester.pumpAndSettle();

    // Set up carries no text input; names live behind a sheet.
    expect(find.byType(TextField), findsNothing);
    // Set up scrolls at this viewport, so bring the row into view first.
    final namesRow = find.byType(SpySettingRow);
    await tester.ensureVisible(namesRow);
    await tester.pumpAndSettle();
    await tester.tap(namesRow);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(3));

    await tester.tap(find.text('DONE'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('DEAL THE CARDS'));
    await tester.pumpAndSettle();

    // Names survive the round trip exactly as typed - never uppercased, never
    // title-cased, never initialled - and the blank one stays numbered. In the
    // order they were entered, too: seat 1 is whoever was typed first.
    expect(
      game.round!.players.map((p) => p.name).toList(),
      ['Amir-Hossein', 'Player 2', 'Sara'],
    );

    // The handoff greets whoever is first by that same name. Only the button
    // style uppercases it; the stored name is untouched.
    final greeting = tester
        .widgetList<Text>(find.textContaining("I'M "))
        .map((t) => t.data!)
        .single;
    expect(greeting, "I'M ${game.round!.players.first.name.toUpperCase()}");
  });
}
