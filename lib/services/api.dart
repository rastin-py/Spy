import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../data/app_info.dart';
import '../data/remote.dart';
import '../data/word_packs.dart';
import 'telemetry.dart' show TelemetryEvent;

/// Why a call did not produce an answer.
///
/// One value per thing a person could reasonably be told, and no more - the
/// screen turns exactly these into one plain sentence and one action. "Error
/// 500" is not a sentence anybody can act on.
enum ApiFailure {
  /// No route to the server at all: aeroplane mode, no signal, no wifi.
  offline,

  /// Reachable but not answering in time.
  timeout,

  /// Answered, badly. Ours to fix, not the caller's.
  server,

  /// Answered with something that is not the shape we agreed on.
  malformed,

  /// The bytes arrived and did not match the hash the catalogue published.
  corrupt,
}

class ApiException implements Exception {
  const ApiException(this.failure, [this.detail]);

  final ApiFailure failure;
  final String? detail;

  @override
  String toString() => 'ApiException(${failure.name}${detail == null ? '' : ': $detail'})';
}

@immutable
class ApiResponse {
  const ApiResponse(this.status, this.bytes);

  final int status;
  final Uint8List bytes;
}

/// Swappable so tests never open a socket.
///
/// [body] is null for a GET and the encoded JSON for a POST. One function for
/// both, because two would be two things to fake.
typedef SpyFetch = Future<ApiResponse> Function(Uri uri, {String? body});

/// Spy's one server.
///
/// Deliberately built on `dart:io` rather than an HTTP package: the whole
/// surface is three GETs, and the app's no-native-plugins property is worth
/// more than the convenience. Nothing here ever blocks a screen - every caller
/// treats a failure as "carry on with what is on the phone".
class SpyApi {
  SpyApi({
    String? baseUrl,
    SpyFetch? fetch,
    this.timeout = const Duration(seconds: 10),
  })  : base = Uri.parse(baseUrl ?? defaultBaseUrl),
        _fetch = fetch ?? _httpFetch;

  /// Set at build time: `flutter build apk --dart-define=SPY_API=https://…`.
  /// Baked in rather than configurable at runtime, because a party game with a
  /// user-editable server address is a party game that can be pointed at
  /// somebody else's word list.
  static const defaultBaseUrl = String.fromEnvironment(
    'SPY_API',
    defaultValue: 'https://api.example.ir',
  );

  final Uri base;
  final Duration timeout;
  final SpyFetch _fetch;

  // ------------------------------------------------------------------- calls

  /// Version check, ad rules and entitlement, in one call.
  ///
  /// The first call of every launch and the only one that happens without
  /// somebody asking for it. [installId] is what makes the answer say whether
  /// this phone has paid; without it the reply is the public one.
  Future<RemoteConfig> config({String? installId}) async {
    final json = await _json(
      _url('v1/config', {
        'build': '${AppInfo.build}',
        'platform': AppInfo.platform,
        'store': AppInfo.store,
        if (installId != null && installId.isNotEmpty) 'install_id': installId,
      }),
    );
    final config = RemoteConfig.tryFrom(json);
    if (config == null) throw const ApiException(ApiFailure.malformed, 'config');
    return config;
  }

  /// What is on offer in this language. Metadata only.
  Future<List<RemotePack>> catalogue({required String language}) async {
    final json = await _json(
      _url('v1/packs', {'lang': language, 'build': '${AppInfo.build}'}),
    );
    final list = json['packs'];
    if (list is! List) throw const ApiException(ApiFailure.malformed, 'packs');
    // One bad entry drops out; the rest of the catalogue still shows.
    return [
      for (final entry in list) ?RemotePack.tryFrom(entry),
    ];
  }

  /// The words, verified against the hash the catalogue promised.
  ///
  /// Verification is not about a hostile network - it could rewrite the
  /// manifest too. It is about the transparent proxies and captive portals
  /// that quietly mangle a response, because a truncated pack that still
  /// parses would silently become the game's word list.
  Future<WordPack> download(RemotePack pack) async {
    final response = await _get(_packUrl(pack));
    if (response.status != 200) {
      throw ApiException(ApiFailure.server, 'pack ${response.status}');
    }
    if (sha256.convert(response.bytes).toString() != pack.sha256) {
      throw const ApiException(ApiFailure.corrupt, 'hash mismatch');
    }

    final decoded = _decode(response.bytes);
    final word = WordPack.tryFrom(decoded);
    // The catalogue and the body have to agree, or the app would install
    // something under a name and version it does not actually have.
    if (word == null || word.id != pack.id || word.version != pack.version) {
      throw const ApiException(ApiFailure.corrupt, 'body does not match catalogue');
    }
    if (word.words.isEmpty) {
      throw const ApiException(ApiFailure.corrupt, 'empty pack');
    }
    return word;
  }

  /// Counters. Nothing waits on this and nothing reads its answer.
  Future<void> sendEvents({
    required String installId,
    required String language,
    required List<TelemetryEvent> events,
  }) async {
    if (events.isEmpty) return;
    final response = await _post(_url('v1/events', const {}), {
      'install_id': installId,
      'platform': AppInfo.platform,
      'store': AppInfo.store,
      'build': AppInfo.build,
      'language': language,
      'events': [for (final event in events) event.toJson()],
    });
    if (response.status >= 400) {
      throw ApiException(ApiFailure.server, '${response.status}');
    }
  }

  /// Hands a store receipt in and gets back what this install is owed.
  ///
  /// A receipt the server cannot check yet still comes back entitled: the
  /// person has paid, and our verifier having a bad afternoon is not their
  /// problem.
  Future<bool> verifyPurchase({
    required String installId,
    required String token,
    String productId = AppInfo.adFreeProduct,
  }) async {
    final response = await _post(_url('v1/purchases/verify', const {}), {
      'install_id': installId,
      'store': AppInfo.store,
      'product_id': productId,
      'token': token,
    });
    if (response.status == 409) {
      // The receipt belongs to another install. Not an error to retry.
      return false;
    }
    if (response.status >= 400) {
      throw ApiException(ApiFailure.server, '${response.status}');
    }
    final decoded = _decode(response.bytes);
    return decoded is Map && decoded['ad_free'] == true;
  }

  // ------------------------------------------------------------------ plumbing

  Uri _url(String path, Map<String, String> query) =>
      base.resolve(path).replace(queryParameters: query);

  /// A pack's URL comes from the server, so it is pinned to the server.
  ///
  /// Following an arbitrary absolute URL out of a manifest would let whoever
  /// serves the manifest aim the downloader anywhere; taking only the path
  /// keeps the download on the host this build was compiled against.
  Uri _packUrl(RemotePack pack) {
    final target = Uri.tryParse(pack.url);
    if (target == null) return base.resolve('v1/packs/${pack.id}/${pack.version}');
    return base.replace(path: target.path, query: target.query.isEmpty ? null : target.query);
  }

  Future<ApiResponse> _post(Uri uri, Map<String, dynamic> body) =>
      _send(uri, body: jsonEncode(body));

  Future<Map<String, dynamic>> _json(Uri uri) async {
    final response = await _get(uri);
    if (response.status != 200) {
      throw ApiException(ApiFailure.server, '${response.status}');
    }
    final decoded = _decode(response.bytes);
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException(ApiFailure.malformed, 'not an object');
    }
    return decoded;
  }

  Object? _decode(Uint8List bytes) {
    try {
      return jsonDecode(utf8.decode(bytes));
    } catch (error) {
      throw ApiException(ApiFailure.malformed, '$error');
    }
  }

  Future<ApiResponse> _get(Uri uri) => _send(uri);

  Future<ApiResponse> _send(Uri uri, {String? body}) async {
    try {
      return await _fetch(uri, body: body).timeout(timeout);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException(ApiFailure.timeout);
    } on SocketException catch (error) {
      throw ApiException(ApiFailure.offline, error.message);
    } on HttpException catch (error) {
      throw ApiException(ApiFailure.offline, error.message);
    } catch (error) {
      throw ApiException(ApiFailure.server, '$error');
    }
  }

  static Future<ApiResponse> _httpFetch(Uri uri, {String? body}) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8)
      // Nothing here is authenticated and nothing is personal, so there is
      // nothing worth keeping between launches.
      ..userAgent = 'Spy/${AppInfo.version} (${AppInfo.build}; ${AppInfo.store})';
    try {
      final request =
          body == null ? await client.getUrl(uri) : await client.postUrl(uri);
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(body);
      }
      final response = await request.close();
      final bytes = await consolidateHttpClientResponseBytes(response);
      return ApiResponse(response.statusCode, bytes);
    } finally {
      client.close(force: true);
    }
  }
}
