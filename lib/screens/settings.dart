import 'package:flutter/material.dart';

import '../app.dart';
import '../data/settings.dart';
import '../data/word_packs.dart';
import '../design/theme.dart';
import '../l10n/strings.dart';
import '../widgets/buttons.dart';
import '../widgets/chips.dart';
import '../widgets/controls.dart';
import '../widgets/dialogs.dart';
import '../widgets/rows.dart';
import '../widgets/scaffold.dart';
import 'pack_downloads.dart';
import 'packs.dart';

/// Eleven rows, three groups, every one with a plain-language second line.
///
/// Reachable mid-evening and it never leaves the game state: three taps in,
/// three taps out, and the clock keeps running the whole time.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = SpyStrings.of(context);
    final store = context.settingsStore;
    final settings = context.settings;

    /// A failed write reverts the row and says so. Never a silent failure.
    Future<void> write(SpySettings next) async {
      final ok = await store.update(next);
      if (!ok && context.mounted) showSpyToast(context, s.storageTitle);
    }

    final onPacks = context.library.forLanguage(s.localeName)
        .where((p) => settings.enabledPacks.contains(p.id))
        .map((p) => p.name)
        .toList();

    return SpyScaffold(
      title: s.settingsTitle,
      onBack: () => Navigator.of(context).pop(),
      body: SpyBody(
        scrollable: true,
        gap: 0,
        children: [
          SpyGroupHeading(s.settingsGroupSound, topGap: SpyPrimitives.s2),
          SpySettingRow(
            label: s.settingsClockSound,
            help: s.settingsClockSoundHelp,
            trailing: SpySwitch(
              value: settings.clockSound,
              semanticLabel: s.settingsClockSound,
              onChanged: (v) => write(settings.copyWith(clockSound: v)),
            ),
          ),
          SpySettingRow(
            label: s.settingsBell,
            help: s.settingsBellHelp,
            trailing: SpySwitch(
              value: settings.bellAtZero,
              semanticLabel: s.settingsBell,
              onChanged: (v) => write(settings.copyWith(bellAtZero: v)),
            ),
          ),
          SpySettingRow(
            label: s.settingsHaptics,
            help: s.settingsHapticsHelp,
            isLast: true,
            trailing: SpySwitch(
              value: settings.haptics,
              semanticLabel: s.settingsHaptics,
              onChanged: (v) => write(settings.copyWith(haptics: v)),
            ),
          ),
          SpyGroupHeading(s.settingsGroupGame),
          SpySettingRow(
            label: s.settingsSpyCategory,
            help: s.settingsSpyCategoryHelp,
            trailing: SpySwitch(
              value: settings.spiesSeeCategory,
              semanticLabel: s.settingsSpyCategory,
              onChanged: (v) => write(settings.copyWith(spiesSeeCategory: v)),
            ),
          ),
          SpySettingRow(
            label: s.packsTitle,
            help: onPacks.isEmpty ? s.setupNoPacks : onPacks.join(', '),
            trailing: SpyRowValue(s.number(onPacks.length)),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PacksScreen()),
            ),
          ),
          SpySettingRow(
            label: s.downloadsTitle,
            help: s.downloadsConnect,
            trailing: const SpyRowValue(''),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PackDownloadsScreen()),
            ),
          ),
          SpySettingRow(
            label: s.settingsNoRepeat,
            help: s.settingsNoRepeatHelp,
            isLast: true,
            trailing: SpySwitch(
              value: settings.noRepeatWords,
              semanticLabel: s.settingsNoRepeat,
              onChanged: (v) => write(settings.copyWith(noRepeatWords: v)),
            ),
          ),
          SpyGroupHeading(s.settingsGroupLook),
          SpySettingRow(
            label: s.settingsTheme,
            help: switch (settings.theme) {
              SpyThemeChoice.system => s.settingsThemeSystem,
              SpyThemeChoice.noir => s.settingsThemeNoir,
              SpyThemeChoice.daylight => s.settingsThemeDaylight,
            },
            trailing: const SpyRowValue(''),
            onTap: () => _pickTheme(context, write),
          ),
          SpySettingRow(
            label: s.settingsLanguage,
            help: switch (settings.language) {
              SpyLanguage.system => s.settingsThemeSystem,
              SpyLanguage.en => 'English',
              SpyLanguage.fa => 'فارسی',
            },
            trailing: const SpyRowValue(''),
            onTap: () => _pickLanguage(context, write),
          ),
          SpySettingRow(
            label: s.settingsAwake,
            help: s.settingsAwakeHelp,
            isLast: true,
            trailing: SpySwitch(
              value: settings.keepAwake,
              semanticLabel: s.settingsAwake,
              onChanged: (v) => write(settings.copyWith(keepAwake: v)),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(
              top: 18,
              bottom: SpyPrimitives.s3,
            ),
            child: SpyButton(
              label: s.settingsReset,
              kind: SpyButtonKind.danger,
              onPressed: () async {
                final confirmed = await showSpyConfirm(
                  context,
                  title: s.settingsResetConfirmTitle,
                  body: s.settingsResetConfirmBody,
                  confirmLabel: s.settingsReset,
                  keepLabel: s.commonCancel,
                );
                if (!confirmed || !context.mounted) return;
                final ok = await store.reset();
                if (!context.mounted) return;
                showSpyToast(
                  context,
                  ok ? s.settingsResetDone : s.storageTitle,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickTheme(
    BuildContext context,
    Future<void> Function(SpySettings) write,
  ) async {
    final s = SpyStrings.of(context);
    final settings = context.settings;
    await showSpySheet<void>(
      context,
      title: s.settingsTheme,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final choice in SpyThemeChoice.values)
            SpyItemRow(
              title: switch (choice) {
                SpyThemeChoice.system => s.settingsThemeSystem,
                SpyThemeChoice.noir => s.settingsThemeNoir,
                SpyThemeChoice.daylight => s.settingsThemeDaylight,
              },
              state: choice == settings.theme
                  ? ItemRowState.now
                  : ItemRowState.waiting,
              trailing: choice == settings.theme
                  ? SpyChip(s.packsOn)
                  : null,
              onTap: () {
                write(settings.copyWith(theme: choice));
                Navigator.of(sheetContext).pop();
              },
            ),
        ],
      ),
    );
  }

  Future<void> _pickLanguage(
    BuildContext context,
    Future<void> Function(SpySettings) write,
  ) async {
    final s = SpyStrings.of(context);
    final settings = context.settings;
    await showSpySheet<void>(
      context,
      title: s.settingsLanguage,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final choice in SpyLanguage.values)
            SpyItemRow(
              // Persian is فارسی, not a flag.
              title: switch (choice) {
                SpyLanguage.system => s.settingsThemeSystem,
                SpyLanguage.en => 'English',
                SpyLanguage.fa => 'فارسی',
              },
              state: choice == settings.language
                  ? ItemRowState.now
                  : ItemRowState.waiting,
              trailing: choice == settings.language ? SpyChip(s.packsOn) : null,
              onTap: () {
                // Packs are per-language, so switching language switches which
                // packs are even on offer. Existing choices are kept - a trip
                // back to English finds the same packs still on - but a
                // language with nothing enabled would land on "every pack is
                // switched off" through no fault of the player, so it gets its
                // packs turned on.
                final code = choice.code ??
                    WidgetsBinding.instance.platformDispatcher.locale.languageCode;
                final available = WordPacks.forLanguage(code == 'fa' ? 'fa' : 'en');
                final anyOn =
                    available.any((p) => settings.enabledPacks.contains(p.id));
                write(settings.copyWith(
                  language: choice,
                  enabledPacks: anyOn
                      ? settings.enabledPacks
                      : {...settings.enabledPacks, ...available.map((p) => p.id)},
                ));
                Navigator.of(sheetContext).pop();
              },
            ),
        ],
      ),
    );
  }
}
