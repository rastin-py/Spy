import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../app.dart';
import '../data/game.dart';
import '../l10n/strings.dart';
import '../services/audio.dart';
import '../services/platform.dart';
import '../widgets/buttons.dart';
import '../widgets/chips.dart';
import '../widgets/clock_face.dart';
import '../widgets/dialogs.dart';
import '../widgets/scaffold.dart';
import 'verdict.dart';

/// Readable at a metre. Lies flat on the table for eight minutes.
class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker = createTicker((_) => _onFrame());
  bool _bellStruck = false;

  /// Null until the platform answers, and null forever on iOS.
  bool? _muted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker.start();
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyRunningState());
    _checkMuted();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    // Released on pause, verdict, background and dispose alike - a wakelock
    // that outlives its screen is how a phone ends the evening flat.
    _setWakelock(false);
    SpyAudio.instance.stopTicking();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Resumes from the wall clock; if it expired while away, the sync below
      // walks straight to the verdict.
      context.game.syncClock();
      _applyRunningState();
      // The ringer may well have been flipped while we were away.
      _checkMuted();
    } else {
      _setWakelock(false);
      SpyAudio.instance.stopTicking();
    }
  }

  /// A phone that will not hold its wakelock is a dimmer screen, not a broken
  /// round - so this never propagates.
  Future<void> _setWakelock(bool on) async {
    try {
      await SpyPlatform.setKeepAwake(on);
    } catch (_) {}
  }

  Future<void> _checkMuted() async {
    final muted = await SpyPlatform.isMuted();
    if (mounted && muted != _muted) setState(() => _muted = muted);
  }

  void _onFrame() {
    final game = context.game;
    if (game.phase != RoundPhase.running) return;
    final before = game.remaining.value;
    game.syncClock();
    if (before > Duration.zero && game.remaining.value <= Duration.zero) {
      _onExpired();
    }
  }

  void _onExpired() {
    if (_bellStruck) return;
    _bellStruck = true;
    if (context.settings.bellAtZero) SpyAudio.instance.strikeBell();
    SpyAudio.instance.stopTicking();
    _setWakelock(false);
    _toVerdict();
  }

  void _applyRunningState() {
    if (!mounted) return;
    final game = context.game;
    final settings = context.settings;
    final running = game.phase == RoundPhase.running;

    // Wakelock only while the clock runs *and* the setting is on.
    _setWakelock(running && settings.keepAwake);
    if (running && settings.clockSound) {
      SpyAudio.instance.startTicking();
    } else {
      SpyAudio.instance.stopTicking();
    }
  }

  void _toVerdict() {
    final game = context.game;
    game.callIt();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const VerdictScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = SpyStrings.of(context);
    final game = context.game;
    final settings = context.settings;
    final round = game.round;
    if (round == null) return const SizedBox.shrink();

    final paused = game.phase == RoundPhase.paused;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _confirmAbandon(context);
      },
      child: SpyScaffold(
        title: s.clockTitle(round.round),
        trailing: SpyButton(
          label: s.abandonAction,
          kind: SpyButtonKind.ghost,
          size: SpyButtonSize.small,
          onPressed: () => _confirmAbandon(context),
        ),
        body: SpyBody(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClockFace(
              remaining: game.remaining,
              total: round.length,
              paused: paused,
              hapticsInLastTen: settings.haptics,
              label: s.clockMeta(
                round.players.length,
                round.spies.length,
                round.pack.name,
              ),
            ),
            // Sound is never the only signal, and a tick nobody can hear is
            // worth saying out loud rather than playing into the void.
            if (settings.clockSound && _muted == true)
              SpyBanner(
                title: s.clockSilent,
                body: s.clockSilentBody,
              ),
          ],
        ),
        foot: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SpyButton(
              label: paused ? s.clockResume : s.clockPause,
              size: SpyButtonSize.large,
              onPressed: () {
                paused ? game.resume() : game.pause();
                _applyRunningState();
              },
            ),
            const SizedBox(height: 9),
            // One tap, no confirm: calling it is the normal ending, not
            // destruction.
            SpyButton(
              label: s.clockCallIt,
              kind: SpyButtonKind.primary,
              size: SpyButtonSize.large,
              onPressed: _toVerdict,
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _confirmAbandon(BuildContext context) async {
  final s = SpyStrings.of(context);
  final game = context.game;
  final confirmed = await showSpyConfirm(
    context,
    title: s.abandonTitle,
    body: s.abandonBody(game.round?.players.length ?? 0),
    confirmLabel: s.abandonConfirm,
    keepLabel: s.abandonKeep,
  );
  if (!confirmed || !context.mounted) return;
  game.abandon();
  Navigator.of(context).popUntil((route) => route.isFirst);
}
