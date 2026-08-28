import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'settings.dart';
import 'pack_store.dart';
import 'word_packs.dart';

enum RoundPhase {
  /// No round. Home shows the last setup.
  idle,

  /// Cards are being handed round, one player at a time.
  dealing,

  /// The clock is running.
  running,
  paused,

  /// Time ran out, or somebody called it.
  verdict,

  /// A lifecycle event landed mid-deal. The whole deal is void.
  interrupted,
}

@immutable
class Player {
  const Player({required this.index, required this.name, required this.isSpy});

  /// Zero-based seat. Display is `index + 1` - there is never a "Player 0".
  final int index;

  /// As typed, or the numbered default. Never uppercased, never initialled.
  final String name;
  final bool isSpy;
}

/// One deal: the word, who is lying about it, and how far round the table the
/// phone has got.
@immutable
class SpyRound {
  const SpyRound({
    required this.players,
    required this.word,
    required this.pack,
    required this.length,
    required this.caseNumber,
    required this.round,
    required this.dealtCount,
    required this.spiesSeeCategory,
  });

  final List<Player> players;
  final String word;
  final WordPack pack;
  final Duration length;
  final int caseNumber;
  final int round;

  /// How many players have confirmed. The deal queue is a progress display,
  /// not a list you can tap.
  final int dealtCount;

  final bool spiesSeeCategory;

  Player get current => players[dealtCount];
  bool get isDealComplete => dealtCount >= players.length;
  List<Player> get spies => players.where((p) => p.isSpy).toList();

  SpyRound copyWith({int? dealtCount}) => SpyRound(
        players: players,
        word: word,
        pack: pack,
        length: length,
        caseNumber: caseNumber,
        round: round,
        dealtCount: dealtCount ?? this.dealtCount,
        spiesSeeCategory: spiesSeeCategory,
      );
}

/// Why a deal could not happen. Each one has a screen that states the reason
/// and offers the single action that fixes it.
sealed class DealFailure {
  const DealFailure();
}

class NoPacksEnabled extends DealFailure {
  const NoPacksEnabled();
}

/// The pack ran dry under "don't repeat words". Reshuffle, or turn on another.
class NotEnoughWords extends DealFailure {
  const NotEnoughWords(this.pack, this.used);

  final WordPack pack;
  final int used;
}

class GameController extends ChangeNotifier {
  GameController({math.Random? random}) : _random = random ?? math.Random();

  final math.Random _random;

  RoundPhase _phase = RoundPhase.idle;
  SpyRound? _round;

  /// Wall-clock end. The remaining time is always derived from this, never
  /// from a counter someone decremented - a decremented counter drifts, and it
  /// lies after the phone has been asleep.
  DateTime? _endsAt;
  Duration _pausedRemaining = Duration.zero;

  /// Whoever was holding the phone when a call landed, for the message that
  /// names the actor rather than blaming "an error".
  String? _interruptedHolder;

  final ValueNotifier<Duration> remaining = ValueNotifier(Duration.zero);

  RoundPhase get phase => _phase;
  SpyRound? get round => _round;
  String? get interruptedHolder => _interruptedHolder;
  bool get isLive => _phase == RoundPhase.running || _phase == RoundPhase.paused;

  /// Deals a round, or says exactly why it could not.
  ///
  /// [language] filters the packs: a Persian UI never draws an English word,
  /// because a language switch mid-game would be a tell.
  ({SpyRound? round, DealFailure? failure}) deal({
    required SpySettings settings,
    required String language,
    required String Function(int) defaultName,
    PackLibrary library = PackLibrary.bundled,
  }) {
    // The library, not the compiled-in list: a downloaded pack deals exactly
    // like a bundled one, and by the time the dealer sees them there is no
    // difference between the two.
    final packs = library
        .forLanguage(language)
        .where((p) => settings.enabledPacks.contains(p.id))
        .toList();
    if (packs.isEmpty) return (round: null, failure: const NoPacksEnabled());

    final candidates = <({WordPack pack, String word})>[];
    for (final pack in packs) {
      final played = settings.playedWords[pack.id] ?? const <String>{};
      for (final word in pack.words) {
        if (settings.noRepeatWords && played.contains(word)) continue;
        candidates.add((pack: pack, word: word));
      }
    }
    if (candidates.isEmpty) {
      // Name the pack that ran out - with several on, "no words left" alone
      // does not tell anyone which one to reshuffle.
      final emptiest = packs.reduce((a, b) {
        final usedA = settings.playedWords[a.id]?.length ?? 0;
        final usedB = settings.playedWords[b.id]?.length ?? 0;
        return usedA / a.size >= usedB / b.size ? a : b;
      });
      return (
        round: null,
        failure: NotEnoughWords(
          emptiest,
          settings.playedWords[emptiest.id]?.length ?? 0,
        )
      );
    }

    final pick = candidates[_random.nextInt(candidates.length)];
    final playerCount = settings.players;
    final spyCount = settings.effectiveSpies;

    final spySeats = <int>{};
    while (spySeats.length < spyCount) {
      spySeats.add(_random.nextInt(playerCount));
    }

    final names = settings.playerNames;
    final players = [
      for (var i = 0; i < playerCount; i++)
        Player(
          index: i,
          name: (i < names.length && names[i].trim().isNotEmpty)
              ? names[i].trim()
              : defaultName(i + 1),
          isSpy: spySeats.contains(i),
        ),
    ];
    // Seat order is the order the names were typed, 1..N, and it stays that
    // way: the phone goes round the table in the order people are sitting, and
    // a queue that jumps about is a queue somebody gets missed out of. The
    // randomness is entirely in `spySeats` - the role, not the turn.

    _round = SpyRound(
      players: players,
      word: pick.word,
      pack: pick.pack,
      length: settings.roundLength,
      caseNumber: settings.caseNumber,
      round: settings.round,
      dealtCount: 0,
      spiesSeeCategory: settings.spiesSeeCategory,
    );
    _phase = RoundPhase.dealing;
    _interruptedHolder = null;
    remaining.value = settings.roundLength;
    notifyListeners();
    return (round: _round, failure: null);
  }

  /// The current player confirmed. There is no way back to their card - once
  /// confirmed, a word is unreachable for the round.
  void confirmSeen() {
    final round = _round;
    if (round == null || _phase != RoundPhase.dealing) return;
    _round = round.copyWith(dealtCount: round.dealtCount + 1);
    notifyListeners();
  }

  void startClock() {
    final round = _round;
    if (round == null) return;
    _phase = RoundPhase.running;
    _endsAt = DateTime.now().add(round.length);
    remaining.value = round.length;
    notifyListeners();
  }

  /// Recomputes from the wall clock. Called on every tick and on resume, so a
  /// round survives the phone being locked, backgrounded or killed.
  void syncClock() {
    if (_phase != RoundPhase.running) return;
    final endsAt = _endsAt;
    if (endsAt == null) return;
    final left = endsAt.difference(DateTime.now());
    remaining.value = left.isNegative ? Duration.zero : left;
    if (left <= Duration.zero) callIt();
  }

  void pause() {
    if (_phase != RoundPhase.running) return;
    _pausedRemaining = remaining.value;
    _phase = RoundPhase.paused;
    notifyListeners();
  }

  void resume() {
    if (_phase != RoundPhase.paused) return;
    _endsAt = DateTime.now().add(_pausedRemaining);
    _phase = RoundPhase.running;
    notifyListeners();
  }

  /// The normal ending. No confirm - calling it is how a round finishes.
  void callIt() {
    if (_phase == RoundPhase.verdict) return;
    _phase = RoundPhase.verdict;
    _endsAt = null;
    notifyListeners();
  }

  /// A lifecycle event landed mid-deal. The whole deal is void: resuming would
  /// mean a phone showing a secret word to whoever is holding it when the call
  /// ends.
  void interrupt(String holder) {
    if (_phase != RoundPhase.dealing) return;
    _interruptedHolder = holder;
    _phase = RoundPhase.interrupted;
    notifyListeners();
  }

  /// Throws the word away. Nobody finds out who the spy was.
  void abandon() {
    _round = null;
    _endsAt = null;
    _phase = RoundPhase.idle;
    remaining.value = Duration.zero;
    notifyListeners();
  }

  @override
  void dispose() {
    remaining.dispose();
    super.dispose();
  }
}
