import 'package:flutter/foundation.dart';

import '../services/api.dart';
import 'remote.dart';

/// What the server said about this build, if it has been asked yet.
///
/// One call, once per launch, in the background. It never gates a frame and it
/// never blocks a deal: a phone that cannot reach the server is a phone that
/// plays exactly as well as one that can, minus the banner.
class UpdateStore extends ChangeNotifier {
  UpdateStore({SpyApi? api, this.installId = '', this.onConfig})
      : _api = api ?? SpyApi();

  final SpyApi _api;

  /// Sent so the answer can say whether this phone has paid.
  final String installId;

  /// Handed every successful answer. This is how the ad rules reach
  /// [AdController] without either of them knowing about the other.
  final Future<void> Function(RemoteConfig)? onConfig;

  RemoteConfig? _config;
  bool _asked = false;

  RemoteConfig? get config => _config;

  /// Something newer is on the store. Only ever a banner and a link - Bazaar
  /// forbids an app installing an update itself, and a group mid-evening is
  /// not going to stop and update anyway.
  bool get updateAvailable => _config?.updateAvailable ?? false;

  /// Newer, and this build is past what the server supports.
  bool get updateUrgent => _config?.updateUrgent ?? false;

  /// The server is having a bad day and has said so. Downloads are pointless
  /// until it passes; everything already on the phone still works.
  bool get maintenance => _config?.maintenance ?? false;

  Future<void> refresh({bool force = false}) async {
    if (_asked && !force) return;
    _asked = true;
    try {
      final config = await _api.config(installId: installId);
      _config = config;
      await onConfig?.call(config);
      notifyListeners();
    } on ApiException {
      // Silent on purpose. Nobody opened this screen and nobody asked; a toast
      // about a version check they did not request is noise.
      _asked = false;
    } catch (_) {
      _asked = false;
    }
  }
}
