import 'package:flutter/material.dart';

import '../app.dart';
import '../data/pack_store.dart';
import '../data/remote.dart';
import '../design/icons.dart';
import '../design/textures.dart';
import '../design/theme.dart';
import '../l10n/strings.dart';
import '../services/platform.dart';
import '../widgets/buttons.dart';
import '../widgets/chips.dart';
import '../widgets/rows.dart';
import '../widgets/scaffold.dart';
import 'about.dart';
import 'deal_flow.dart';
import 'how_to_play.dart';
import 'pack_downloads.dart';
import 'settings.dart';
import 'setup.dart';

/// Leads with the last setup, not with setup.
///
/// The 45-second test lives or dies here: five people who have never opened
/// Spy are asking the first question within 45 seconds, without reading
/// anything. That is why *Same again* is the primary action and setup is the
/// quiet one underneath it.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _toldAboutStorage = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Storage unreadable: defaults plus a toast, never a silent shrug.
    if (!_toldAboutStorage && context.settingsStore.loadFailed) {
      _toldAboutStorage = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showSpyToast(context, SpyStrings.of(context).storageTitle);
      });
    }
  }

  /// Home's primary action, and the only place in the app an advert can
  /// appear.
  ///
  /// The order matters and is not negotiable: the advert happens *here*,
  /// before a round exists. A full-screen advert launches its own activity,
  /// which pauses Flutter, which is exactly what `DossierCard` treats as
  /// somebody walking off with the phone - it seals the card and voids the
  /// deal. Shown from Home there is nothing to void; shown a screen later
  /// there would be.
  Future<void> _sameAgain() async {
    final game = context.game;
    await context.ads.maybeShow(gameIdle: !game.isLive);
    if (!mounted) return;
    context.telemetry.record('game_started');
    DealFlow.start(context);
  }

  String _relativeWhen(SpyStrings s, DateTime when) {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    if (when.isAfter(midnight)) return s.homeWhenTonight;
    if (when.isAfter(midnight.subtract(const Duration(days: 1)))) {
      return s.homeWhenYesterday;
    }
    return s.homeWhenAWhileAgo;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spy;
    final s = SpyStrings.of(context);
    final settings = context.settings;
    final game = context.game;
    final hasPlayed = settings.lastPlayedAt != null;

    final packNames = context.library.forLanguage(s.localeName)
        .where((p) => settings.enabledPacks.contains(p.id))
        .map((p) => p.name)
        .join(', ');

    return SpyScaffold(
      title: s.appName,
      trailing: SpyIconButton(
        icon: const SpyIcon(SpyIconData.settings),
        semanticLabel: s.a11ySettings,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        ),
      ),
      body: SpyBody(
        children: [
          Expanded(child: _Hero()),
          // Never above the fold and never in the way: a group standing round
          // a table is not going to stop and update, and the round they are
          // about to deal works exactly as well either way.
          if (!game.isLive && context.updates.updateAvailable) const _UpdateBanner(),
          if (!game.isLive && !context.updates.updateAvailable) const _PacksNudge(),
          if (game.isLive)
            SpyBanner(
              tone: SpyBannerTone.accent,
              title: s.homeRoundInProgress,
              body: s.homeRoundInProgressBody(s.clockTime(game.remaining.value)),
              action: SpyButton(
                label: s.clockTitle(game.round?.round ?? 1),
                size: SpyButtonSize.small,
                onPressed: () => DealFlow.resume(context),
              ),
            )
          else if (hasPlayed)
            SpyItemRow(
              leading: const _AgainGlyph(),
              title: s.homeLastSetup(
                settings.players,
                settings.effectiveSpies,
                s.roundLength(settings.roundLength),
              ),
              subtitle: [
                if (packNames.isNotEmpty) packNames,
                s.homeLastPlayed(_relativeWhen(s, settings.lastPlayedAt!)),
              ].join(' · '),
            ),
        ],
      ),
      foot: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // First launch has nothing to repeat, so the primary becomes setup.
          SpyButton(
            label: hasPlayed ? s.homeSameAgain : s.homeSetUpGame,
            kind: SpyButtonKind.primary,
            size: SpyButtonSize.large,
            // First run has nothing to repeat and has earned no advert:
            // somebody who has not played yet meets the game, not a network.
            onPressed: () => hasPlayed
                ? _sameAgain()
                : Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SetupScreen()),
                  ),
          ),
          if (hasPlayed) ...[
            const SizedBox(height: 9),
            SpyButton(
              label: s.homeChangeSetup,
              size: SpyButtonSize.large,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SetupScreen()),
              ),
            ),
          ],
          const SizedBox(height: 9),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SpyButton(
                label: s.homeHowToPlay,
                kind: SpyButtonKind.ghost,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HowToPlayScreen()),
                ),
              ),
              Text('·', style: TextStyle(color: c.textFaint)),
              SpyButton(
                label: s.homeAbout,
                kind: SpyButtonKind.ghost,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AboutScreen()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A quiet word that there are more packs than the ones in this build.
///
/// Held back until somebody has actually played - asking a stranger to go
/// online before they have finished a game is a way to lose them - and put
/// away for days once dismissed. It never appears above the fold and never
/// while a round is live.
class _PacksNudge extends StatelessWidget {
  const _PacksNudge();

  @override
  Widget build(BuildContext context) {
    final s = SpyStrings.of(context);
    final settings = context.settings;
    final nudge = context.updates.config?.nudge ?? PacksNudge.standard;
    final store = context.packStore;

    if (!nudge.enabled) return const SizedBox.shrink();
    if (settings.roundsPlayed < nudge.afterRounds) return const SizedBox.shrink();

    final dismissed = settings.packsNudgedAt;
    if (dismissed != null) {
      // Zero means never come back.
      if (nudge.repeatAfter == Duration.zero) return const SizedBox.shrink();
      if (DateTime.now().difference(dismissed) < nudge.repeatAfter) {
        return const SizedBox.shrink();
      }
    }

    // If the catalogue has already been fetched and holds nothing new, there
    // is nothing to encourage anybody towards.
    if (store.state == CatalogueState.ready &&
        store.updatesIn(s.localeName).isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: SpyPrimitives.s3),
      child: SpyBanner(
        tone: SpyBannerTone.accent,
        title: s.nudgeTitle,
        body: s.nudgeBody,
        action: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SpyButton(
              label: s.downloadsTitle,
              kind: SpyButtonKind.primary,
              size: SpyButtonSize.small,
              onPressed: () {
                context.telemetry.record('packs_opened', detail: 'nudge');
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PackDownloadsScreen()),
                );
              },
            ),
            const SizedBox(width: SpyPrimitives.s2),
            SpyButton(
              label: s.nudgeNotNow,
              kind: SpyButtonKind.ghost,
              size: SpyButtonSize.small,
              onPressed: () => context.settingsStore.edit(
                (old) => old.copyWith(packsNudgedAt: DateTime.now()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// There is something newer on the store.
///
/// A link, never an install. Bazaar forbids an app updating itself, and the
/// permission that would make it possible is one this app has no business
/// holding. If nothing on the phone can open the link, the banner says nothing
/// happened rather than pretending it did.
class _UpdateBanner extends StatelessWidget {
  const _UpdateBanner();

  @override
  Widget build(BuildContext context) {
    final s = SpyStrings.of(context);
    final config = context.updates.config;
    if (config == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: SpyPrimitives.s3),
      child: SpyBanner(
        tone: SpyBannerTone.notice,
        title: s.updateTitle,
        body: context.updates.updateUrgent
            ? s.updateUrgentBody(config.latestVersion)
            : s.updateBody(config.latestVersion),
        action: config.updateUrl.isEmpty
            ? null
            : SpyButton(
                label: s.updateAction,
                size: SpyButtonSize.small,
                onPressed: () async {
                  final opened = await SpyPlatform.openUrl(config.updateUrl);
                  if (opened || !context.mounted) return;
                  showSpyToast(context, s.netOfflineBody);
                },
              ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.spy;
    final t = context.type;
    final s = SpyStrings.of(context);
    final compact = context.density.isCompact;

    return Grain(
      borderRadius: BorderRadius.circular(SpyPrimitives.rLg),
      child: Blind(
        color: c.text,
        child: Container(
          width: double.infinity,
          alignment: Alignment.center,
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 14,
            vertical: 22,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SpyPrimitives.rLg),
          ),
          // The hero is the first thing to give way. Everything else on
          // this screen - a live round, an update, the offer of more packs -
          // is something to act on; the wordmark is decoration, so it shrinks
          // to fit rather than pushing anything off the bottom.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t.uppercases ? s.appName.toUpperCase() : s.appName,
                  textAlign: TextAlign.center,
                  style: t.wordmark.copyWith(
                    color: c.text,
                    fontSize: compact ? 34 : null,
                    letterSpacing: compact && t.uppercases ? 34 * 0.12 : null,
                  ),
                ),
                const SizedBox(height: SpyPrimitives.s4),
                Text(
                  t.uppercases ? s.appTagline.toUpperCase() : s.appTagline,
                  textAlign: TextAlign.center,
                  style: t.file.copyWith(color: c.textFaint, fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AgainGlyph extends StatelessWidget {
  const _AgainGlyph();

  @override
  Widget build(BuildContext context) {
    final c = context.spy;
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.accentQuiet,
        borderRadius: BorderRadius.circular(SpyPrimitives.rSm),
      ),
      child: SpyIcon(SpyIconData.again, size: 18, color: c.accentText),
    );
  }
}
