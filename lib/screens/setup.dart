import 'package:flutter/material.dart';

import '../app.dart';
import '../data/settings.dart';
import '../design/theme.dart';
import '../l10n/strings.dart';
import '../widgets/buttons.dart';
import '../widgets/chips.dart';
import '../widgets/controls.dart';
import '../widgets/rows.dart';
import '../widgets/scaffold.dart';
import 'deal_flow.dart';
import 'packs.dart';
import 'player_names.dart';

/// Three numbers and a pack. No text input and no scrolling on a standard
/// phone - anything that makes this screen longer costs seconds off the
/// 45-second test.
class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = SpyStrings.of(context);
    final store = context.settingsStore;
    final settings = context.settings;

    final packs = context.library.forLanguage(s.localeName);
    final onPacks = packs.where((p) => settings.enabledPacks.contains(p.id)).toList();
    final offCount = packs.length - onPacks.length;
    final ceiling = SpySettings.spyCeiling(settings.players);
    final spies = settings.effectiveSpies;
    final canDeal = onPacks.isNotEmpty;
    final named = settings.playerNames
        .take(settings.players)
        .where((n) => n.trim().isNotEmpty)
        .toList();

    return SpyScaffold(
      title: s.setupTitle,
      onBack: () => Navigator.of(context).pop(),
      body: SpyBody(
        scrollable: true,
        gap: SpyPrimitives.s6,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              SpyLabel(s.setupPlayers),
              CountStepper(
                value: settings.players,
                min: SpySettings.minPlayers,
                max: SpySettings.maxPlayers,
                semanticLabel: s.setupPlayers,
                format: s.number,
                onChanged: (v) => store.edit(
                  (old) => old.copyWith(
                    players: v,
                    // Keep the spy count legal as the table grows or shrinks,
                    // rather than silently dealing an impossible round.
                    spies: old.spies.clamp(1, SpySettings.spyCeiling(v)),
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              SpyLabel(s.setupSpies),
              CountStepper(
                value: spies,
                min: 1,
                max: ceiling,
                semanticLabel: s.setupSpies,
                format: s.number,
                onChanged: (v) => store.edit((old) => old.copyWith(spies: v)),
              ),
              // The ceiling always states its reason. A greyed-out plus with
              // no explanation reads as a bug.
              SpyHelp(s.setupSpyCeiling(settings.players, ceiling)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              SpyLabel(s.setupLength),
              SpySegmented<Duration>(
                options: SpySettings.lengthOptions,
                selected: settings.roundLength,
                labelOf: s.roundLength,
                onChanged: (v) => store.edit((old) => old.copyWith(roundLength: v)),
              ),
              if (settings.roundLength !=
                  SpySettings.suggestedLength(settings.players))
                SpyHelp(
                  s.setupSuggested(
                    settings.players,
                    s.roundLength(SpySettings.suggestedLength(settings.players)),
                  ),
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              SpyLabel(s.setupPacks),
              InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PacksScreen()),
                ),
                borderRadius: BorderRadius.circular(SpyPrimitives.rMd),
                child: Container(
                  constraints:
                      const BoxConstraints(minHeight: SpyPrimitives.tapMin),
                  alignment: AlignmentDirectional.centerStart,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final pack in onPacks) SpyChip(pack.name),
                      if (offCount > 0)
                        SpyChip(s.setupPacksOff(offCount), tone: SpyChipTone.quiet),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              SpyLabel(s.setupPlayerNames),
              SpySettingRow(
                label: named.isEmpty
                    ? s.setupPlayerNamesHelp
                    : named.join(', '),
                isLast: true,
                trailing: SpyRowValue(
                  s.cardPosition(named.length, settings.players),
                ),
                onTap: () => showPlayerNamesSheet(context),
              ),
            ],
          ),
          if (!canDeal)
            SpyBanner(
              tone: SpyBannerTone.danger,
              title: s.setupNoPacks,
              body: s.setupNoPacksBody,
              action: SpyButton(
                label: s.setupPacks,
                size: SpyButtonSize.small,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PacksScreen()),
                ),
              ),
            ),
        ],
      ),
      foot: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SpyButton(
            label: s.setupDeal,
            kind: SpyButtonKind.primary,
            size: SpyButtonSize.large,
            disabledReason: canDeal ? null : s.setupNoPacksBody,
            onPressed: canDeal ? () => DealFlow.start(context) : null,
          ),
          // The reason is on screen, not only in the semantics tree.
          if (!canDeal)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: SpyPrimitives.s3),
              child: Text(
                s.setupNoPacksBody,
                textAlign: TextAlign.center,
                style: context.type.caption.copyWith(color: context.spy.danger),
              ),
            ),
        ],
      ),
    );
  }
}
