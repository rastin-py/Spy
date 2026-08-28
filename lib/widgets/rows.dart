import 'package:flutter/material.dart';

import '../design/theme.dart';

enum ItemRowState { waiting, now, seen, spy }

/// A row in a list: the deal queue, the pack list, the last-setup row on Home.
///
/// In the deal queue this is deliberately **not** interactive. It is a progress
/// display; the moment it looks tappable, somebody taps a name expecting to see
/// that person's word.
class SpyItemRow extends StatelessWidget {
  const SpyItemRow({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.state = ItemRowState.waiting,
    this.onTap,
    this.semanticLabel,
    super.key,
  });

  final String title;
  final String? subtitle;

  /// A letter monogram, not a picture.
  final Widget? leading;

  final Widget? trailing;
  final ItemRowState state;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.spy;
    final t = context.type;

    final (Color stripe, Color background) = switch (state) {
      ItemRowState.waiting => (Colors.transparent, c.surfaceRaised),
      ItemRowState.now => (c.accent, c.accentQuiet),
      ItemRowState.seen => (c.ok, c.surfaceRaised),
      ItemRowState.spy => (c.spy, c.surfaceRaised),
    };

    final row = Container(
      constraints: const BoxConstraints(minHeight: SpyPrimitives.tapMin),
      padding: const EdgeInsetsDirectional.fromSTEB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(SpyPrimitives.rMd),
        // The status stripe sits on the leading edge, so it moves to the right
        // in Persian along with everything else.
        border: BorderDirectional(start: BorderSide(color: stripe, width: 2)),
      ),
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: SpyPrimitives.s4),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: t.body.copyWith(
                    color: c.text,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: t.caption.copyWith(color: c.textMuted),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: SpyPrimitives.s3),
            trailing!,
          ],
        ],
      ),
    );

    final labelled = semanticLabel == null
        ? row
        : Semantics(label: semanticLabel, container: true, child: ExcludeSemantics(child: row));

    if (onTap == null) return labelled;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SpyPrimitives.rMd),
        splashFactory: NoSplash.splashFactory,
        child: labelled,
      ),
    );
  }
}

/// A monogram in a brass square. Never a picture: an icon for "Places" only
/// invites an argument about whether a beach is one.
class SpyMonogram extends StatelessWidget {
  const SpyMonogram(this.letter, {super.key});

  final String letter;

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
      child: Text(
        letter,
        style: context.type.title.copyWith(
          color: c.accentText,
          fontSize: 14,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

/// A settings row: label, one line of plain-language help, trailing control.
///
/// Built on a plain Row rather than ListTile - ListTile's vertical padding
/// fights the 44dp target once the text scale goes up.
class SpySettingRow extends StatelessWidget {
  const SpySettingRow({
    required this.label,
    this.help,
    this.trailing,
    this.onTap,
    this.isLast = false,
    super.key,
  });

  final String label;
  final String? help;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final c = context.spy;
    final t = context.type;
    final content = Container(
      constraints: const BoxConstraints(minHeight: SpyPrimitives.tapMin),
      padding: const EdgeInsetsDirectional.symmetric(vertical: SpyPrimitives.s4),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: t.body.copyWith(color: c.text, fontSize: 13)),
                if (help != null)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(top: 3),
                    child: Text(
                      help!,
                      style: t.caption.copyWith(color: c.textMuted),
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 14),
            trailing!,
          ],
        ],
      ),
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        child: content,
      ),
    );
  }
}

/// The trailing "Noir ›" style value on a row that opens something else.
class SpyRowValue extends StatelessWidget {
  const SpyRowValue(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.spy;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: context.type.body.copyWith(
            color: c.textMuted,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(width: SpyPrimitives.s2),
        Text('›', style: TextStyle(color: c.textFaint, fontSize: 16)),
      ],
    );
  }
}

/// A group heading in Settings.
class SpyGroupHeading extends StatelessWidget {
  const SpyGroupHeading(this.text, {this.topGap = SpyPrimitives.s5, super.key});

  final String text;
  final double topGap;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Padding(
      padding: EdgeInsetsDirectional.only(top: topGap, bottom: SpyPrimitives.s2),
      child: Text(
        t.uppercases ? text.toUpperCase() : text,
        style: t.label.copyWith(color: context.spy.textFaint),
      ),
    );
  }
}
