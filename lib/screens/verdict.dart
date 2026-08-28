import 'package:flutter/material.dart';

import '../app.dart';
import '../design/theme.dart';
import '../l10n/strings.dart';
import '../widgets/buttons.dart';
import '../widgets/scaffold.dart';
import '../widgets/verdict_stamp.dart';
import 'deal_flow.dart';

/// The punchline. Nothing left to protect, so this screen survives
/// backgrounding and is the one people screenshot.
class VerdictScreen extends StatefulWidget {
  const VerdictScreen({super.key});

  @override
  State<VerdictScreen> createState() => _VerdictScreenState();
}

class _VerdictScreenState extends State<VerdictScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: SpyPrimitives.dVerdict,
  )..forward();

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spy;
    final t = context.type;
    final s = SpyStrings.of(context);
    final round = context.game.round;
    if (round == null) return const SizedBox.shrink();

    final spies = round.spies;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _backToStart(context);
      },
      child: SpyScaffold(
        title: s.verdictTitle,
        body: SpyBody(
          scrollable: true,
          gap: 18,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: SpyPrimitives.s8),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _caps(t, s.verdictTheWordWas),
                  textAlign: TextAlign.center,
                  style: t.file.copyWith(color: c.textFaint, fontSize: 10),
                ),
                const SizedBox(height: SpyPrimitives.s2),
                // The word rises 12px and fades in over 520 ms - the slowest
                // thing in the app. It should land late.
                AnimatedBuilder(
                  animation: _reveal,
                  builder: (context, child) {
                    final v = SpyPrimitives.eEnter.transform(_reveal.value);
                    return Opacity(
                      opacity: v,
                      child: Transform.translate(
                        offset: Offset(0, context.reducedMotion ? 0 : 12 * (1 - v)),
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    t.uppercases ? round.word.toUpperCase() : round.word,
                    textAlign: TextAlign.center,
                    style: t.display.copyWith(color: c.accent),
                  ),
                ),
                const SizedBox(height: SpyPrimitives.s2),
                Text(
                  _caps(t, round.pack.name),
                  textAlign: TextAlign.center,
                  style: t.file.copyWith(color: c.accentText, fontSize: 11),
                ),
              ],
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _caps(t, s.verdictTheSpiesWere(spies.length)),
                  textAlign: TextAlign.center,
                  style: t.file.copyWith(color: c.textFaint, fontSize: 10),
                ),
                const SizedBox(height: SpyPrimitives.s4),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    for (var i = 0; i < spies.length; i++)
                      VerdictStamp(name: spies[i].name, index: i),
                  ],
                ),
              ],
            ),
            const SizedBox(height: SpyPrimitives.s8),
          ],
        ),
        foot: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Second round, same group: one tap.
            SpyButton(
              label: s.homeSameAgain,
              kind: SpyButtonKind.primary,
              size: SpyButtonSize.large,
              onPressed: () async {
                final navigator = Navigator.of(context);
                context.game.abandon();
                navigator.popUntil((route) => route.isFirst);
                if (context.mounted) await DealFlow.start(context);
              },
            ),
            const SizedBox(height: 9),
            SpyButton(
              label: s.verdictBackToStart,
              kind: SpyButtonKind.ghost,
              onPressed: () => _backToStart(context),
            ),
          ],
        ),
      ),
    );
  }

  void _backToStart(BuildContext context) {
    context.game.abandon();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  String _caps(SpyType t, String value) => t.uppercases ? value.toUpperCase() : value;
}
