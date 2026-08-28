import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spy/app.dart';
import 'package:spy/data/game.dart';
import 'package:spy/data/pack_store.dart';
import 'package:spy/data/remote.dart';
import 'package:spy/data/settings.dart';
import 'package:spy/data/update_store.dart';
import 'package:spy/data/word_packs.dart';
import 'package:spy/screens/pack_downloads.dart';
import 'package:spy/screens/packs.dart';
import 'package:spy/services/api.dart';
import 'package:spy/widgets/buttons.dart';

/// Downloaded packs, and the promise that none of it can break a phone that
/// never reaches the server.
void main() {
  const base = 'https://api.test';

  /// One pack, the catalogue entry describing it, and the bytes in between.
  ({Map<String, dynamic> summary, Uint8List body}) publish(WordPack pack) {
    final body = Uint8List.fromList(utf8.encode(jsonEncode(pack.toJson())));
    return (
      summary: {
        'id': pack.id,
        'language': pack.language,
        'name': pack.name,
        'version': pack.version,
        'word_count': pack.words.length,
        'bytes': body.length,
        'sha256': sha256.convert(body).toString(),
        'url': '$base/v1/packs/${pack.id}/${pack.version}',
      },
      body: body,
    );
  }

  /// A server that answers from a map of paths, or refuses in a stated way.
  SpyApi serving(
    List<WordPack> packs, {
    ApiFailure? failWith,
    Uint8List Function(Uint8List)? tamper,
    List<Map<String, dynamic>> extraEntries = const [],
  }) {
    final published = {for (final p in packs) p.id: publish(p)};
    return SpyApi(
      baseUrl: base,
      fetch: (uri, {String? body}) async {
        if (failWith != null) throw ApiException(failWith);
        if (uri.path == '/v1/packs') {
          final lang = uri.queryParameters['lang'];
          final body = jsonEncode({
            'packs': [
              for (final entry in published.entries)
                if (entry.value.summary['language'] == lang) entry.value.summary,
              ...extraEntries,
            ],
          });
          return ApiResponse(200, Uint8List.fromList(utf8.encode(body)));
        }
        for (final entry in published.entries) {
          if (uri.path == '/v1/packs/${entry.key}/'
              '${entry.value.summary['version']}') {
            final bytes = entry.value.body;
            return ApiResponse(200, tamper == null ? bytes : tamper(bytes));
          }
        }
        return ApiResponse(404, Uint8List(0));
      },
    );
  }

  const music = WordPack(
    id: 'music',
    language: 'en',
    name: 'Music',
    words: ['Encore', 'Vinyl record', 'Drum solo', 'Busker'],
  );

  /// A second edition of a pack that ships inside the app.
  final placesV2 = WordPack(
    id: 'places',
    language: 'en',
    name: 'Places',
    version: 2,
    words: [...WordPacks.places.words, 'Bunker'],
  );

  Future<PackStore> storeWith(SpyApi api, {List<WordPack>? installed}) async =>
      PackStore(
        vault: MemoryPackVault(installed),
        api: api,
        installed: installed,
      );

  group('the library', () {
    test('a phone that has never been online still has every bundled pack', () {
      expect(PackLibrary.bundled.forLanguage('en'), isNotEmpty);
      expect(PackLibrary.bundled.forLanguage('fa'), isNotEmpty);
    });

    test('a downloaded pack joins the bundled ones as an equal', () async {
      final store = await storeWith(serving([music]), installed: [music]);

      final english = store.library.forLanguage('en').map((p) => p.id);
      expect(english, contains('music'));
      expect(english, contains('places'), reason: 'the built-in packs stay');
    });

    test('a newer edition of a bundled pack wins, an older one does not',
        () async {
      final newer = await storeWith(serving([]), installed: [placesV2]);
      expect(newer.library.byId('places')!.words, contains('Bunker'));

      const stale = WordPack(
        id: 'places',
        language: 'en',
        name: 'Places',
        words: ['Nowhere'],
      );
      final older = await storeWith(serving([]), installed: [stale]);
      expect(
        older.library.byId('places')!.words.length,
        WordPacks.places.size,
        reason: 'a download at the same version must not replace the binary',
      );
    });

    test('the dealer draws from downloaded packs without knowing it', () async {
      final store = await storeWith(serving([music]), installed: [music]);
      final result = GameController(random: Random(3)).deal(
        settings: const SpySettings(players: 4, enabledPacks: {'music'}),
        language: 'en',
        defaultName: (n) => 'Player $n',
        library: store.library,
      );

      expect(result.failure, isNull);
      expect(music.words, contains(result.round!.word));
    });
  });

  group('downloading', () {
    test('the catalogue lists what is new and what is already held', () async {
      final store = await storeWith(serving([music, placesV2]));
      await store.refresh(language: 'en');

      expect(store.state, CatalogueState.ready);
      expect(
        store.updatesIn('en').map((p) => p.id),
        containsAll(<String>['music', 'places']),
        reason: 'one is new, the other is a newer edition of a bundled pack',
      );
    });

    test('installing puts the words on the phone and in the library', () async {
      final store = await storeWith(serving([music]));
      await store.refresh(language: 'en');

      expect(await store.install(store.catalogue.single), isNull);
      expect(store.library.byId('music')!.words, music.words);
      expect(store.updatesIn('en'), isEmpty, reason: 'nothing left to get');
    });

    test('a pack that arrives damaged is refused and nothing is written',
        () async {
      // One byte short: still valid JSON in shape, but not what was promised.
      final store = await storeWith(
        serving([music], tamper: (bytes) => bytes.sublist(0, bytes.length - 1)),
      );
      await store.refresh(language: 'en');

      expect(await store.install(store.catalogue.single), ApiFailure.corrupt);
      expect(store.library.byId('music'), isNull);
      expect(store.installed, isEmpty);
    });

    test('a catalogue entry that cannot be verified is dropped, not shown',
        () async {
      final store = await storeWith(
        serving([music], extraEntries: [
          // No sha256: there would be no way to check what came back.
          {'id': 'broken', 'language': 'en', 'name': 'Broken', 'version': 1},
        ]),
      );
      await store.refresh(language: 'en');

      expect(store.catalogue.map((p) => p.id), ['music']);
    });

    test('removing a downloaded edition brings the bundled one back', () async {
      final store = await storeWith(serving([placesV2]));
      await store.refresh(language: 'en');
      await store.install(store.catalogue.single);
      expect(store.library.byId('places')!.version, 2);
      expect(store.isRemovable('places'), isTrue);

      expect(await store.remove('places'), isTrue);
      expect(store.library.byId('places')!.version, 1);
      expect(
        store.library.byId('places')!.words.length,
        WordPacks.places.size,
        reason: 'the pack compiled into the app cannot be deleted',
      );
    });

    test('a bundled pack on its own is never offered for removal', () async {
      final store = await storeWith(serving([]));
      expect(store.isRemovable('places'), isFalse);
    });

    test('no network leaves the library exactly as it was', () async {
      final store = await storeWith(
        serving([music], failWith: ApiFailure.offline),
        installed: [music],
      );
      final before = store.library.packs.length;
      await store.refresh(language: 'en');

      expect(store.state, CatalogueState.failed);
      expect(store.failure, ApiFailure.offline);
      expect(store.library.packs.length, before);
      expect(store.library.byId('music'), isNotNull);
    });

    test('a phone with nowhere to write says so instead of pretending',
        () async {
      final vault = MemoryPackVault()..failWrites = true;
      final store = PackStore(vault: vault, api: serving([music]));
      await store.refresh(language: 'en');

      expect(await store.install(store.catalogue.single), ApiFailure.server);
      expect(store.library.byId('music'), isNull);
    });
  });

  group('the version check', () {
    RemoteConfig config({int latest = 1, int min = 1, bool force = false}) =>
        RemoteConfig(
          latestBuild: latest,
          latestVersion: '1.$latest.0',
          minSupportedBuild: min,
          updateUrl: 'bazaar://details?id=ir.topazapps.spy',
          forceUpdate: force,
        );

    test('the running build is never told to update to itself', () {
      expect(config().updateAvailable, isFalse);
      expect(config().updateUrgent, isFalse);
    });

    test('a newer build is an offer, an unsupported one is a warning', () {
      expect(config(latest: 9).updateAvailable, isTrue);
      expect(config(latest: 9).updateUrgent, isFalse);
      expect(config(latest: 9, min: 5).updateUrgent, isTrue);
      expect(config(latest: 9, force: true).updateUrgent, isTrue);
    });

    test('an unreadable answer is no answer, not a crash', () {
      expect(RemoteConfig.tryFrom('not json'), isNull);
      expect(RemoteConfig.tryFrom({'latest_version': '2.0.0'}), isNull);
      // Everything optional missing is still a usable answer.
      expect(RemoteConfig.tryFrom({'latest_build': 4})?.latestBuild, 4);
    });
  });

  group('on screen', () {
    /// Home, with a server that answers the way this test wants it to.
    Future<PackStore> pumpApp(
      WidgetTester tester, {
      required SpyApi api,
      List<WordPack>? installed,
    }) async {
      final settings = await SettingsStore.open(backend: MemorySettingsBackend());
      final packs = PackStore(
        vault: MemoryPackVault(installed),
        api: api,
        installed: installed,
      );
      await tester.pumpWidget(SpyApp(
        settings: settings,
        game: GameController(),
        packs: packs,
        updates: UpdateStore(api: api),
      ));
      await tester.pumpAndSettle();
      return packs;
    }

    /// Home -> Settings -> Word packs -> the one affordance the feature hangs
    /// off. Walked rather than routed to directly, because the route into it
    /// is half of what is being tested.
    Future<void> openDownloads(WidgetTester tester) async {
      await tester.tap(find.byType(SpyIconButton));
      await tester.pumpAndSettle();

      final packsRow = find.text('Word packs');
      await tester.ensureVisible(packsRow);
      await tester.pumpAndSettle();
      await tester.tap(packsRow);
      await tester.pumpAndSettle();
      expect(find.byType(PacksScreen), findsOneWidget);

      final connect = find.text(
        'Connect to the network to download the latest packs',
      );
      await tester.ensureVisible(connect);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Download packs'));
      await tester.pumpAndSettle();
    }

    testWidgets('the packs screen leads to the downloads screen',
        (tester) async {
      await pumpApp(tester, api: serving([music]));
      await openDownloads(tester);

      expect(find.byType(PackDownloadsScreen), findsOneWidget);
      expect(find.text('Music'), findsOneWidget);
    });

    testWidgets('a pack on offer can be taken, and then says it is held',
        (tester) async {
      final store = await pumpApp(tester, api: serving([music]));
      await openDownloads(tester);

      expect(find.text('Get'), findsOneWidget);
      await tester.tap(find.text('Get'));
      await tester.pumpAndSettle();

      expect(store.library.byId('music')!.words, music.words);
      expect(find.text('Get'), findsNothing);
      expect(find.text('Remove'), findsOneWidget);
    });

    testWidgets('no network states the reason and offers to try again',
        (tester) async {
      final store = await pumpApp(
        tester,
        api: serving([music], failWith: ApiFailure.offline),
      );
      await openDownloads(tester);

      expect(find.text('No network'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      // The whole point of surviving a failure: the game is untouched.
      expect(store.library.forLanguage('en'), isNotEmpty);
    });

    testWidgets('a built-in pack is held, and cannot be removed',
        (tester) async {
      await pumpApp(tester, api: serving([WordPacks.places]));
      await openDownloads(tester);

      expect(find.text('Places'), findsOneWidget);
      expect(find.text('Built in'), findsOneWidget);
      expect(find.text('Remove'), findsNothing);
    });
  });
}
