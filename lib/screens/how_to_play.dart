import 'package:flutter/material.dart';

import '../design/theme.dart';
import '../l10n/strings.dart';
import '../widgets/buttons.dart';
import '../widgets/chips.dart';
import '../widgets/scaffold.dart';

/// Four cards, reached from Home, closed with one tap. Not a tutorial.
///
/// It is never forced in front of anybody, first run included: the game
/// explains itself in one sentence on the hero, and a group that has opened
/// the app wants to deal, not to read.
class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = SpyStrings.of(context);

    return SpyScaffold(
      title: s.howTitle,
      onBack: () => Navigator.of(context).pop(),
      body: SpyBody(
        scrollable: true,
        gap: SpyPrimitives.s5,
        children: [
          _Card(chip: SpyChip(s.number(1).padLeft(2, '0')), body: s.howStep1),
          _Card(chip: SpyChip(s.number(2).padLeft(2, '0')), body: s.howStep2),
          _Card(chip: SpyChip(s.number(3).padLeft(2, '0')), body: s.howStep3),
          _Card(
            chip: SpyChip(s.howSpyLabel, tone: SpyChipTone.spy),
            body: s.howSpy,
          ),
        ],
      ),
      foot: SpyButton(
        label: s.commonGotIt,
        kind: SpyButtonKind.primary,
        size: SpyButtonSize.large,
        onPressed: () => Navigator.of(context).pop(),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.chip, required this.body});

  final Widget chip;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(alignment: AlignmentDirectional.centerStart, child: chip),
        const SizedBox(height: SpyPrimitives.s3),
        Text(
          body,
          style: context.type.body.copyWith(color: context.spy.text),
        ),
      ],
    );
  }
}
