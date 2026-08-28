import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'api.dart';

/// Counters, batched and thrown away when they cannot be delivered.
///
/// The whole vocabulary is a handful of event names and an occasional short
/// label - a pack id, an ad zone, a failure reason. There is no field here a
/// player's name could fit in, and no identifier except the random number the
/// phone made up about itself on first run.
///
/// Nothing waits on this class. Every method returns immediately, delivery
/// happens on a timer, and a batch that cannot be sent is dropped rather than
/// retried forever. If the server vanished the game would be identical.
class SpyTelemetry {
  SpyTelemetry({
    required SpyApi api,
    required String installId,
    String language = 'en',
    Duration? flushAfter,
  }) : this._(api, installId, language, flushAfter ?? const Duration(seconds: 20));

  SpyTelemetry._(this._api, this.installId, this.language, this._flushAfter);

  final SpyApi _api;
  final Duration _flushAfter;

  /// Anonymous, and the only identifier there is. Blank switches the whole
  /// thing off - a phone with nowhere to store one is a phone that counts
  /// nothing rather than one that invents a new identity every launch.
  final String installId;

  String language;

  final List<TelemetryEvent> _pending = [];
  Timer? _timer;
  bool _sending = false;

  /// Beyond this the oldest go. A phone that has been offline for a week has
  /// nothing worth catching up on.
  static const _cap = 60;

  bool get enabled => installId.isNotEmpty;

  @visibleForTesting
  List<TelemetryEvent> get pending => List.unmodifiable(_pending);

  void record(String kind, {String? detail}) {
    if (!enabled) return;
    _pending.add(TelemetryEvent(kind, DateTime.now(), detail));
    if (_pending.length > _cap) _pending.removeRange(0, _pending.length - _cap);
    _timer ??= Timer(_flushAfter, () {
      _timer = null;
      unawaited(flush());
    });
  }

  /// Sends what is queued. Safe to call at any time, including on the way to
  /// the background - it takes a copy first, so a slow send cannot lose an
  /// event recorded while it was in flight.
  Future<void> flush() async {
    if (!enabled || _sending || _pending.isEmpty) return;
    _sending = true;
    final batch = List<TelemetryEvent>.from(_pending);
    _pending.clear();
    try {
      await _api.sendEvents(
        installId: installId,
        language: language,
        events: batch,
      );
    } on ApiException {
      // Dropped, not retried. These are counters, and a counter that costs
      // somebody a retry loop on a metered connection is not worth having.
      debugPrint('Spy: ${batch.length} counters dropped');
    } catch (_) {
      // Same.
    } finally {
      _sending = false;
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}

@immutable
class TelemetryEvent {
  const TelemetryEvent(this.kind, this.at, [this.detail]);

  final String kind;
  final DateTime at;
  final String? detail;

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'at': at.toUtc().toIso8601String(),
        if (detail != null) 'detail': detail,
      };
}

/// A random number this phone calls itself.
///
/// Not a device id, not an advertising id, and not derived from anything about
/// the phone or the person holding it - those are all things that follow
/// somebody between apps. This is 32 hex characters from the secure random
/// generator, written once into Spy's own settings file, and it means nothing
/// anywhere else. Clearing the app's data makes a new one, which is exactly
/// the right amount of permanence.
String newInstallId() {
  final random = Random.secure();
  final buffer = StringBuffer();
  for (var i = 0; i < 16; i++) {
    buffer.write(random.nextInt(256).toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}
