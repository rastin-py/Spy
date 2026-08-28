import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/ads.dart';
import 'data/game.dart';
import 'data/pack_store.dart';
import 'data/settings.dart';
import 'data/update_store.dart';
import 'design/theme.dart';
import 'l10n/strings.dart';
import 'screens/home.dart';
import 'services/api.dart';
import 'services/haptics.dart';
import 'services/telemetry.dart';

/// Hands the two stores down the tree. There is no state management package
/// here on purpose: one settings store and one game controller is not an
/// architecture problem.
class SpyScope extends InheritedNotifier<Listenable> {
  SpyScope({
    required this.settings,
    required this.game,
    required this.packs,
    required this.updates,
    required this.ads,
    required this.telemetry,
    required super.child,
    super.key,
  }) : super(notifier: Listenable.merge([settings, game, packs, updates, ads]));

  final SettingsStore settings;
  final GameController game;
  final PackStore packs;
  final UpdateStore updates;
  final AdController ads;
  final SpyTelemetry telemetry;

  static SpyScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SpyScope>()!;

  @override
  bool updateShouldNotify(SpyScope oldWidget) =>
      settings != oldWidget.settings ||
      game != oldWidget.game ||
      packs != oldWidget.packs ||
      updates != oldWidget.updates ||
      ads != oldWidget.ads ||
      super.updateShouldNotify(oldWidget);
}

extension SpyScopeContext on BuildContext {
  SettingsStore get settingsStore => SpyScope.of(this).settings;
  SpySettings get settings => SpyScope.of(this).settings.value;
  GameController get game => SpyScope.of(this).game;
  PackStore get packStore => SpyScope.of(this).packs;

  /// Every pack this phone can deal from - compiled in and downloaded alike.
  /// Nothing that reads this needs to know which is which.
  PackLibrary get library => SpyScope.of(this).packs.library;

  UpdateStore get updates => SpyScope.of(this).updates;
  AdController get ads => SpyScope.of(this).ads;
  SpyTelemetry get telemetry => SpyScope.of(this).telemetry;
}

class SpyApp extends StatefulWidget {
  SpyApp({
    required this.settings,
    required this.game,
    PackStore? packs,
    UpdateStore? updates,
    AdController? ads,
    SpyTelemetry? telemetry,
    super.key,
  })  : packs = packs ?? PackStore(vault: MemoryPackVault(), api: SpyApi()),
        updates = updates ?? UpdateStore(),
        telemetry = telemetry ??
            SpyTelemetry(api: SpyApi(), installId: settings.value.installId),
        ads = ads ??
            AdController(
              settings: settings,
              telemetry: telemetry ??
                  SpyTelemetry(api: SpyApi(), installId: settings.value.installId),
            );

  final SettingsStore settings;
  final GameController game;

  /// Defaulted so a test or a tool can put the app on screen without a
  /// filesystem or a server under it - every one of these degrades to "nothing
  /// downloaded, nothing said, no adverts".
  final PackStore packs;
  final UpdateStore updates;
  final AdController ads;
  final SpyTelemetry telemetry;

  @override
  State<SpyApp> createState() => _SpyAppState();
}

class _SpyAppState extends State<SpyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.settings.addListener(_applySettings);
    _applySettings();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Backgrounding is the last chance to deliver counters: a phone that is
    // put down and never opened again has still played the rounds it played.
    // Nothing waits on this and its failure changes nothing.
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      widget.telemetry.flush();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.settings.removeListener(_applySettings);
    widget.telemetry.dispose();
    super.dispose();
  }

  void _applySettings() {
    SpyHaptics.enabled = widget.settings.value.haptics;
  }

  @override
  Widget build(BuildContext context) {
    return SpyScope(
      settings: widget.settings,
      game: widget.game,
      packs: widget.packs,
      updates: widget.updates,
      ads: widget.ads,
      telemetry: widget.telemetry,
      child: AnimatedBuilder(
        animation: widget.settings,
        builder: (context, _) {
          final settings = widget.settings.value;
          final systemLocale =
              WidgetsBinding.instance.platformDispatcher.locale;
          final locale = switch (settings.language) {
            SpyLanguage.system =>
              systemLocale.languageCode == 'fa' ? const Locale('fa') : const Locale('en'),
            SpyLanguage.en => const Locale('en'),
            SpyLanguage.fa => const Locale('fa'),
          };

          return MaterialApp(
            title: 'Spy',
            debugShowCheckedModeBanner: false,
            locale: locale,
            supportedLocales: SpyStrings.supportedLocales,
            localizationsDelegates: const <LocalizationsDelegate<Object>>[
              SpyStrings.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: SpyTheme.build(colors: SpyColors.daylight, locale: locale),
            darkTheme: SpyTheme.build(colors: SpyColors.noir, locale: locale),
            themeMode: switch (settings.theme) {
              SpyThemeChoice.system => ThemeMode.system,
              SpyThemeChoice.noir => ThemeMode.dark,
              SpyThemeChoice.daylight => ThemeMode.light,
            },
            builder: (context, child) {
              // Text scale is honoured to 200%; past that the layout stops
              // being a layout. The compact breakpoint absorbs the rest.
              final scaler = MediaQuery.textScalerOf(context).clamp(
                minScaleFactor: 1.0,
                maxScaleFactor: 2.0,
              );
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: scaler),
                child: child!,
              );
            },
            // Always Home. The rules are two taps away under the hero and
            // nobody wants a tutorial standing between them and dealing.
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}

/// Portrait, both platforms. A phone that is passed around a table and laid
/// flat should not reflow in mid-air.
///
/// Never awaited by startup: a host that cannot lock its orientation may never
/// answer, and the app is still perfectly playable unlocked.
Future<void> lockOrientation() => SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
