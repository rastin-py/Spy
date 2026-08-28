import 'package:flutter/material.dart';

import '../app.dart';
import '../data/settings.dart';
import '../design/theme.dart';
import '../l10n/strings.dart';
import '../widgets/buttons.dart';
import '../widgets/controls.dart';
import '../widgets/dialogs.dart';

/// Optional names, in a sheet rather than on Set up.
///
/// Set up stays three numbers and a pack - no text input and no scrolling on a
/// standard phone - because every second spent there comes off the 45-second
/// test. Names are for the group that plays every week and wants to read
/// "Pass the phone to Sara" instead of "Player 3"; they are never required,
/// and a blank field simply stays numbered.
Future<void> showPlayerNamesSheet(BuildContext context) {
  final s = SpyStrings.of(context);
  // The store is read here, where there is a real build context to read it
  // from, and handed to the sheet - a modal route's initState is too early to
  // go looking for an inherited widget.
  final store = context.settingsStore;
  return showSpySheet<void>(
    context,
    title: s.setupPlayerNames,
    builder: (sheetContext) => _PlayerNamesSheet(store: store),
  );
}

/// Stateful so the controllers live and die with the sheet's own element.
///
/// Disposing them when `showModalBottomSheet` returns is too early: the route
/// is still animating out, and still building these fields.
class _PlayerNamesSheet extends StatefulWidget {
  const _PlayerNamesSheet({required this.store});

  final SettingsStore store;

  @override
  State<_PlayerNamesSheet> createState() => _PlayerNamesSheetState();
}

class _PlayerNamesSheetState extends State<_PlayerNamesSheet> {
  late final List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    final settings = widget.store.value;
    _controllers = [
      for (var i = 0; i < settings.players; i++)
        TextEditingController(
          text: i < settings.playerNames.length ? settings.playerNames[i] : '',
        ),
    ];
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _save() {
    widget.store.edit(
      (old) => old.copyWith(
        // Stored as typed, minus the accidental whitespace. Never uppercased
        // and never title-cased - it is a person's name.
        playerNames: [for (final c in _controllers) c.text.trim()],
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = SpyStrings.of(context);
    return Padding(
      // Lift the fields clear of the keyboard rather than hiding them under it.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            s.setupPlayerNamesHelp,
            style: context.type.caption.copyWith(color: context.spy.textMuted),
          ),
          const SizedBox(height: SpyPrimitives.s5),
          for (var i = 0; i < _controllers.length; i++)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: SpyPrimitives.s3),
              child: SpyTextField(
                controller: _controllers[i],
                // The numbered default doubles as the placeholder, so an empty
                // field shows exactly what leaving it empty will produce.
                hint: s.playerDefault(i + 1),
                textInputAction: i == _controllers.length - 1
                    ? TextInputAction.done
                    : TextInputAction.next,
                onSubmitted: i == _controllers.length - 1 ? (_) => _save() : null,
              ),
            ),
          const SizedBox(height: SpyPrimitives.s3),
          SpyButton(
            label: s.commonDone,
            kind: SpyButtonKind.primary,
            size: SpyButtonSize.large,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
