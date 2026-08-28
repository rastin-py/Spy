import 'package:flutter/material.dart';

import '../app.dart';
import '../data/word_packs.dart';
import '../design/theme.dart';
import '../l10n/strings.dart';
import '../widgets/buttons.dart';
import '../widgets/chips.dart';
import '../widgets/rows.dart';
import '../widgets/scaffold.dart';
import 'pack_downloads.dart';

/// Packs mix. With two on, every round draws from both.
class PacksScreen extends StatelessWidget {
  const PacksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = SpyStrings.of(context);
    final store = context.settingsStore;
    final settings = context.settings;

    // Only this language's packs. A Persian UI never offers an English pack,
    // because the word is the thing being guessed and a language switch is a
    // tell.
    // The library, so a downloaded pack sits in this list exactly like a
    // built-in one. Only the download screen ever distinguishes the two.
    final packs = context.library.forLanguage(s.localeName);
    final anyOn = packs.any((p) => settings.enabledPacks.contains(p.id));

    return SpyScaffold(
      title: s.packsTitle,
      onBack: () => Navigator.of(context).pop(),
      body: SpyBody(
        scrollable: true,
        gap: 7,
        children: [
          if (!anyOn)
            SpyBanner(
              tone: SpyBannerTone.danger,
              title: s.setupNoPacks,
              body: s.setupNoPacksBody,
              action: packs.isEmpty
                  ? null
                  : SpyButton(
                      label: s.packsTurnOn(packs.first.name),
                      size: SpyButtonSize.small,
                      onPressed: () => store.edit(
                        (old) => old.copyWith(
                          enabledPacks: {...old.enabledPacks, packs.first.id},
                        ),
                      ),
                    ),
            ),
          for (final pack in packs)
            _PackRow(pack: pack, on: settings.enabledPacks.contains(pack.id)),
          Padding(
            padding: const EdgeInsetsDirectional.only(top: SpyPrimitives.s3),
            child: SpyBanner(
              tone: SpyBannerTone.accent,
              title: s.downloadsConnect,
              body: s.downloadsConnectBody(
                WordPacks.forLanguage(s.localeName).length,
              ),
              action: SpyButton(
                label: s.downloadsTitle,
                size: SpyButtonSize.small,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PackDownloadsScreen()),
                ),
              ),
            ),
          ),
          SpyBanner(title: s.packsMixNote),
        ],
      ),
    );
  }
}

class _PackRow extends StatelessWidget {
  const _PackRow({required this.pack, required this.on});

  final WordPack pack;
  final bool on;

  @override
  Widget build(BuildContext context) {
    final c = context.spy;
    final t = context.type;
    final s = SpyStrings.of(context);
    final store = context.settingsStore;
    final settings = context.settings;
    final played = settings.playedWords[pack.id]?.length ?? 0;

    return SpyItemRow(
      leading: SpyMonogram(pack.monogram),
      title: pack.name,
      subtitle: [
        s.packsCount(pack.size),
        if (played > 0) s.packsPlayedTonight(played),
      ].join(' · '),
      state: on ? ItemRowState.now : ItemRowState.waiting,
      // The literal words ON / OFF, because a brass stripe alone is colour
      // doing the work by itself.
      trailing: Text(
        on ? s.packsOn : s.packsOff,
        style: t.file.copyWith(
          color: on ? c.accentText : c.textFaint,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
      semanticLabel: '${pack.name}, ${on ? s.packsOn : s.packsOff}. '
          '${s.packsCount(pack.size)}',
      onTap: () => store.edit((old) {
        final next = Set<String>.from(old.enabledPacks);
        on ? next.remove(pack.id) : next.add(pack.id);
        return old.copyWith(enabledPacks: next);
      }),
    );
  }
}
