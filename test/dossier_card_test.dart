import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spy/design/theme.dart';
import 'package:spy/l10n/strings.dart';
import 'package:spy/widgets/dossier_card.dart';

/// The secrecy checklist, as tests.
///
/// Does the card survive backgrounding, a screenshot, a thumb sliding off the
/// track, and a screen reader reading ahead? Every one of those is a way a
/// player sees a card that isn't theirs, which is the single failure this app
/// cannot recover from.
void main() {
  const word = 'Lighthouse';
  const wordUpper = 'LIGHTHOUSE';

  Widget harness({
    bool isSpy = false,
    bool spiesSeeCategory = true,
    VoidCallback? onInterrupted,
    Locale locale = const Locale('en'),
  }) {
    return MaterialApp(
      locale: locale,
      supportedLocales: SpyStrings.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        SpyStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: SpyTheme.build(colors: SpyColors.noir, locale: locale),
      home: Scaffold(
        body: SpyDensityScope(
          density: SpyDensity.standard,
          child: DossierCard(
            playerName: 'Sara',
            word: isSpy ? null : word,
            packName: 'Places',
            isSpy: isSpy,
            spiesSeeCategory: spiesSeeCategory,
            caseNumber: 4,
            round: 2,
            position: 3,
            total: 7,
            onInterrupted: onInterrupted ?? () {},
          ),
        ),
      ),
    );
  }

  /// Drives the slider without letting go, the way a thumb does.
  Future<TestGesture> dragTo(WidgetTester tester, double fraction) async {
    final slider = tester.getRect(find.byType(Slider));
    final target = Offset(
      slider.left + slider.width * fraction,
      slider.center.dy,
    );
    final gesture = await tester.startGesture(target);
    await tester.pump();
    return gesture;
  }

  testWidgets('a sealed card has no word in the tree at all', (tester) async {
    await tester.pumpWidget(harness());

    expect(find.text(wordUpper), findsNothing);
    expect(find.text(word), findsNothing);
    expect(find.text('Redacted'), findsOneWidget);
    expect(find.text('Sara'), findsOneWidget);
    expect(find.text('Drag the slider to see the word'), findsOneWidget);
  });

  testWidgets('the word is absent from the semantics tree while sealed',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(harness());

    // A screen reader must not be able to read ahead of the slider.
    expect(
      find.bySemanticsLabel(RegExp(word, caseSensitive: false)),
      findsNothing,
    );
    expect(
      find.bySemanticsLabel(RegExp('Sara.s card, sealed')),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('dragging burns the word through', (tester) async {
    await tester.pumpWidget(harness());

    final gesture = await dragTo(tester, 0.9);
    expect(find.text(wordUpper), findsOneWidget);
    expect(find.text('Let go and it hides'), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('letting go seals it, and the word leaves the tree',
      (tester) async {
    await tester.pumpWidget(harness());

    final gesture = await dragTo(tester, 0.9);
    expect(find.text(wordUpper), findsOneWidget);

    await gesture.up();
    // d-seal is 140 ms; give it a frame past that and nothing may remain.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(find.text(wordUpper), findsNothing);
    expect(find.text('Drag the slider to see the word'), findsOneWidget);
  });

  testWidgets('a thumb sliding off the track still seals the card',
      (tester) async {
    await tester.pumpWidget(harness());

    final gesture = await dragTo(tester, 0.9);
    expect(find.text(wordUpper), findsOneWidget);

    // Off the bottom of the card entirely, then release out there.
    await gesture.moveBy(const Offset(0, 400));
    await tester.pump();
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(find.text(wordUpper), findsNothing);
  });

  testWidgets('going inactive seals the card without voiding the deal',
      (tester) async {
    var interrupted = false;
    await tester.pumpWidget(harness(onInterrupted: () => interrupted = true));

    final gesture = await dragTo(tester, 0.9);
    expect(find.text(wordUpper), findsOneWidget);

    // iOS fires `inactive` for the Control Centre pull-down and the screenshot
    // flash - precisely when a word must not be on screen.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text(wordUpper), findsNothing);
    expect(
      interrupted,
      isFalse,
      reason: 'checking your brightness should not throw the round away',
    );

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('a real backgrounding seals the card and voids the deal',
      (tester) async {
    var interrupted = false;
    await tester.pumpWidget(harness(onInterrupted: () => interrupted = true));

    final gesture = await dragTo(tester, 0.9);
    expect(find.text(wordUpper), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text(wordUpper), findsNothing);
    expect(interrupted, isTrue);

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('the spy card never holds the civilian word', (tester) async {
    await tester.pumpWidget(harness(isSpy: true));

    final gesture = await dragTo(tester, 0.9);

    expect(find.text('YOU ARE THE SPY'), findsOneWidget);
    expect(find.text(wordUpper), findsNothing);
    expect(find.text(word), findsNothing);

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('spies lose the category line when the setting is off',
      (tester) async {
    await tester.pumpWidget(harness(isSpy: true, spiesSeeCategory: false));
    expect(find.textContaining('Places'), findsNothing);

    await tester.pumpWidget(harness(isSpy: true));
    expect(find.textContaining('Places'), findsOneWidget);
  });

  testWidgets('the slider always starts at zero, on every card', (tester) async {
    await tester.pumpWidget(harness());
    expect(tester.widget<Slider>(find.byType(Slider)).value, 0);

    final gesture = await dragTo(tester, 0.9);
    await gesture.up();
    await tester.pumpAndSettle();

    expect(tester.widget<Slider>(find.byType(Slider)).value, 0);
  });

  testWidgets('a Persian card mirrors and never shows an English word',
      (tester) async {
    await tester.pumpWidget(harness(locale: const Locale('fa')));

    final direction = Directionality.of(
      tester.element(find.byType(DossierCard)),
    );
    expect(direction, TextDirection.rtl);
    expect(find.text('سانسور شده'), findsOneWidget);
    expect(find.text('برای دیدن واژه، اهرم را بکش'), findsOneWidget);
  });
}
