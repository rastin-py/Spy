import 'package:flutter/foundation.dart';

import 'app_info.dart';

/// The two things the server says, parsed the same way settings are: tolerantly.
///
/// A field this build does not understand is ignored, and a field it expects
/// but does not get falls back to a default that keeps the app working. The
/// server is an improvement on an app that already works offline, so nothing
/// it can say may put the app into a state where it does not.

/// Every rule about when an advert may appear.
///
/// The defaults here are the same numbers the server ships, with one
/// difference that matters: `enabled` is false. A phone that has never reached
/// the server shows no adverts at all rather than falling back to some other
/// behaviour - adverts are something the network switches on, never something
/// the app decides on its own.
@immutable
class AdsConfig {
  const AdsConfig({
    this.enabled = false,
    this.provider = 'none',
    this.cooldown = const Duration(minutes: 20),
    this.resetOnRestart = true,
    this.minGap = const Duration(seconds: 90),
    this.quietRounds = 1,
    this.placements = const {},
    this.zones = const {},
  });

  /// What every build starts on, and what it stays on offline.
  static const off = AdsConfig();

  /// The only placement there is. Pressing the button on Home that starts a
  /// game - never mid-round, never on the card, never on the clock.
  static const homeStart = 'home_start';

  final bool enabled;

  /// The app only knows the networks it was compiled with. An unknown name
  /// means no adverts, not a guess.
  final String provider;

  final Duration cooldown;

  /// Relaunching clears the cooldown: a new evening should not be silent
  /// because somebody played twenty minutes ago.
  final bool resetOnRestart;

  /// The floor a relaunch cannot get under. Without it, closing and reopening
  /// the app is a way to see an advert every ten seconds, and the person who
  /// finds that out uninstalls.
  final Duration minGap;

  /// Rounds somebody plays before the first advert.
  final int quietRounds;

  final Map<String, bool> placements;
  final Map<String, String> zones;

  bool allows(String placement) => enabled && (placements[placement] ?? false);

  String zone(String placement) => zones[placement] ?? '';

  static AdsConfig tryFrom(Object? source) {
    if (source is! Map) return off;
    int seconds(String key, Duration fallback) {
      final v = source[key];
      return v is int && v >= 0 ? v : fallback.inSeconds;
    }

    return AdsConfig(
      enabled: source['enabled'] == true,
      provider: source['provider'] is String ? source['provider'] as String : 'none',
      cooldown: Duration(
        minutes: source['cooldown_minutes'] is int && source['cooldown_minutes'] >= 0
            ? source['cooldown_minutes'] as int
            : 20,
      ),
      resetOnRestart: source['reset_on_restart'] != false,
      minGap: Duration(seconds: seconds('min_gap_seconds', const Duration(seconds: 90))),
      quietRounds:
          source['quiet_rounds'] is int && source['quiet_rounds'] >= 0
              ? source['quiet_rounds'] as int
              : 1,
      placements: source['placements'] is Map
          ? {
              for (final e in (source['placements'] as Map).entries)
                if (e.key is String && e.value is bool) e.key as String: e.value as bool,
            }
          : const {},
      zones: source['zones'] is Map
          ? {
              for (final e in (source['zones'] as Map).entries)
                if (e.key is String && e.value is String)
                  e.key as String: e.value as String,
            }
          : const {},
    );
  }
}

/// Whether, and how often, to mention that there are more word packs.
@immutable
class PacksNudge {
  const PacksNudge({
    this.enabled = true,
    this.afterRounds = 2,
    this.repeatAfter = const Duration(hours: 72),
  });

  static const standard = PacksNudge();

  final bool enabled;

  /// Not before somebody has played this many rounds. Asking a stranger to go
  /// online before they have finished a game is a way to lose them.
  final int afterRounds;

  /// Once dismissed, stay quiet this long. Zero means never come back.
  final Duration repeatAfter;

  static PacksNudge tryFrom(Object? source) {
    if (source is! Map) return standard;
    return PacksNudge(
      enabled: source['enabled'] != false,
      afterRounds: source['after_rounds'] is int && source['after_rounds'] >= 0
          ? source['after_rounds'] as int
          : 2,
      repeatAfter: Duration(
        hours: source['repeat_after_hours'] is int && source['repeat_after_hours'] >= 0
            ? source['repeat_after_hours'] as int
            : 72,
      ),
    );
  }
}

@immutable
class RemoteConfig {
  const RemoteConfig({
    required this.latestBuild,
    required this.latestVersion,
    required this.minSupportedBuild,
    required this.updateUrl,
    this.changelog = '',
    this.forceUpdate = false,
    this.maintenance = false,
    this.flags = const {},
    this.ads = AdsConfig.off,
    this.nudge = PacksNudge.standard,
    this.adFree = false,
  });

  final int latestBuild;
  final String latestVersion;

  /// Below this the server considers the client too old to be useful.
  final int minSupportedBuild;

  /// A store deep link. Spy never installs anything itself - Bazaar forbids it,
  /// and an app that can install apps is an app nobody should trust with a
  /// party game.
  final String updateUrl;

  final String changelog;
  final bool forceUpdate;
  final bool maintenance;
  final Map<String, bool> flags;

  final AdsConfig ads;
  final PacksNudge nudge;

  /// This install has bought its way out of adverts. Answered in the same call
  /// as everything else, so there is one thing to fail rather than two.
  final bool adFree;

  /// There is something newer than what is running.
  bool get updateAvailable => latestBuild > AppInfo.build;

  /// Newer *and* this build is past its useful life. Still only ever a banner
  /// and a link - the game keeps working, because a group standing round a
  /// table is not going to stop and update.
  bool get updateUrgent =>
      updateAvailable && (forceUpdate || AppInfo.build < minSupportedBuild);

  bool flag(String name, {bool orElse = false}) => flags[name] ?? orElse;

  static RemoteConfig? tryFrom(Object? source) {
    if (source is! Map) return null;
    final latest = source['latest_build'];
    if (latest is! int) return null;
    return RemoteConfig(
      latestBuild: latest,
      latestVersion: source['latest_version'] is String
          ? source['latest_version'] as String
          : AppInfo.version,
      minSupportedBuild:
          source['min_supported_build'] is int ? source['min_supported_build'] as int : 1,
      updateUrl: source['update_url'] is String ? source['update_url'] as String : '',
      changelog: source['changelog'] is String ? source['changelog'] as String : '',
      forceUpdate: source['force_update'] == true,
      maintenance: source['maintenance'] == true,
      ads: AdsConfig.tryFrom(source['ads']),
      nudge: PacksNudge.tryFrom(source['packs_nudge']),
      adFree: source['ad_free'] == true,
      flags: source['flags'] is Map
          ? {
              for (final entry in (source['flags'] as Map).entries)
                if (entry.key is String && entry.value is bool)
                  entry.key as String: entry.value as bool,
            }
          : const {},
    );
  }
}

/// One entry in the catalogue: everything except the words.
///
/// The words are a second request, so browsing what is on offer costs a couple
/// of kilobytes rather than every pack on the server.
@immutable
class RemotePack {
  const RemotePack({
    required this.id,
    required this.language,
    required this.name,
    required this.version,
    required this.wordCount,
    required this.bytes,
    required this.sha256,
    required this.url,
    this.premium = false,
  });

  final String id;
  final String language;

  /// Already in the pack's own language - packs are never translated.
  final String name;

  /// Monotonic. Higher than what is installed means an update is on offer.
  final int version;

  final int wordCount;

  /// The exact size of the body, so the download can be described before it
  /// starts rather than after.
  final int bytes;

  /// Of the bytes the server will send, not of some canonical form of them.
  final String sha256;

  final String url;
  final bool premium;

  String get monogram => name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();

  static RemotePack? tryFrom(Object? source) {
    if (source is! Map) return null;
    final id = source['id'];
    final language = source['language'];
    final name = source['name'];
    final version = source['version'];
    final sha = source['sha256'];
    final url = source['url'];
    // Anything missing one of these cannot be downloaded or verified, so it is
    // dropped rather than shown as an entry that fails when tapped.
    if (id is! String || id.isEmpty) return null;
    if (language is! String || name is! String) return null;
    if (version is! int || sha is! String || url is! String) return null;
    return RemotePack(
      id: id,
      language: language,
      name: name,
      version: version,
      wordCount: source['word_count'] is int ? source['word_count'] as int : 0,
      bytes: source['bytes'] is int ? source['bytes'] as int : 0,
      sha256: sha,
      url: url,
      premium: source['premium'] == true,
    );
  }
}
