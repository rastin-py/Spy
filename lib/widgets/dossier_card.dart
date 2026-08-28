import 'package:flutter/material.dart';

import '../design/textures.dart';
import '../design/theme.dart';
import '../l10n/strings.dart';
import '../services/haptics.dart';
import 'reveal_slider.dart';

/// The screenshot, the app icon, and the reason nobody sees a card that isn't
/// theirs.
///
/// Secrecy checklist, all four answered here:
///  * backgrounding - one [WidgetsBindingObserver] seals on `inactive`,
///    `paused` and `hidden` alike. iOS fires `inactive` for the Control Centre
///    pull-down and the screenshot flash, which is precisely when a word must
///    not be on screen; handling only `paused` is the bug that ships.
///  * screenshots - the word widget is conditionally built above 0, never
///    `Opacity(0)`, which would keep it in the layer tree and in the capture.
///  * a thumb sliding off the track - release is release, wherever it happens.
///  * a screen reader reading ahead - the word joins the semantics tree only
///    above 0, for the same reason.
class DossierCard extends StatefulWidget {
  const DossierCard({
    required this.playerName,
    required this.word,
    required this.packName,
    required this.isSpy,
    required this.spiesSeeCategory,
    required this.caseNumber,
    required this.round,
    required this.position,
    required this.total,
    required this.onInterrupted,
    this.fill = false,
    super.key,
  });

  final String playerName;

  /// The civilian word. Spies never receive it - it is not passed into a spy
  /// card at all, so there is nothing on screen to fish out.
  final String? word;

  final String packName;
  final bool isSpy;
  final bool spiesSeeCategory;
  final int caseNumber;
  final int round;
  final int position;
  final int total;

  /// A real backgrounding while a card is open. The deal is void: resuming
  /// would mean a phone showing a secret word to whoever is holding it when
  /// the call ends.
  final VoidCallback onInterrupted;

  /// Take all the height on offer, growing the word bay into it, instead of
  /// wrapping the content and leaving a gap above the button. Off when the
  /// screen is scrolling, where "all the height on offer" is unbounded.
  final bool fill;

  @override
  State<DossierCard> createState() => _DossierCardState();
}

class _DossierCardState extends State<DossierCard>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  /// 0..1, and the word's opacity, and nothing else. One number.
  double _value = 0;

  late final AnimationController _seal = AnimationController(
    vsync: this,
    duration: SpyPrimitives.dSeal,
  )..addListener(() {
      // Unguarded on purpose. Skipping the frame where the controller settles
      // would leave the word at whatever opacity the previous frame had, and a
      // card that seals to "nearly hidden" is not sealed.
      setState(() => _value = _sealFrom * (1 - _seal.value));
    });

  double _sealFrom = 0;
  bool _hapticFired = false;
  final FocusNode _sliderFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sliderFocus.addListener(() {
      // Switch access and keyboards keep their value until focus leaves - the
      // one place the secrecy rule bends, because arrow keys have no release.
      if (!_sliderFocus.hasFocus && _value > 0) _sealNow(animate: true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sliderFocus.dispose();
    _seal.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        // Seal first, always, whatever else happens.
        if (_value > 0) _sealNow(animate: false);
        // A genuine backgrounding also voids the deal. `inactive` alone does
        // not: it fires for a Control Centre pull-down, and throwing the round
        // away because somebody checked their brightness would be its own bug.
        if (state != AppLifecycleState.inactive) widget.onInterrupted();
      case AppLifecycleState.resumed:
      case AppLifecycleState.detached:
        break;
    }
  }

  void _sealNow({required bool animate}) {
    _hapticFired = false;
    // Reduced motion turns the seal into a cut. The spring-back itself stays
    // in both cases: it is security, not decoration.
    if (!animate || !mounted || context.reducedMotion) {
      _seal.stop();
      setState(() => _value = 0);
      return;
    }
    _sealFrom = _value;
    _seal.forward(from: 0);
  }

  void _onChanged(double v) {
    _seal.stop();
    setState(() => _value = v);
    if (v > 0.55 && !_hapticFired) {
      _hapticFired = true;
      // The spy's card gets the heavier one - the second channel now that
      // the card itself is framed the same either way, and one nobody across
      // the table can see.
      widget.isSpy ? SpyHaptics.spyReveal() : SpyHaptics.reveal();
    } else if (v <= 0.55) {
      _hapticFired = false;
    }
  }

  /// What the card says out loud. The word appears here only above 0, so a
  /// screen reader cannot read ahead of the slider.
  String _announcement(SpyStrings s) {
    if (_value <= 0) return s.a11yCardSealed(widget.playerName, widget.packName);
    if (widget.isSpy) return s.a11yCardOpenSpy(widget.packName);
    return s.a11yCardOpen(widget.word ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spy;
    final t = context.type;
    final s = SpyStrings.of(context);
    final density = context.density;

    final bay = _WordBay(
      value: _value,
      word: widget.word,
      isSpy: widget.isSpy,
      sealing: _seal.isAnimating,
    );

    return Semantics(
      container: true,
      label: _announcement(s),
      child: Grain(
        borderRadius: BorderRadius.circular(SpyPrimitives.rLg),
        child: Container(
          padding: const EdgeInsetsDirectional.fromSTEB(
            SpyPrimitives.s5,
            SpyPrimitives.s5,
            SpyPrimitives.s5,
            18,
          ),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(SpyPrimitives.rLg),
            // Every card is framed identically. A crimson edge on the spy's
            // card is a tell: it is visible from across the table, before the
            // slider has moved, and the whole point is that the phone gives
            // nothing away to anyone but the person holding it.
            border: Border.all(color: c.borderStrong),
            boxShadow: [c.shadow1],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: widget.fill ? MainAxisSize.max : MainAxisSize.min,
            children: [
              _FileHeader(
                left: s.handoffCase(widget.caseNumber, widget.round),
                right: s.cardPosition(widget.position, widget.total),
                compact: density.isCompact,
              ),
              const SizedBox(height: 14),
              // Never uppercased: it is a person's name, not a screen title.
              Text(
                widget.playerName,
                style: t.title.copyWith(color: c.text),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              if (!widget.isSpy || widget.spiesSeeCategory)
                Text(
                  density.isCompact
                      ? widget.packName
                      : s.cardCategory(widget.packName),
                  style: t.file.copyWith(color: c.accentText, fontSize: 11),
                ),
              const SizedBox(height: SpyPrimitives.s5),
              // The bay is the only part that stretches: the header, the name
              // and the slider are all fixed furniture, so the slack goes to
              // the black slab where the word lands.
              if (widget.fill)
                Expanded(child: bay)
              else
                bay,
              const SizedBox(height: SpyPrimitives.s4),
              RevealSlider(
                value: _value,
                onChanged: _onChanged,
                onReleased: () => _sealNow(animate: true),
                focusNode: _sliderFocus,
                semanticLabel: s.a11yRevealSlider,
                formatValue: s.a11yRevealValue,
              ),
              const SizedBox(height: SpyPrimitives.s2),
              Center(
                child: Text(
                  _value > 0 ? s.cardDragLive : s.cardDrag,
                  style: t.file.copyWith(
                    color: c.textMuted,
                    fontSize: 10.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FileHeader extends StatelessWidget {
  const _FileHeader({required this.left, required this.right, required this.compact});

  final String left;
  final String right;

  /// The file header is the third thing to give way at large text scales,
  /// after the app-bar subtitle and the pack name.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.spy;
    final t = context.type;
    final style = t.file.copyWith(color: c.textFaint);
    return Container(
      padding: const EdgeInsetsDirectional.only(bottom: 9),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              t.uppercases ? left.toUpperCase() : left,
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!compact)
            Text(t.uppercases ? right.toUpperCase() : right, style: style),
        ],
      ),
    );
  }
}

/// The word bay *is* the redaction: a black slab the word burns through.
///
/// `--redact` in both themes - it is not a themed surface. The word is
/// white-on-black in Daylight too, and the slab stays the darkest thing on the
/// phone.
class _WordBay extends StatelessWidget {
  const _WordBay({
    required this.value,
    required this.word,
    required this.isSpy,
    required this.sealing,
  });

  final double value;
  final String? word;
  final bool isSpy;
  final bool sealing;

  @override
  Widget build(BuildContext context) {
    final c = context.spy;
    final t = context.type;
    final s = SpyStrings.of(context);
    final density = context.density;

    final wordSize = switch (density) {
      SpyDensity.compact => 27.0,
      SpyDensity.standard => t.display.fontSize!,
      SpyDensity.wide => 40.0,
    };

    return ClipRRect(
      borderRadius: BorderRadius.circular(SpyPrimitives.rSm),
      child: Blind(
        color: SpyPrimitives.neutral1000,
        child: Container(
          constraints: const BoxConstraints(minHeight: 104),
          width: double.infinity,
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 14,
            vertical: SpyPrimitives.s6,
          ),
          color: c.redact,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // The stub fades out well before the word is legible, so the two
              // never overlap into mud.
              Opacity(
                opacity: (1 - value / 0.6).clamp(0.0, 1.0),
                child: Text(
                  s.cardRedacted,
                  style: t.file.copyWith(
                    color: const Color(0xFF4E5663),
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              // Conditionally built, never faded from zero: an Opacity(0) word
              // is still in the semantics tree and still in a screenshot.
              if (value > 0)
                Opacity(
                  opacity: value.clamp(0.0, 1.0),
                  child: ExcludeSemantics(
                    child: Text(
                      isSpy
                          ? (t.uppercases ? s.cardSpy.toUpperCase() : s.cardSpy)
                          : (t.uppercases
                              ? (word ?? '').toUpperCase()
                              : (word ?? '')),
                      textAlign: TextAlign.center,
                      // Wrapped, never truncated: a truncated secret word is a
                      // broken game. Three lines before it gives an inch.
                      maxLines: 3,
                      style: t.display.copyWith(
                        color: isSpy
                            ? SpyPrimitives.crimson300
                            : SpyPrimitives.neutral1000,
                        fontSize: isSpy ? wordSize * 0.85 : wordSize,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
