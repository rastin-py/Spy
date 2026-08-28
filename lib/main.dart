import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'data/ads.dart';
import 'data/game.dart';
import 'data/pack_store.dart';
import 'data/settings.dart';
import 'data/update_store.dart';
import 'design/textures.dart';
import 'services/api.dart';
import 'services/audio.dart';
import 'services/telemetry.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Settings and downloaded packs are read before the first frame so Home has
  // no loading state - there is nothing to wait for, and a spinner on the way
  // to "Same again" would cost more than the two file reads do.
  final settings = await SettingsStore.open();
  final api = SpyApi();
  final packs = await PackStore.open(api: api);

  final telemetry = SpyTelemetry(
    api: api,
    installId: settings.value.installId,
  );
  final ads = AdController(settings: settings, telemetry: telemetry);

  // The version check is also where the ad rules and the entitlement arrive,
  // so it is the one call that has to happen without anybody asking - and the
  // one whose failure has to change nothing at all.
  final updates = UpdateStore(
    api: api,
    installId: settings.value.installId,
    onConfig: ads.apply,
  );

  // None of these may gate the first frame. The orientation lock in
  // particular never resolves on a host that will not lock, and Home is
  // meant to be one tap from dealing - the grain is decoration, the audio
  // is atmosphere, and the version check is somebody else's opinion.
  unawaited(lockOrientation());
  unawaited(SpyTextures.warmUp());
  unawaited(SpyAudio.instance.warmUp());
  unawaited(updates.refresh());

  telemetry.record('app_open');

  runApp(SpyApp(
    settings: settings,
    game: GameController(),
    packs: packs,
    updates: updates,
    ads: ads,
    telemetry: telemetry,
  ));
}
