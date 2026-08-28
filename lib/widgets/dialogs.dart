import 'package:flutter/material.dart';

import '../design/theme.dart';
import 'buttons.dart';

/// Modal, blocks until answered. Used twice in the whole app: abandoning a
/// round, and resetting the settings - the two destructive actions.
Future<bool> showSpyConfirm(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  required String keepLabel,
}) async {
  final c = context.spy;
  final t = context.type;
  final result = await showDialog<bool>(
    context: context,
    barrierColor: c.scrim,
    builder: (context) => Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(SpyPrimitives.s5),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Material(
            color: c.surface,
            borderRadius: BorderRadius.circular(SpyPrimitives.rLg),
            child: Container(
              padding: const EdgeInsetsDirectional.all(SpyPrimitives.s6),
              decoration: BoxDecoration(
                border: Border.all(color: c.border),
                borderRadius: BorderRadius.circular(SpyPrimitives.rLg),
                boxShadow: [c.shadow3],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    t.uppercases ? title.toUpperCase() : title,
                    style: t.appBar.copyWith(color: c.text, fontSize: 16),
                  ),
                  const SizedBox(height: SpyPrimitives.s3),
                  Text(body, style: t.caption.copyWith(color: c.textMuted)),
                  const SizedBox(height: 18),
                  SpyButton(
                    label: keepLabel,
                    kind: SpyButtonKind.secondary,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                  const SizedBox(height: SpyPrimitives.s3),
                  // Crimson-outlined, never crimson-filled: a filled crimson
                  // block is the spy card's visual language.
                  SpyButton(
                    label: confirmLabel,
                    kind: SpyButtonKind.danger,
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return result ?? false;
}

/// A bottom sheet - the only place `rXl` is used.
Future<T?> showSpySheet<T>(
  BuildContext context, {
  required String title,
  required Widget Function(BuildContext) builder,
}) {
  final c = context.spy;
  final t = context.type;
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: c.scrim,
    isScrollControlled: true,
    builder: (context) => Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(SpyPrimitives.rXl),
        ),
        boxShadow: [c.shadow3],
      ),
      padding: const EdgeInsetsDirectional.fromSTEB(
        SpyPrimitives.s5,
        SpyPrimitives.s3,
        SpyPrimitives.s5,
        18,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 34,
                height: 4,
                margin: const EdgeInsetsDirectional.only(bottom: SpyPrimitives.s5),
                decoration: BoxDecoration(
                  color: c.borderStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              t.uppercases ? title.toUpperCase() : title,
              style: t.appBar.copyWith(color: c.text),
            ),
            const SizedBox(height: SpyPrimitives.s5),
            Flexible(child: SingleChildScrollView(child: builder(context))),
          ],
        ),
      ),
    ),
  );
}

/// Icon, the situation, and the single next action as a button. Never a shrug.
class SpyEmptyState extends StatelessWidget {
  const SpyEmptyState({
    required this.title,
    required this.body,
    this.action,
    this.glyph,
    super.key,
  });

  final String title;
  final String body;
  final Widget? action;
  final Widget? glyph;

  @override
  Widget build(BuildContext context) {
    final c = context.spy;
    final t = context.type;
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 18,
          vertical: 28,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (glyph != null) ...[
              IconTheme(
                data: IconThemeData(color: c.textFaint, size: 30),
                child: glyph!,
              ),
              const SizedBox(height: SpyPrimitives.s4),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: t.body.copyWith(
                color: c.text,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 5),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Text(
                body,
                textAlign: TextAlign.center,
                style: t.caption.copyWith(color: c.textMuted),
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 14),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
