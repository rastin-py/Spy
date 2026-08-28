import 'package:flutter/material.dart';

import '../design/theme.dart';

enum SpyChipTone { accent, spy, notice, ok, quiet }

/// Small, non-interactive, and exempt from the 44dp rule because of it.
class SpyChip extends StatelessWidget {
  const SpyChip(this.label, {this.tone = SpyChipTone.accent, super.key});

  final String label;
  final SpyChipTone tone;

  @override
  Widget build(BuildContext context) {
    final c = context.spy;
    final t = context.type;
    final (Color fg, Color bg) = switch (tone) {
      SpyChipTone.accent => (c.accentText, c.accentQuiet),
      SpyChipTone.spy => (c.spy, c.spyQuiet),
      SpyChipTone.notice => (c.notice, c.noticeBg),
      SpyChipTone.ok => (c.ok, c.okBg),
      SpyChipTone.quiet => (c.textMuted, c.surfaceSunken),
    };
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(SpyPrimitives.rFull),
      ),
      child: Text(
        t.uppercases ? label.toUpperCase() : label,
        style: t.label.copyWith(color: fg, letterSpacing: t.uppercases ? 1.0 : null),
      ),
    );
  }
}

enum SpyBannerTone { notice, accent, danger }

/// Persistent, in the layout - not an overlay and not a toast.
///
/// There is no `warn` tone, because nothing in Spy is a warning. The one
/// caution-shaped message ("your phone is on silent") is a steel notice.
class SpyBanner extends StatelessWidget {
  const SpyBanner({
    required this.title,
    this.body,
    this.tone = SpyBannerTone.notice,
    this.action,
    super.key,
  });

  final String title;
  final String? body;
  final SpyBannerTone tone;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.spy;
    final t = context.type;
    final (Color fg, Color bg) = switch (tone) {
      SpyBannerTone.notice => (c.notice, c.noticeBg),
      SpyBannerTone.accent => (c.accentText, c.accentQuiet),
      SpyBannerTone.danger => (c.danger, c.dangerBg),
    };
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(13, 11, 13, 11),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(SpyPrimitives.rMd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: t.caption.copyWith(color: fg, fontWeight: FontWeight.w700),
            ),
            if (body != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 2),
                child: Text(body!, style: t.caption.copyWith(color: fg)),
              ),
            if (action != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: SpyPrimitives.s3),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: action,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Four seconds, one at a time. Never for the user's own action - a switch
/// moving is the acknowledgement that the switch moved.
void showSpyToast(BuildContext context, String message, {String? actionLabel, VoidCallback? onAction}) {
  final c = context.spy;
  final t = context.type;
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 4),
      backgroundColor: c.surfaceRaised,
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SpyPrimitives.rMd),
        side: BorderSide(color: c.border),
      ),
      content: Text(message, style: t.caption.copyWith(color: c.text)),
      action: actionLabel == null
          ? null
          : SnackBarAction(
              label: actionLabel,
              textColor: c.accentText,
              onPressed: onAction ?? () {},
            ),
    ),
  );
}
