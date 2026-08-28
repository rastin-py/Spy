import 'package:flutter/material.dart';

import '../app.dart';
import '../data/game.dart';
import '../data/settings.dart';
import '../design/theme.dart';
import '../l10n/strings.dart';
import '../services/secure_screen.dart';
import '../widgets/buttons.dart';
import '../widgets/chips.dart';
import '../widgets/dialogs.dart';
import '../widgets/dossier_card.dart';
import '../widgets/scaffold.dart';
import 'packs.dart';
import 'setup.dart';
import 'timer.dart';

/// Deal -> handoff -> reveal -> handoff -> ... -> the clock.
///
/// Every step is a route replacement rather than an overlay, so the previous
/// screen is deactivated and any card state on it is disposed. An overlay
/// would leave a live dossier card sitting under an opaque black rectangle,
/// which is exactly the thing this flow exists to prevent.
abstract final class DealFlow {
  static Future<void> start(BuildContext context) async {
    final game = context.game;
    final store = context.settingsStore;
    final s = SpyStrings.of(context);
    final navigator = Navigator.of(context);

    final result = game.deal(
      settings: store.value,
      language: s.localeName,
      defaultName: s.playerDefault,
      library: context.library,
    );

    final failure = result.failure;
    if (failure != null) {
      if (!context.mounted) return;
      switch (failure) {
        case NoPacksEnabled():
          // Setup is where the reason and the fix both live.
          await navigator.push(
            MaterialPageRoute(builder: (_) => const SetupScreen()),
          );
        case NotEnoughWords(:final pack, :final used):
          await showSpySheet<void>(
            context,
            title: s.packsExhausted,
            builder: (sheetContext) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  s.packsExhaustedBody(pack.name, pack.size, used),
                  style: sheetContext.type.caption
                      .copyWith(color: sheetContext.spy.textMuted),
                ),
                const SizedBox(height: 18),
                SpyButton(
                  label: s.packsReshuffle(pack.name),
                  kind: SpyButtonKind.primary,
                  size: SpyButtonSize.large,
                  onPressed: () async {
                    await store.edit((old) {
                      final played = Map<String, Set<String>>.from(old.playedWords)
                        ..remove(pack.id);
                      return old.copyWith(playedWords: played);
                    });
                    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                  },
                ),
                const SizedBox(height: 9),
                SpyButton(
                  label: s.packsTitle,
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    navigator.push(
                      MaterialPageRoute(builder: (_) => const PacksScreen()),
                    );
                  },
                ),
              ],
            ),
          );
      }
      return;
    }

    final round = result.round!;
    await _recordDeal(store, round);
    if (!context.mounted) return;
    await navigator.push(handoffRoute(0));
  }

  /// Back into a round that is already running - from Home's banner.
  static void resume(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TimerScreen()),
    );
  }

  /// Bookkeeping the round itself should not carry: the word is spent, the
  /// evening has a case number, and Home now has something to repeat.
  static Future<void> _recordDeal(SettingsStore store, SpyRound round) {
    return store.edit((old) {
      final now = DateTime.now();
      final last = old.lastPlayedAt;
      final sameEvening = last != null &&
          now.difference(last) < const Duration(hours: 6);

      final played = {
        for (final entry in old.playedWords.entries)
          entry.key: Set<String>.from(entry.value),
      };
      played.putIfAbsent(round.pack.id, () => <String>{}).add(round.word);

      return old.copyWith(
        lastPlayedAt: now,
        playedWords: played,
        caseNumber: sameEvening ? old.caseNumber : old.caseNumber + 1,
        round: sameEvening ? old.round + 1 : 1,
        // Counted for life, not for the evening: the first advert and the
        // first mention of downloadable packs both wait on somebody having
        // actually played, and neither should reset because they slept.
        roundsPlayed: old.roundsPlayed + 1,
      );
    });
  }

  /// The *handoff* motion: an opaque black wipe travelling in the reading
  /// direction, 320 ms. Not a crossfade - a crossfade shows two cards at once.
  static Route<void> handoffRoute(int index) {
    return PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: SpyPrimitives.dSlow,
      reverseTransitionDuration: SpyPrimitives.dSlow,
      pageBuilder: (_, _, _) => HandoffScreen(index: index),
      transitionsBuilder: (context, animation, _, child) {
        if (context.reducedMotion) return child;
        final rtl = Directionality.of(context) == TextDirection.rtl;
        return SlideTransition(
          position: Tween<Offset>(
            begin: Offset(rtl ? 1 : -1, 0),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: animation, curve: SpyPrimitives.eStandard),
          ),
          child: child,
        );
      },
    );
  }

  static Route<void> revealRoute(int index) {
    return PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: SpyPrimitives.dFast,
      pageBuilder: (_, _, _) => RevealScreen(index: index),
      transitionsBuilder: (context, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    );
  }
}

/// The gate that makes the promise true.
///
/// Full-bleed `#05070A` in **both** themes - a bone-white handoff screen in a
/// dim room is a flashbulb in six faces. No card exists in the tree here at
/// all, so there is nothing to leak while the phone crosses the table.
class HandoffScreen extends StatefulWidget {
  const HandoffScreen({required this.index, super.key});

  final int index;

  @override
  State<HandoffScreen> createState() => _HandoffScreenState();
}

class _HandoffScreenState extends State<HandoffScreen> {
  bool _nameVisible = false;

  @override
  void initState() {
    super.initState();
    SecureScreen.acquire();
    // The name fades in *after* the wipe has landed, never during it.
    Future.delayed(SpyPrimitives.dSlow, () {
      if (mounted) setState(() => _nameVisible = true);
    });
  }

  @override
  void dispose() {
    SecureScreen.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = SpyStrings.of(context);
    final t = context.type;
    final round = context.game.round;
    if (round == null || widget.index >= round.players.length) {
      return const SizedBox.shrink();
    }
    final player = round.players[widget.index];
    final compact = context.density.isCompact;

    return PopScope(
      // Back is blocked during the deal. On Android the predictive-back
      // gesture surfaces the abandon dialog instead of dropping the round.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _confirmAbandon(context);
      },
      child: SpyScaffold(
        showAppBar: false,
        background: SpyPrimitives.ink,
        body: Center(
          child: Padding(
            padding: const EdgeInsetsDirectional.all(SpyPrimitives.s5),
            child: AnimatedOpacity(
              opacity: _nameVisible ? 1 : 0,
              duration: SpyPrimitives.dBase,
              curve: SpyPrimitives.eEnter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _caps(t, s.handoffCase(round.caseNumber, round.round)),
                    textAlign: TextAlign.center,
                    style: t.file.copyWith(
                      color: const Color(0xFF5A6270),
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: SpyPrimitives.s3),
                  Text(
                    _caps(t, s.handoffPassTo),
                    textAlign: TextAlign.center,
                    style: t.appBar.copyWith(
                      color: const Color(0xFF7B8592),
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: SpyPrimitives.s3),
                  Text(
                    // As typed. A name is not a screen title.
                    player.name,
                    textAlign: TextAlign.center,
                    style: t.title.copyWith(
                      color: SpyPrimitives.neutral1000,
                      fontSize: compact ? 38 : 46,
                      fontWeight: FontWeight.w700,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: SpyPrimitives.s3),
                  Text(
                    _caps(
                      t,
                      s.handoffPosition(widget.index + 1, round.players.length),
                    ),
                    textAlign: TextAlign.center,
                    style: t.file.copyWith(
                      color: const Color(0xFF5A6270),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        foot: SpyButton(
          label: s.handoffIAm(player.name),
          kind: SpyButtonKind.primary,
          size: SpyButtonSize.large,
          onPressed: () => Navigator.of(context)
              .pushReplacement(DealFlow.revealRoute(widget.index)),
        ),
      ),
    );
  }

  String _caps(SpyType t, String value) => t.uppercases ? value.toUpperCase() : value;
}

/// The screen that matters.
class RevealScreen extends StatefulWidget {
  const RevealScreen({required this.index, super.key});

  final int index;

  @override
  State<RevealScreen> createState() => _RevealScreenState();
}

class _RevealScreenState extends State<RevealScreen> {
  @override
  void initState() {
    super.initState();
    SecureScreen.acquire();
  }

  @override
  void dispose() {
    SecureScreen.release();
    super.dispose();
  }

  void _next() {
    final game = context.game;
    final round = game.round;
    if (round == null) return;
    game.confirmSeen();
    final navigator = Navigator.of(context);
    if (widget.index + 1 < round.players.length) {
      navigator.pushReplacement(DealFlow.handoffRoute(widget.index + 1));
    } else {
      game.startClock();
      navigator.pushReplacement(
        MaterialPageRoute(builder: (_) => const TimerScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spy;
    final t = context.type;
    final s = SpyStrings.of(context);
    final round = context.game.round;
    if (round == null || widget.index >= round.players.length) {
      return const SizedBox.shrink();
    }
    final player = round.players[widget.index];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _confirmAbandon(context);
      },
      child: SpyScaffold(
        title: s.cardTitle,
        trailing: Padding(
          padding: const EdgeInsetsDirectional.only(end: SpyPrimitives.s3),
          child: SpyChip(
            s.cardPosition(widget.index + 1, round.players.length),
            tone: SpyChipTone.quiet,
          ),
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            // The card owns this screen, so it takes the whole body rather
            // than wrapping its content and leaving a dead gap above the
            // button. Past about 130% text scale the fixed furniture - header,
            // name, slider, caption - fills the screen on its own; there is
            // nothing left to stretch into, so the page scrolls instead of
            // crushing the word bay.
            final fills = MediaQuery.textScalerOf(context).scale(14) <= 18.2 &&
                constraints.maxHeight >= 420;

            final card = DossierCard(
              // A fresh card per player: no state can survive the handoff.
              key: ValueKey(widget.index),
              playerName: player.name,
              word: player.isSpy ? null : round.word,
              packName: round.pack.name,
              isSpy: player.isSpy,
              spiesSeeCategory: round.spiesSeeCategory,
              caseNumber: round.caseNumber,
              round: round.round,
              position: widget.index + 1,
              total: round.players.length,
              fill: fills,
              onInterrupted: () {
                context.game.interrupt(player.name);
                if (!mounted) return;
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const InterruptedScreen()),
                );
              },
            );
            final note = Text(
              s.cardDontSayIt,
              textAlign: TextAlign.center,
              style: t.caption.copyWith(color: c.textMuted),
            );

            return SpyBody(
              scrollable: !fills,
              children: [
                if (fills) Expanded(child: card) else card,
                note,
              ],
            );
          },
        ),
        foot: SpyButton(
          label: s.cardGotIt,
          kind: SpyButtonKind.primary,
          size: SpyButtonSize.large,
          onPressed: _next,
        ),
      ),
    );
  }
}

/// A call landed while somebody was holding the phone.
///
/// An interrupted reveal is never resumed - the alternative is a phone showing
/// a secret word to whoever happens to be holding it when the call ends.
class InterruptedScreen extends StatelessWidget {
  const InterruptedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = SpyStrings.of(context);
    final holder = context.game.interruptedHolder ?? s.playerDefault(1);

    return SpyScaffold(
      title: s.interruptedTitle,
      body: SpyEmptyState(
        title: s.interruptedTitle,
        body: s.interruptedBody(holder),
      ),
      foot: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SpyButton(
            label: s.interruptedDealAgain,
            kind: SpyButtonKind.primary,
            size: SpyButtonSize.large,
            onPressed: () async {
              context.game.abandon();
              final navigator = Navigator.of(context);
              navigator.popUntil((route) => route.isFirst);
              if (context.mounted) await DealFlow.start(context);
            },
          ),
          const SizedBox(height: 9),
          SpyButton(
            label: s.verdictBackToStart,
            kind: SpyButtonKind.ghost,
            onPressed: () {
              context.game.abandon();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
    );
  }
}

Future<void> _confirmAbandon(BuildContext context) async {
  final s = SpyStrings.of(context);
  final game = context.game;
  final seen = game.round?.dealtCount ?? 0;
  final confirmed = await showSpyConfirm(
    context,
    title: s.abandonTitle,
    body: s.abandonBody(seen),
    confirmLabel: s.abandonConfirm,
    keepLabel: s.abandonKeep,
  );
  if (!confirmed || !context.mounted) return;
  game.abandon();
  Navigator.of(context).popUntil((route) => route.isFirst);
}
