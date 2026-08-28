import 'package:flutter/foundation.dart';

/// What this build is, in the three terms the server asks about.
///
/// The build number is the one that matters. A store with no forced updates
/// means the server has to be able to recognise an old client and either work
/// around it or tell the person holding it, so every call carries this.
abstract final class AppInfo {
  static const version = '1.0.0';

  /// Bump on every upload, never reuse. `min_supported_build` on the server is
  /// compared against this number and nothing else.
  static const build = 1;

  /// Which store this binary was published to.
  ///
  /// Set per build: `--dart-define=SPY_STORE=myket`. Bazaar and Myket want
  /// different deep links for the same update and different billing libraries
  /// for the same purchase, and a receipt is only ever valid at the store that
  /// issued it - so this has to be right, and it is set once, at build time.
  static const store = String.fromEnvironment(
    'SPY_STORE',
    defaultValue: 'bazaar',
  );

  /// The one thing there is to buy. One product, one price, forever.
  static const adFreeProduct = 'spy_ad_free';

  static String get platform => switch (defaultTargetPlatform) {
        TargetPlatform.iOS => 'ios',
        _ => 'android',
      };
}
