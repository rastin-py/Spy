import 'package:flutter/material.dart';

import '../design/icons.dart';
import '../design/theme.dart';
import '../l10n/strings.dart';

/// Every screen is app bar / flexing body / foot holding the single primary
/// action in thumb reach. Portrait, one column, full bleed.
///
/// The density comes from this widget's own constraints, never from
/// `MediaQuery.size`: the compact breakpoint has to fire on a 400dp phone at
/// 1.6x text scale, and the window size knows nothing about text scale.
class SpyScaffold extends StatelessWidget {
  const SpyScaffold({
    this.title,
    this.subtitle,
    this.onBack,
    this.trailing,
    required this.body,
    this.foot,
    this.background,
    this.showAppBar = true,
    super.key,
  });

  final String? title;

  /// First thing to give way when space runs out.
  final String? subtitle;

  final VoidCallback? onBack;
  final Widget? trailing;
  final Widget body;

  /// The single primary action, plus at most two quieter ones under it.
  final Widget? foot;

  final Color? background;
  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    final c = context.spy;
    return Scaffold(
      backgroundColor: background ?? c.bg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final density = SpyDensity.of(
            constraints.maxWidth,
            MediaQuery.textScalerOf(context),
          );
          return SpyDensityScope(
            density: density,
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  // Wide phones cap and centre; nothing else scales with width.
                  constraints:
                      const BoxConstraints(maxWidth: SpyPrimitives.contentMax),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (showAppBar)
                        _AppBar(
                          title: title,
                          subtitle: density.isCompact ? null : subtitle,
                          onBack: onBack,
                          trailing: trailing,
                        ),
                      Expanded(child: body),
                      if (foot != null) _Foot(child: foot!),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AppBar extends StatelessWidget {
  const _AppBar({this.title, this.subtitle, this.onBack, this.trailing});

  final String? title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.spy;
    final t = context.type;
    final strings = SpyStrings.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        SpyPrimitives.s5,
        14,
        SpyPrimitives.s5,
        SpyPrimitives.s3,
      ),
      child: Row(
        children: [
          if (onBack != null) ...[
            _BackButton(onPressed: onBack!, label: strings.a11yBack),
            const SizedBox(width: SpyPrimitives.s4),
          ],
          if (title != null)
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    t.uppercases ? title!.toUpperCase() : title!,
                    style: t.appBar.copyWith(color: c.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(top: 2),
                      child: Text(
                        subtitle!,
                        style: t.caption.copyWith(color: c.textFaint),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed, required this.label});

  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.spy;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(SpyPrimitives.rSm),
        child: Container(
          // 44 tap target around a 32 box - the box is the drawn thing.
          width: SpyPrimitives.tapMin,
          height: SpyPrimitives.tapMin,
          alignment: Alignment.center,
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: c.border),
              borderRadius: BorderRadius.circular(SpyPrimitives.rSm),
            ),
            child: SpyIcon(SpyIconData.back, size: 16, color: c.textMuted),
          ),
        ),
      ),
    );
  }
}

class _Foot extends StatelessWidget {
  const _Foot({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          SpyPrimitives.s5,
          SpyPrimitives.s4,
          SpyPrimitives.s5,
          18,
        ),
        child: child,
      );
}

/// The body's standard padding and block rhythm.
class SpyBody extends StatelessWidget {
  const SpyBody({
    required this.children,
    this.gap = 14,
    this.scrollable = false,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
    super.key,
  });

  final List<Widget> children;
  final double gap;

  /// At 200% text scale the screen scrolls rather than compressing anything.
  final bool scrollable;

  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final column = Column(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: scrollable ? MainAxisSize.min : MainAxisSize.max,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
          children[i],
        ],
      ],
    );
    const padding = EdgeInsetsDirectional.fromSTEB(
      SpyPrimitives.s5,
      SpyPrimitives.s3,
      SpyPrimitives.s5,
      SpyPrimitives.s5,
    );
    if (!scrollable) return Padding(padding: padding, child: column);
    return SingleChildScrollView(padding: padding, child: column);
  }
}

/// A section label: 10 / 700 / .16em caps, above a block.
class SpyLabel extends StatelessWidget {
  const SpyLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 7),
      child: Text(
        t.uppercases ? text.toUpperCase() : text,
        style: t.label.copyWith(color: context.spy.textFaint),
      ),
    );
  }
}

/// Plain-language help under a control. When a control is disabled this is
/// where the reason goes - a greyed-out button with no explanation is a bug.
class SpyHelp extends StatelessWidget {
  const SpyHelp(this.text, {this.isError = false, super.key});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final c = context.spy;
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 7),
      child: Text(
        text,
        style: context.type.caption.copyWith(
          color: isError ? c.danger : c.textMuted,
        ),
      ),
    );
  }
}
