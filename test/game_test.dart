import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:spy/data/game.dart';
import 'package:spy/data/settings.dart';
import 'package:spy/data/word_packs.dart';

/// The dealer's contract: everyone gets the same word except the spies, the
/// spy count is legal, and nobody is handed a word the pack has already spent.
void main() {
  ({SpyRound? round, DealFailure? failure}) dealWith(
    SpySettings settings, {
    String language = 'en',
    int seed = 1,
  }) {
    return GameController(random: Random(seed)).deal(
      settings: settings,
      language: language,
      defaultName: (n) => 'Player $n',
    );
  }

  group('dealing', () {
    test('every player gets a seat, and exactly the requested spies lie', () {
      final result = dealWith(const SpySettings(players: 7, spies: 2));
      final round = result.round!;

      expect(round.players, hasLength(7));
      expect(round.spies, hasLength(2));
      expect(
        round.players.map((p) => p.index),
        List.generate(7, (i) => i),
        reason: 'seats are 0..n-1 with no gaps, so "Player 3 of 7" is honest',
      );
    });

    test('the word comes from an enabled pack and is a real word in it', () {
      final result = dealWith(
        const SpySettings(players: 4, enabledPacks: {'places'}),
      );
      final round = result.round!;

      expect(round.pack.id, 'places');
      expect(WordPacks.places.words, contains(round.word));
    });

    test('a spy count above the ceiling is clamped, not dealt', () {
      // Four spies among seven is not a deduction game.
      final result = dealWith(const SpySettings(players: 7, spies: 4));
      expect(result.round!.spies, hasLength(SpySettings.spyCeiling(7)));
    });

    test('the ceiling always leaves at least two civilians', () {
      for (var players = SpySettings.minPlayers;
          players <= SpySettings.maxPlayers;
          players++) {
        final ceiling = SpySettings.spyCeiling(players);
        expect(ceiling, greaterThanOrEqualTo(1));
        expect(players - ceiling, greaterThanOrEqualTo(2),
            reason: '$players players must keep two people who know the word');
      }
    });

    test('no packs on is a stated failure, not an empty round', () {
      final result = dealWith(const SpySettings(enabledPacks: {}));
      expect(result.round, isNull);
      expect(result.failure, isA<NoPacksEnabled>());
    });

    test('a Persian round never draws an English word', () {
      final result = dealWith(
        // Both languages' packs switched on, as they are after a language
        // switch - the deal still has to pick a side.
        const SpySettings(players: 4, enabledPacks: {'places', 'iran'}),
        language: 'fa',
      );
      expect(result.round!.pack.id, 'iran');
      expect(WordPacks.iran.words, contains(result.round!.word));
    });

    test('"don\'t repeat words" skips what has already been played', () {
      // Everything but one word is spent, so the deal has only one legal
      // answer left.
      final spent = WordPacks.places.words.toSet()
        ..remove(WordPacks.places.words.last);
      final result = dealWith(
        SpySettings(
          players: 4,
          enabledPacks: const {'places'},
          playedWords: {'places': spent},
        ),
      );
      expect(result.round!.word, WordPacks.places.words.last);
    });

    test('an exhausted pack names itself so the player knows what to reshuffle',
        () {
      final result = dealWith(
        SpySettings(
          players: 4,
          enabledPacks: const {'places'},
          playedWords: {'places': WordPacks.places.words.toSet()},
        ),
      );
      expect(result.round, isNull);
      final failure = result.failure;
      expect(failure, isA<NotEnoughWords>());
      expect((failure as NotEnoughWords).pack.id, 'places');
      expect(failure.used, WordPacks.places.size);
    });

    test('repeats are allowed again once the setting is off', () {
      final result = dealWith(
        SpySettings(
          players: 4,
          noRepeatWords: false,
          enabledPacks: const {'places'},
          playedWords: {'places': WordPacks.places.words.toSet()},
        ),
      );
      expect(result.round, isNotNull);
    });
  });

  group('the deal queue', () {
    test('confirming walks forward and never back', () {
      final game = GameController(random: Random(3));
      game.deal(
        settings: const SpySettings(players: 3),
        language: 'en',
        defaultName: (n) => 'Player $n',
      );

      expect(game.round!.dealtCount, 0);
      expect(game.round!.current.index, 0);

      game.confirmSeen();
      expect(game.round!.dealtCount, 1);
      expect(game.round!.isDealComplete, isFalse);

      game.confirmSeen();
      game.confirmSeen();
      expect(game.round!.isDealComplete, isTrue);
    });

    test('confirming does nothing once the clock is running', () {
      final game = GameController(random: Random(3));
      game.deal(
        settings: const SpySettings(players: 3),
        language: 'en',
        defaultName: (n) => 'Player $n',
      );
      game.confirmSeen();
      game.confirmSeen();
      game.confirmSeen();
      game.startClock();

      game.confirmSeen();
      expect(game.round!.dealtCount, 3, reason: 'no re-reveal, ever');
    });
  });

  group('the clock', () {
    late GameController game;

    setUp(() {
      game = GameController(random: Random(5));
      game.deal(
        settings: const SpySettings(
          players: 3,
          roundLength: Duration(minutes: 8),
        ),
        language: 'en',
        defaultName: (n) => 'Player $n',
      );
    });

    test('starts at the full round length', () {
      game.startClock();
      expect(game.phase, RoundPhase.running);
      expect(game.remaining.value.inMinutes, 8);
    });

    test('pausing holds the remaining time and resuming keeps it', () {
      game.startClock();
      game.pause();
      final held = game.remaining.value;
      expect(game.phase, RoundPhase.paused);

      game.resume();
      expect(game.phase, RoundPhase.running);
      expect(
        (game.remaining.value - held).abs(),
        lessThan(const Duration(seconds: 1)),
      );
    });

    test('a paused clock does not drain', () {
      game.startClock();
      game.pause();
      final held = game.remaining.value;
      game.syncClock();
      expect(game.remaining.value, held);
    });

    test('calling it goes straight to the verdict, no confirm', () {
      game.startClock();
      game.callIt();
      expect(game.phase, RoundPhase.verdict);
    });

    test('an expired clock lands on the verdict rather than going negative', () {
      game.deal(
        settings: const SpySettings(
          players: 3,
          roundLength: Duration.zero,
        ),
        language: 'en',
        defaultName: (n) => 'Player $n',
      );
      game.startClock();
      game.syncClock();
      expect(game.remaining.value, Duration.zero);
      expect(game.phase, RoundPhase.verdict);
    });
  });

  group('interruption and abandonment', () {
    test('an interrupted deal names who was holding the phone', () {
      final game = GameController(random: Random(7));
      game.deal(
        settings: const SpySettings(players: 4),
        language: 'en',
        defaultName: (n) => 'Player $n',
      );

      game.interrupt('Sara');
      expect(game.phase, RoundPhase.interrupted);
      expect(game.interruptedHolder, 'Sara');
    });

    test('a running round cannot be interrupted into a void deal', () {
      final game = GameController(random: Random(7));
      game.deal(
        settings: const SpySettings(players: 4),
        language: 'en',
        defaultName: (n) => 'Player $n',
      );
      game.startClock();

      game.interrupt('Sara');
      expect(game.phase, RoundPhase.running,
          reason: 'the verdict survives backgrounding; there is nothing left '
              'to protect once every card has been seen');
    });

    test('abandoning throws the word away', () {
      final game = GameController(random: Random(9));
      game.deal(
        settings: const SpySettings(players: 4),
        language: 'en',
        defaultName: (n) => 'Player $n',
      );
      game.abandon();

      expect(game.round, isNull);
      expect(game.phase, RoundPhase.idle);
      expect(game.remaining.value, Duration.zero);
    });
  });

  group('player names', () {
    test('blank and missing names fall back to the numbered default', () {
      final result = dealWith(
        const SpySettings(players: 3, playerNames: ['Sara', '  ']),
      );
      final names = result.round!.players.map((p) => p.name).toSet();
      expect(names, contains('Sara'));
      expect(names.where((n) => n.startsWith('Player ')), hasLength(2));
      expect(names, isNot(contains('Player 0')));
    });

    test('names are kept exactly as typed', () {
      final result = dealWith(
        const SpySettings(players: 3, playerNames: ['Amir-Hossein']),
      );
      expect(
        result.round!.players.map((p) => p.name),
        contains('Amir-Hossein'),
        reason: 'never uppercased, never title-cased, never initialled',
      );
    });

    test('the queue follows the order the names were entered, every seed', () {
      const settings = SpySettings(
        players: 5,
        spies: 1,
        playerNames: ['Ada', 'Bea', '', 'Dai', 'Eve'],
      );
      // The phone goes round the table in seating order. Nothing about the
      // deal may reorder it - only who is lying is random.
      for (var seed = 0; seed < 25; seed++) {
        final round = dealWith(settings, seed: seed).round!;
        expect(
          round.players.map((p) => p.name).toList(),
          ['Ada', 'Bea', 'Player 3', 'Dai', 'Eve'],
          reason: 'seed $seed reordered the queue',
        );
      }
    });

    test('the spy still moves about, seat order or not', () {
      const settings = SpySettings(players: 5, spies: 1);
      final seats = {
        for (var seed = 0; seed < 40; seed++)
          dealWith(settings, seed: seed).round!.spies.single.index,
      };
      expect(
        seats.length,
        greaterThan(1),
        reason: 'a fixed queue must not mean a fixed spy',
      );
    });
  });
}
