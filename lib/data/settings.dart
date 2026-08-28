import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../services/platform.dart';
import '../services/telemetry.dart' show newInstallId;
import 'word_packs.dart';

enum SpyThemeChoice { system, noir, daylight }

enum SpyLanguage {
  system,
  en,
  fa;

  String? get code => this == SpyLanguage.system ? null : name;
}

/// Everything the app remembers between evenings.
///
/// Settings are read synchronously at startup - Home has no loading state
/// because there is nothing to wait for.
@immutable
class SpySettings {
  const SpySettings({
    this.clockSound = true,
    this.bellAtZero = true,
    this.haptics = true,
    this.spiesSeeCategory = true,
    this.noRepeatWords = true,
    this.keepAwake = false,
    this.theme = SpyThemeChoice.system,
    this.language = SpyLanguage.system,
    this.enabledPacks = WordPacks.defaultOn,
    this.players = 5,
    this.spies = 1,
    this.roundLength = const Duration(minutes: 8),
    this.playerNames = const [],
    this.lastPlayedAt,
    this.caseNumber = 1,
    this.round = 1,
    this.playedWords = const {},
    this.installId = '',
    this.roundsPlayed = 0,
    this.lastAdAt,
    this.adFree = false,
    this.packsNudgedAt,
  });

  final bool clockSound;
  final bool bellAtZero;
  final bool haptics;
  final bool spiesSeeCategory;
  final bool noRepeatWords;
  final bool keepAwake;
  final SpyThemeChoice theme;
  final SpyLanguage language;

  /// Pack ids, across both languages. Filtered by locale at the point of use.
  final Set<String> enabledPacks;

  final int players;
  final int spies;
  final Duration roundLength;

  /// Optional, and sparse - index i is player i's name, or blank for the
  /// numbered default. Names are stored as typed and never uppercased.
  final List<String> playerNames;

  final DateTime? lastPlayedAt;

  /// Set dressing that also happens to tell two evenings apart in a screenshot.
  final int caseNumber;
  final int round;

  /// Pack id -> words already dealt, so "don't repeat words" can hold.
  final Map<String, Set<String>> playedWords;

  /// A random number this phone calls itself, made up on first run.
  ///
  /// Not a device id and not an advertising id - it means nothing outside
  /// Spy, and clearing the app's data makes a new one. It is what a receipt is
  /// attached to and what a counter is grouped by, and it is the only
  /// identifier in the whole app.
  final String installId;

  /// Rounds dealt on this phone, ever. Adverts and the packs nudge both hold
  /// off until somebody has actually played.
  final int roundsPlayed;

  /// When the last advert was shown. The cooldown is measured from here.
  final DateTime? lastAdAt;

  /// Remembered from the last time the server was reachable, so somebody who
  /// paid still sees no adverts on a train.
  final bool adFree;

  /// When the "there are more word packs" note was last dismissed.
  final DateTime? packsNudgedAt;

  /// 3-12 people in one room. Below three there is no room to hide; above
  /// twelve nobody gets a turn to ask anything.
  static const minPlayers = 3;
  static const maxPlayers = 12;

  static const lengthOptions = [
    Duration(minutes: 3),
    Duration(minutes: 5),
    Duration(minutes: 8),
    Duration(minutes: 10),
  ];

  /// The most spies the game survives: roughly a quarter of the table, never
  /// fewer than one. Four spies among seven is not a deduction game.
  static int spyCeiling(int players) => (players / 3).floor().clamp(1, players - 2);

  /// Long enough that questions get past the obvious, short enough that the
  /// table does not drift into another conversation.
  static Duration suggestedLength(int players) => switch (players) {
        <= 4 => const Duration(minutes: 5),
        <= 7 => const Duration(minutes: 8),
        _ => const Duration(minutes: 10),
      };

  int get effectiveSpies => spies.clamp(1, spyCeiling(players));

  SpySettings copyWith({
    bool? clockSound,
    bool? bellAtZero,
    bool? haptics,
    bool? spiesSeeCategory,
    bool? noRepeatWords,
    bool? keepAwake,
    SpyThemeChoice? theme,
    SpyLanguage? language,
    Set<String>? enabledPacks,
    int? players,
    int? spies,
    Duration? roundLength,
    List<String>? playerNames,
    DateTime? lastPlayedAt,
    int? caseNumber,
    int? round,
    Map<String, Set<String>>? playedWords,
    String? installId,
    int? roundsPlayed,
    DateTime? lastAdAt,
    bool? adFree,
    DateTime? packsNudgedAt,
  }) {
    return SpySettings(
      clockSound: clockSound ?? this.clockSound,
      bellAtZero: bellAtZero ?? this.bellAtZero,
      haptics: haptics ?? this.haptics,
      spiesSeeCategory: spiesSeeCategory ?? this.spiesSeeCategory,
      noRepeatWords: noRepeatWords ?? this.noRepeatWords,
      keepAwake: keepAwake ?? this.keepAwake,
      theme: theme ?? this.theme,
      language: language ?? this.language,
      enabledPacks: enabledPacks ?? this.enabledPacks,
      players: players ?? this.players,
      spies: spies ?? this.spies,
      roundLength: roundLength ?? this.roundLength,
      playerNames: playerNames ?? this.playerNames,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      caseNumber: caseNumber ?? this.caseNumber,
      round: round ?? this.round,
      playedWords: playedWords ?? this.playedWords,
      installId: installId ?? this.installId,
      roundsPlayed: roundsPlayed ?? this.roundsPlayed,
      lastAdAt: lastAdAt ?? this.lastAdAt,
      adFree: adFree ?? this.adFree,
      packsNudgedAt: packsNudgedAt ?? this.packsNudgedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'clockSound': clockSound,
        'bellAtZero': bellAtZero,
        'haptics': haptics,
        'spiesSeeCategory': spiesSeeCategory,
        'noRepeatWords': noRepeatWords,
        'keepAwake': keepAwake,
        'theme': theme.name,
        'language': language.name,
        'enabledPacks': enabledPacks.toList(),
        'players': players,
        'spies': spies,
        'roundLengthSeconds': roundLength.inSeconds,
        'playerNames': playerNames,
        'lastPlayedAt': lastPlayedAt?.toIso8601String(),
        'caseNumber': caseNumber,
        'round': round,
        'playedWords': playedWords.map((k, v) => MapEntry(k, v.toList())),
        'installId': installId,
        'roundsPlayed': roundsPlayed,
        'lastAdAt': lastAdAt?.toIso8601String(),
        'adFree': adFree,
        'packsNudgedAt': packsNudgedAt?.toIso8601String(),
      };

  /// Tolerant by design: a field this build does not understand, or one that
  /// was written by a newer build, falls back to its default rather than
  /// throwing away the whole file.
  static SpySettings fromJson(Map<String, dynamic> json) {
    T pick<T>(String key, T fallback) {
      final v = json[key];
      return v is T ? v : fallback;
    }

    const defaults = SpySettings();
    final rawNames = json['playerNames'];
    final rawPacks = json['enabledPacks'];
    final rawPlayed = json['playedWords'];
    final rawDate = json['lastPlayedAt'];

    DateTime? date(String key) {
      final raw = json[key];
      return raw is String ? DateTime.tryParse(raw) : null;
    }

    return SpySettings(
      clockSound: pick('clockSound', defaults.clockSound),
      bellAtZero: pick('bellAtZero', defaults.bellAtZero),
      haptics: pick('haptics', defaults.haptics),
      spiesSeeCategory: pick('spiesSeeCategory', defaults.spiesSeeCategory),
      noRepeatWords: pick('noRepeatWords', defaults.noRepeatWords),
      keepAwake: pick('keepAwake', defaults.keepAwake),
      theme: SpyThemeChoice.values.firstWhere(
        (t) => t.name == json['theme'],
        orElse: () => defaults.theme,
      ),
      language: SpyLanguage.values.firstWhere(
        (l) => l.name == json['language'],
        orElse: () => defaults.language,
      ),
      enabledPacks: rawPacks is List
          ? rawPacks.whereType<String>().toSet()
          : defaults.enabledPacks,
      players: pick('players', defaults.players).clamp(minPlayers, maxPlayers),
      spies: pick('spies', defaults.spies),
      roundLength: Duration(
        seconds: pick('roundLengthSeconds', defaults.roundLength.inSeconds),
      ),
      playerNames:
          rawNames is List ? rawNames.whereType<String>().toList() : defaults.playerNames,
      lastPlayedAt: rawDate is String ? DateTime.tryParse(rawDate) : null,
      caseNumber: pick('caseNumber', defaults.caseNumber),
      round: pick('round', defaults.round),
      playedWords: rawPlayed is Map
          ? rawPlayed.map(
              (k, v) => MapEntry(
                k as String,
                v is List ? v.whereType<String>().toSet() : <String>{},
              ),
            )
          : defaults.playedWords,
      installId: pick('installId', defaults.installId),
      roundsPlayed: pick('roundsPlayed', defaults.roundsPlayed),
      lastAdAt: date('lastAdAt'),
      adFree: pick('adFree', defaults.adFree),
      packsNudgedAt: date('packsNudgedAt'),
    );
  }
}

/// Where settings are kept. Swappable so tests do not need a phone under them.
abstract class SettingsBackend {
  const SettingsBackend();

  /// The stored JSON, or null when nothing has been written yet.
  /// Throws if storage exists but cannot be read.
  Future<String?> read();

  /// Throws if the write did not land.
  Future<void> write(String json);
}

/// A JSON file in the app's own directory.
///
/// A file rather than a key-value plugin: Spy stores one small object, and one
/// `dart:io` write is fewer moving parts than a platform preferences store -
/// and no third-party native code.
class FileSettingsBackend extends SettingsBackend {
  const FileSettingsBackend(this._path);

  final String _path;

  static Future<SettingsBackend?> open() async {
    final dir = await SpyPlatform.storageDirectory();
    if (dir == null) return null;
    return FileSettingsBackend('$dir/settings.json');
  }

  File get _file => File(_path);

  @override
  Future<String?> read() async {
    final file = _file;
    if (!file.existsSync()) return null;
    return file.readAsString();
  }

  @override
  Future<void> write(String json) async {
    // Write beside, then rename: a phone that dies mid-write leaves the old
    // settings intact rather than half a file that parses to nothing.
    await _file.parent.create(recursive: true);
    final temp = File('$_path.tmp');
    await temp.writeAsString(json, flush: true);
    await temp.rename(_path);
  }
}

/// Holds settings for this session only. The fallback when there is nowhere to
/// write, and what tests run against.
class MemorySettingsBackend extends SettingsBackend {
  MemorySettingsBackend([this._json]);

  String? _json;

  /// Set to make writes fail, for exercising the storage-error path.
  bool failWrites = false;

  @override
  Future<String?> read() async => _json;

  @override
  Future<void> write(String json) async {
    if (failWrites) throw const FileSystemException('no free storage');
    _json = json;
  }
}

/// Reads once at startup, then holds the settings in memory and writes through.
///
/// A failed write is never silent: [update] returns false, and the caller
/// reverts the row it changed and says what happened.
class SettingsStore extends ChangeNotifier {
  SettingsStore(this._backend, this._value, {this.loadFailed = false});

  final SettingsBackend _backend;
  SpySettings _value;

  /// True when storage could not be read at all - the app runs on defaults and
  /// says so, rather than pretending the evening started fresh on purpose.
  final bool loadFailed;

  SpySettings get value => _value;

  /// Read before the first frame, so Home has no loading state.
  static Future<SettingsStore> open({SettingsBackend? backend}) async {
    final store = backend ?? await FileSettingsBackend.open();
    if (store == null) {
      // Nowhere to write means no install id: a phone that cannot remember one
      // must not invent a new identity on every launch, so it counts nothing
      // and buys nothing rather than looking like a new user every evening.
      return SettingsStore(MemorySettingsBackend(), const SpySettings());
    }
    try {
      final raw = await store.read();
      final settings = raw == null
          ? const SpySettings()
          : SpySettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      final seeded = await _withInstallId(store, settings);
      return SettingsStore(store, seeded);
    } catch (_) {
      // Unreadable or corrupt: run on defaults, and let Home say so.
      return SettingsStore(store, const SpySettings(), loadFailed: true);
    }
  }

  /// Mints the install id on first run and writes it through immediately.
  ///
  /// Written here rather than lazily, because an id that only survives if some
  /// later write happens is an id that changes when a phone runs out of space
  /// - and a receipt is attached to it.
  static Future<SpySettings> _withInstallId(
    SettingsBackend backend,
    SpySettings settings,
  ) async {
    if (settings.installId.isNotEmpty) return settings;
    final seeded = settings.copyWith(installId: newInstallId());
    try {
      await backend.write(jsonEncode(seeded.toJson()));
      return seeded;
    } catch (_) {
      // No storage. Runs without one rather than with a different one each
      // launch.
      return settings;
    }
  }

  /// Applies [next] optimistically and writes it through. Returns false if the
  /// write failed, having already rolled the in-memory value back.
  Future<bool> update(SpySettings next) async {
    final previous = _value;
    _value = next;
    notifyListeners();
    try {
      await _backend.write(jsonEncode(next.toJson()));
      return true;
    } catch (_) {
      _value = previous;
      notifyListeners();
      return false;
    }
  }

  Future<bool> edit(SpySettings Function(SpySettings) change) =>
      update(change(_value));

  Future<bool> reset() => update(const SpySettings());
}
