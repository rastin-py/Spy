import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../services/api.dart';
import '../services/platform.dart';
import 'remote.dart';
import 'word_packs.dart';

/// Every pack this phone can deal from, whatever its origin.
///
/// The bundled packs and the downloaded ones are the same kind of thing by the
/// time anything reads them - the game does not know or care which is which.
/// A downloaded pack with the same id as a bundled one replaces it, but only
/// at a higher version.
@immutable
class PackLibrary {
  const PackLibrary(this.packs);

  /// What a phone with no storage and no network plays with.
  static const bundled = PackLibrary(WordPacks.all);

  final List<WordPack> packs;

  static PackLibrary merge(List<WordPack> installed) {
    final byId = {for (final pack in WordPacks.all) pack.id: pack};
    for (final pack in installed) {
      final existing = byId[pack.id];
      if (existing == null || pack.version > existing.version) {
        byId[pack.id] = pack;
      }
    }
    return PackLibrary(byId.values.toList());
  }

  /// A Persian UI never offers an English pack: the word is the thing being
  /// guessed, and a language switch would be a tell.
  List<WordPack> forLanguage(String language) {
    final out = packs.where((p) => p.language == language).toList();
    out.sort((a, b) => a.name.compareTo(b.name));
    return out;
  }

  WordPack? byId(String id) {
    for (final pack in packs) {
      if (pack.id == id) return pack;
    }
    return null;
  }
}

/// Where downloaded packs are kept. Swappable so tests need no filesystem.
abstract class PackVault {
  const PackVault();

  Future<List<WordPack>> readAll();
  Future<void> write(WordPack pack);
  Future<void> delete(String id);
}

/// One JSON file per pack, in the app's own directory.
///
/// The same shape as the settings file, and for the same reason: `dart:io` and
/// a rename is fewer moving parts than a store, and it keeps the app free of
/// native code it did not write.
class FilePackVault extends PackVault {
  const FilePackVault(this.directory);

  final String directory;

  static Future<PackVault?> open() async {
    final dir = await SpyPlatform.storageDirectory();
    if (dir == null) return null;
    return FilePackVault('$dir/packs');
  }

  File _file(String id) => File('$directory/$id.json');

  @override
  Future<List<WordPack>> readAll() async {
    final dir = Directory(directory);
    if (!dir.existsSync()) return const [];
    final packs = <WordPack>[];
    for (final entry in dir.listSync()) {
      if (entry is! File || !entry.path.endsWith('.json')) continue;
      try {
        final pack = WordPack.tryFrom(jsonDecode(await entry.readAsString()));
        if (pack != null) packs.add(pack);
      } catch (_) {
        // A pack that will not parse is one pack missing, not a broken app.
        // It stays on disk so a reinstall can overwrite it cleanly.
        continue;
      }
    }
    return packs;
  }

  @override
  Future<void> write(WordPack pack) async {
    final file = _file(pack.id);
    await file.parent.create(recursive: true);
    // Beside, then rename: a phone that dies mid-write leaves the previous
    // pack intact rather than half a file that parses to nothing.
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(pack.toJson()), flush: true);
    await temp.rename(file.path);
  }

  @override
  Future<void> delete(String id) async {
    final file = _file(id);
    if (file.existsSync()) await file.delete();
  }
}

class MemoryPackVault extends PackVault {
  MemoryPackVault([List<WordPack>? initial])
      : _packs = {for (final p in initial ?? const <WordPack>[]) p.id: p};

  final Map<String, WordPack> _packs;

  /// Set to make writes fail, for exercising the storage-error path.
  bool failWrites = false;

  @override
  Future<List<WordPack>> readAll() async => _packs.values.toList();

  @override
  Future<void> write(WordPack pack) async {
    if (failWrites) throw const FileSystemException('no free storage');
    _packs[pack.id] = pack;
  }

  @override
  Future<void> delete(String id) async => _packs.remove(id);
}

/// How the catalogue is doing. Drives exactly one banner on one screen.
enum CatalogueState { idle, loading, ready, failed }

/// The library, plus whatever the server last said was on offer.
///
/// Nothing in here is ever awaited by a screen that has something to show. The
/// library is built from disk before the first frame; the catalogue arrives
/// when it arrives, and until it does the download screen says so.
class PackStore extends ChangeNotifier {
  PackStore({
    required PackVault vault,
    required SpyApi api,
    List<WordPack>? installed,
  })  : this._(vault, api, installed ?? []);

  PackStore._(this._vault, this._api, this._installed);

  final PackVault _vault;
  final SpyApi _api;
  List<WordPack> _installed;

  List<RemotePack> _catalogue = const [];
  CatalogueState _state = CatalogueState.idle;
  ApiFailure? _failure;
  final Set<String> _working = {};

  /// True when the vault could not be opened at all - downloads will not
  /// survive the evening, and the screen says so rather than pretending.
  bool get canInstall => _vault is! _NullVault;

  static Future<PackStore> open({PackVault? vault, SpyApi? api}) async {
    final store = vault ?? await FilePackVault.open() ?? const _NullVault();
    List<WordPack> installed;
    try {
      installed = await store.readAll();
    } catch (_) {
      installed = const [];
    }
    return PackStore(vault: store, api: api ?? SpyApi(), installed: installed);
  }

  PackLibrary get library => PackLibrary.merge(_installed);
  List<WordPack> get installed => List.unmodifiable(_installed);
  List<RemotePack> get catalogue => List.unmodifiable(_catalogue);
  CatalogueState get state => _state;
  ApiFailure? get failure => _failure;

  bool isWorkingOn(String id) => _working.contains(id);

  /// What version of [id] this phone holds, bundled or downloaded, or null.
  int? versionOf(String id) => library.byId(id)?.version;

  /// A downloaded pack that is not simply the bundled one. Only these can be
  /// removed - the compiled-in packs are part of the binary.
  bool isRemovable(String id) {
    final downloaded = _installed.any((p) => p.id == id);
    if (!downloaded) return false;
    final bundled = WordPacks.byId(id);
    return bundled == null || (versionOf(id) ?? 0) > bundled.version;
  }

  /// The catalogue, filtered to what this phone does not already have at this
  /// version or better.
  List<RemotePack> updatesIn(String language) => [
        for (final pack in _catalogue)
          if (pack.language == language && (versionOf(pack.id) ?? 0) < pack.version) pack,
      ];

  // ---------------------------------------------------------------- fetching

  Future<void> refresh({required String language}) async {
    if (_state == CatalogueState.loading) return;
    _state = CatalogueState.loading;
    _failure = null;
    notifyListeners();
    try {
      _catalogue = await _api.catalogue(language: language);
      _state = CatalogueState.ready;
    } on ApiException catch (error) {
      _failure = error.failure;
      _state = CatalogueState.failed;
    } catch (_) {
      _failure = ApiFailure.server;
      _state = CatalogueState.failed;
    }
    notifyListeners();
  }

  /// Downloads, verifies and writes one pack. Returns the reason it did not,
  /// or null when it did.
  ///
  /// Nothing is written until the bytes have been checked against the hash the
  /// catalogue published, so a failed install leaves the previous pack exactly
  /// where it was.
  Future<ApiFailure?> install(RemotePack pack) async {
    if (_working.contains(pack.id)) return null;
    _working.add(pack.id);
    notifyListeners();
    try {
      final downloaded = await _api.download(pack);
      await _vault.write(downloaded);
      _installed = [
        ..._installed.where((p) => p.id != downloaded.id),
        downloaded,
      ];
      return null;
    } on ApiException catch (error) {
      return error.failure;
    } catch (_) {
      // A write that did not land. Same shape of answer as a settings write
      // that failed: say so, change nothing.
      return ApiFailure.server;
    } finally {
      _working.remove(pack.id);
      notifyListeners();
    }
  }

  /// Drops a downloaded pack. A bundled pack underneath it comes back.
  Future<bool> remove(String id) async {
    try {
      await _vault.delete(id);
      _installed = _installed.where((p) => p.id != id).toList();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// No storage: the app runs, downloads are refused up front rather than
/// appearing to work and vanishing at the next launch.
class _NullVault extends PackVault {
  const _NullVault();

  @override
  Future<List<WordPack>> readAll() async => const [];

  @override
  Future<void> write(WordPack pack) async =>
      throw const FileSystemException('nowhere to write');

  @override
  Future<void> delete(String id) async {}
}
