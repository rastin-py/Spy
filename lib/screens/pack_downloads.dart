import 'package:flutter/material.dart';

import '../app.dart';
import '../data/pack_store.dart';
import '../data/remote.dart';
import '../data/word_packs.dart';
import '../design/icons.dart';
import '../design/theme.dart';
import '../l10n/strings.dart';
import '../services/api.dart';
import '../widgets/buttons.dart';
import '../widgets/chips.dart';
import '../widgets/dialogs.dart';
import '../widgets/rows.dart';
import '../widgets/scaffold.dart';

/// One plain sentence and one cause per way the network can let you down.
///
/// Lives here rather than in the API, because a failure is a thing to say to
/// somebody, not a thing to log. Every caller shows the pair together.
(String, String) networkMessage(SpyStrings s, ApiFailure failure) =>
    switch (failure) {
      ApiFailure.offline => (s.netOffline, s.netOfflineBody),
      ApiFailure.timeout => (s.netTimeout, s.netTimeoutBody),
      ApiFailure.malformed || ApiFailure.server => (s.netServer, s.netServerBody),
      ApiFailure.corrupt => (s.netCorrupt, s.netCorruptBody),
    };

/// More packs, from the server.
///
/// The whole screen is optional. Spy ships with enough packs to play forever,
/// and every state here - no network, a slow server, nothing new - leaves the
/// game exactly as playable as it was before anybody opened it.
class PackDownloadsScreen extends StatefulWidget {
  const PackDownloadsScreen({super.key});

  @override
  State<PackDownloadsScreen> createState() => _PackDownloadsScreenState();
}

class _PackDownloadsScreenState extends State<PackDownloadsScreen> {
  bool _asked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Opening the screen is the request. Asked once per visit, and only here -
    // nothing else in the app fetches a catalogue nobody has asked to see.
    if (_asked) return;
    _asked = true;
    final store = context.packStore;
    final language = SpyStrings.of(context).localeName;
    if (store.state == CatalogueState.idle ||
        store.state == CatalogueState.failed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) store.refresh(language: language);
      });
    }
  }

  Future<void> _install(RemotePack pack) async {
    final s = SpyStrings.of(context);
    final store = context.packStore;
    final failure = await store.install(pack);
    if (!mounted) return;
    if (failure == null) {
      showSpyToast(context, s.downloadsReady(pack.name));
    } else {
      showSpyToast(context, networkMessage(s, failure).$1);
    }
  }

  Future<void> _remove(WordPack pack) async {
    final s = SpyStrings.of(context);
    final store = context.packStore;
    final confirmed = await showSpyConfirm(
      context,
      title: s.downloadsRemoveConfirm(pack.name),
      body: s.downloadsRemoveConfirmBody,
      confirmLabel: s.downloadsRemove,
      keepLabel: s.commonCancel,
    );
    if (!confirmed || !mounted) return;
    final ok = await store.remove(pack.id);
    if (!mounted || ok) return;
    showSpyToast(context, s.storageTitle);
  }

  @override
  Widget build(BuildContext context) {
    final s = SpyStrings.of(context);
    final store = context.packStore;
    final language = s.localeName;

    // Everything on offer in this language, whatever its state, so the list
    // reads as a catalogue rather than as a queue that empties as you use it.
    final offered = store.catalogue.where((p) => p.language == language).toList()
      ..sort((a, b) {
        final aNeeds = (store.versionOf(a.id) ?? 0) < a.version;
        final bNeeds = (store.versionOf(b.id) ?? 0) < b.version;
        if (aNeeds != bNeeds) return aNeeds ? -1 : 1;
        return a.name.compareTo(b.name);
      });
    final waiting = store.state == CatalogueState.loading && offered.isEmpty;
    final failure = store.failure;

    return SpyScaffold(
      title: s.downloadsTitle,
      onBack: () => Navigator.of(context).pop(),
      body: SpyBody(
        scrollable: true,
        gap: 7,
        children: [
          if (!store.canInstall)
            SpyBanner(
              tone: SpyBannerTone.danger,
              title: s.storageTitle,
              body: s.downloadsNoStorage,
            ),
          if (failure != null && store.state == CatalogueState.failed)
            SpyBanner(
              tone: SpyBannerTone.notice,
              title: networkMessage(s, failure).$1,
              body: networkMessage(s, failure).$2,
              action: SpyButton(
                label: s.commonTryAgain,
                size: SpyButtonSize.small,
                onPressed: () => store.refresh(language: language),
              ),
            ),
          if (waiting)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: SpyPrimitives.s6),
              child: Text(
                s.downloadsLooking,
                textAlign: TextAlign.center,
                style: context.type.caption.copyWith(color: context.spy.textMuted),
              ),
            ),
          if (!waiting && offered.isEmpty && store.state == CatalogueState.ready)
            SpyEmptyState(
              glyph: const SpyIcon(SpyIconData.redact, size: 30),
              title: s.downloadsNothingNew,
              body: s.downloadsNothingNewBody,
            ),
          for (final pack in offered)
            _CatalogueRow(
              pack: pack,
              onInstall: () => _install(pack),
              onRemove: _remove,
            ),
        ],
      ),
    );
  }
}

class _CatalogueRow extends StatelessWidget {
  const _CatalogueRow({
    required this.pack,
    required this.onInstall,
    required this.onRemove,
  });

  final RemotePack pack;
  final VoidCallback onInstall;
  final void Function(WordPack) onRemove;

  @override
  Widget build(BuildContext context) {
    final s = SpyStrings.of(context);
    final store = context.packStore;

    final held = store.versionOf(pack.id);
    final isNew = held == null;
    final needsUpdate = held != null && held < pack.version;
    final working = store.isWorkingOn(pack.id);

    return SpyItemRow(
      leading: SpyMonogram(pack.monogram),
      title: pack.name,
      subtitle: [
        s.packsCount(pack.wordCount),
        if (isNew || needsUpdate) s.downloadsSize(pack.bytes),
      ].join(' · '),
      // Brass for something to do, plain for something already done.
      state: isNew || needsUpdate ? ItemRowState.waiting : ItemRowState.seen,
      trailing: _Action(
        pack: pack,
        working: working,
        isNew: isNew,
        needsUpdate: needsUpdate,
        onInstall: onInstall,
        onRemove: onRemove,
      ),
      semanticLabel: '${pack.name}, ${s.packsCount(pack.wordCount)}. '
          '${isNew || needsUpdate ? s.downloadsGet : s.downloadsBuiltIn}',
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.pack,
    required this.working,
    required this.isNew,
    required this.needsUpdate,
    required this.onInstall,
    required this.onRemove,
  });

  final RemotePack pack;
  final bool working;
  final bool isNew;
  final bool needsUpdate;
  final VoidCallback onInstall;
  final void Function(WordPack) onRemove;

  @override
  Widget build(BuildContext context) {
    final s = SpyStrings.of(context);
    final store = context.packStore;

    if (working) {
      // No spinner: a pack is a couple of kilobytes, and one that flashes for
      // 200ms says less than a word does.
      return _Quiet(s.downloadsGetting);
    }

    if (isNew || needsUpdate) {
      return SpyButton(
        label: needsUpdate ? s.downloadsUpdate : s.downloadsGet,
        kind: SpyButtonKind.primary,
        size: SpyButtonSize.small,
        onPressed: store.canInstall ? onInstall : null,
        disabledReason: store.canInstall ? null : s.downloadsNoStorage,
      );
    }

    // Held at this version or better. Only a downloaded pack can be removed;
    // the ones compiled into the app are part of the binary.
    final installed = store.library.byId(pack.id);
    if (installed != null && store.isRemovable(pack.id)) {
      return SpyButton(
        label: s.downloadsRemove,
        kind: SpyButtonKind.ghost,
        size: SpyButtonSize.small,
        onPressed: () => onRemove(installed),
      );
    }
    // Nothing to do and nothing to undo: this one is part of the binary. The
    // row's stripe already says it is held, so this stays out of the way.
    return _Quiet(s.downloadsBuiltIn);
  }
}

/// The trailing word on a row with no action, in the same voice as ON / OFF on
/// the packs screen. A chip here would be wider than the name beside it.
class _Quiet extends StatelessWidget {
  const _Quiet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: context.type.file.copyWith(
          color: context.spy.textFaint,
          fontSize: 11,
        ),
      );
}
