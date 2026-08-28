import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/widgets.dart';

/// The app's entire user-facing vocabulary.
///
/// No string ships from inside a widget; it gets a key here first, which is
/// what makes the tone reviewable in one place and the Persian build a
/// one-file job. Plurals are real branches, never concatenation - Persian has
/// different plural rules and English has "1 spy / 2 spies".
///
/// Voice: a dealer at a card table who has seen it all and is not impressed.
/// Sentence case, second person, present tense, zero exclamation marks.
abstract class SpyStrings {
  const SpyStrings();

  static const supportedLocales = [Locale('en'), Locale('fa')];

  static const delegate = _SpyStringsDelegate();

  static SpyStrings of(BuildContext context) =>
      Localizations.of<SpyStrings>(context, SpyStrings)!;

  static SpyStrings forLocale(Locale locale) =>
      locale.languageCode == 'fa' ? const SpyStringsFa() : const SpyStringsEn();

  String get localeName;

  /// The name of this language, in this language. Persian is فارسی, not a flag.
  String get languageName;

  // ------------------------------------------------------------------ numerals
  /// Latin in English, Persian-Indic in Persian, everywhere including the
  /// clock. A locale property, not a setting.
  String number(int value);

  /// `mm:ss`, two-digit minutes so the digit count never changes under a
  /// player's eye.
  String clockTime(Duration d) {
    final total = d.isNegative ? 0 : d.inSeconds;
    final m = (total ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '${digits(m)}:${digits(s)}';
  }

  /// `m:ss` - the shorter form used in prose and the round-length control.
  String roundLength(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '${number(m)}:${digits(s)}';
  }

  String digits(String latin);

  // ---------------------------------------------------------------------- app
  String get appName;
  String get appTagline;

  // --------------------------------------------------------------------- home
  String get homeSameAgain;
  String get homeChangeSetup;
  String get homeSetUpGame;
  String get homeHowToPlay;
  String homeLastSetup(int players, int spies, String length);
  String homeLastPlayed(String when);
  String get homeWhenTonight;
  String get homeWhenYesterday;
  String get homeWhenAWhileAgo;
  String get homeRoundInProgress;
  String homeRoundInProgressBody(String left);
  String get homeAbout;

  // ------------------------------------------------------------------- set up
  String get setupTitle;
  String get setupPlayers;
  String get setupSpies;
  String get setupLength;
  String get setupPacks;
  String setupPacksOff(int n);
  String get setupDeal;
  String setupSpyCeiling(int players, int max);
  String setupSuggested(int players, String length);
  String get setupNoPacks;
  String get setupNoPacksBody;
  String get setupPlayerNames;
  String get setupPlayerNamesHelp;

  // ------------------------------------------------------------------ handoff
  String get handoffPassTo;
  String handoffIAm(String name);
  String handoffPosition(int n, int total);
  String handoffCase(int caseNumber, int round);

  // --------------------------------------------------------------------- card
  String get cardTitle;
  String cardCategory(String pack);
  String get cardDrag;
  String get cardDragLive;
  String get cardRedacted;
  String get cardSpy;
  String get cardDontSayIt;
  String get cardGotIt;
  String cardPosition(int n, int total);

  // -------------------------------------------------------------------- clock
  String clockTitle(int round);
  String clockMeta(int players, int spies, String pack);
  String get clockPause;
  String get clockResume;
  String get clockCallIt;
  String get clockTimeUp;
  String get clockSilent;
  String get clockSilentBody;

  // ------------------------------------------------------------------ verdict
  String get verdictTitle;
  String get verdictTheWordWas;
  String verdictTheSpiesWere(int n);
  String get verdictBackToStart;

  // ------------------------------------------------------------------ abandon
  String get abandonAction;
  String get abandonTitle;
  String abandonBody(int n);
  String get abandonKeep;
  String get abandonConfirm;

  // ----------------------------------------------------------------- settings
  String get settingsTitle;
  String get settingsGroupSound;
  String get settingsClockSound;
  String get settingsClockSoundHelp;
  String get settingsBell;
  String get settingsBellHelp;
  String get settingsHaptics;
  String get settingsHapticsHelp;
  String get settingsGroupGame;
  String get settingsSpyCategory;
  String get settingsSpyCategoryHelp;
  String get settingsNoRepeat;
  String get settingsNoRepeatHelp;
  String get settingsGroupLook;
  String get settingsTheme;
  String get settingsThemeSystem;
  String get settingsThemeNoir;
  String get settingsThemeDaylight;
  String get settingsLanguage;
  String get settingsAwake;
  String get settingsAwakeHelp;
  String get settingsReset;
  String get settingsResetDone;
  String get settingsResetConfirmTitle;
  String get settingsResetConfirmBody;

  // -------------------------------------------------------------------- packs
  String get packsTitle;
  String packsCount(int n);
  String get packsMixNote;
  String get packsOn;
  String get packsOff;
  String packsTurnOn(String pack);
  String get packsExhausted;
  String packsExhaustedBody(String pack, int total, int used);
  String packsReshuffle(String pack);
  String packsPlayedTonight(int n);

  // ---------------------------------------------------------------- downloads
  String get downloadsTitle;
  String get downloadsConnect;
  String downloadsConnectBody(int built);
  String get downloadsGet;
  String get downloadsUpdate;
  String get downloadsRemove;
  String get downloadsBuiltIn;
  String get downloadsGetting;
  String get downloadsLooking;
  String get downloadsNothingNew;
  String get downloadsNothingNewBody;
  String downloadsSize(int bytes);
  String downloadsReady(String pack);
  String downloadsRemoveConfirm(String pack);
  String get downloadsRemoveConfirmBody;
  String get downloadsNoStorage;

  /// One plain sentence per way a call can fail, and one action beside it.
  /// "Error 500" is not something anybody can act on.
  String get netOffline;
  String get netOfflineBody;
  String get netTimeout;
  String get netTimeoutBody;
  String get netServer;
  String get netServerBody;
  String get netCorrupt;
  String get netCorruptBody;

  // -------------------------------------------------------------- packs nudge
  String get nudgeTitle;
  String get nudgeBody;
  String get nudgeNotNow;

  // ------------------------------------------------------------------- update
  String get updateTitle;
  String updateBody(String version);
  String updateUrgentBody(String version);
  String get updateAction;

  // -------------------------------------------------------------- how to play
  String get howTitle;
  String get howStep1;
  String get howStep2;
  String get howStep3;
  String get howSpy;
  String get howSpyLabel;

  // -------------------------------------------------------------------- about
  String get aboutTitle;
  String get aboutNetwork;
  String get aboutNetworkBody;
  String aboutVersion(String version);
  String aboutBuild(int build);

  // -------------------------------------------------------------- interrupted
  String get interruptedTitle;
  String interruptedBody(String name);
  String get interruptedDealAgain;

  // ------------------------------------------------------------------ storage
  String get storageTitle;
  String get storageBody;

  // ------------------------------------------------------------------- common
  String get commonTryAgain;
  String get commonDone;
  String get commonBack;
  String get commonGotIt;
  String get commonUndo;
  String get commonCancel;

  // -------------------------------------------------------------------- queue
  String get queueSeen;
  String get queueNow;
  String get queueWaiting;
  String get queueTitle;

  // ------------------------------------------------------------------ players
  String playerDefault(int n);

  // --------------------------------------------------------------------- a11y
  String a11yCardSealed(String name, String pack);
  String get a11yRevealSlider;
  String a11yRevealValue(int n);
  String a11yCardOpen(String word);
  String a11yCardOpenSpy(String pack);
  String a11yTimeLeft(String left);
  String get a11ySettings;
  String get a11yBack;
}

class SpyStringsEn extends SpyStrings {
  const SpyStringsEn();

  @override
  String get localeName => 'en';
  @override
  String get languageName => 'English';

  @override
  String number(int value) => value.toString();
  @override
  String digits(String latin) => latin;

  @override
  String get appName => 'Spy';
  @override
  String get appTagline => 'One word · one liar';

  @override
  String get homeSameAgain => 'Same again';
  @override
  String get homeChangeSetup => 'Change setup';
  @override
  String get homeSetUpGame => 'Set up a game';
  @override
  String get homeHowToPlay => 'How to play';
  @override
  String homeLastSetup(int players, int spies, String length) =>
      '${number(players)} players · ${spies == 1 ? '1 spy' : '${number(spies)} spies'} · $length';
  @override
  String homeLastPlayed(String when) => 'last played $when';
  @override
  String get homeWhenTonight => 'tonight';
  @override
  String get homeWhenYesterday => 'yesterday';
  @override
  String get homeWhenAWhileAgo => 'a while ago';
  @override
  String get homeRoundInProgress => 'Round in progress';
  @override
  String homeRoundInProgressBody(String left) => '$left left.';
  @override
  String get homeAbout => 'About';

  @override
  String get setupTitle => 'Set up';
  @override
  String get setupPlayers => 'Players';
  @override
  String get setupSpies => 'Spies';
  @override
  String get setupLength => 'Round length';
  @override
  String get setupPacks => 'Word packs';
  @override
  String setupPacksOff(int n) => '+${number(n)} off';
  @override
  String get setupDeal => 'Deal the cards';
  @override
  String setupSpyCeiling(int players, int max) =>
      'With ${number(players)} players, ${max == 1 ? '1 spy is' : '${number(max)} spies are'} the most the game survives';
  @override
  String setupSuggested(int players, String length) =>
      'Suggested for ${number(players)} players: $length';
  @override
  String get setupNoPacks => 'Every pack is switched off';
  @override
  String get setupNoPacksBody => 'Turn at least one back on to deal a round.';
  @override
  String get setupPlayerNames => 'Names';
  @override
  String get setupPlayerNamesHelp => 'Optional. Blank ones stay numbered.';

  @override
  String get handoffPassTo => 'Pass the phone to';
  @override
  String handoffIAm(String name) => "I'm $name";
  @override
  String handoffPosition(int n, int total) =>
      'Player ${number(n)} of ${number(total)}';
  @override
  String handoffCase(int caseNumber, int round) =>
      'Case ${caseNumber.toString().padLeft(2, '0')} · Round ${number(round)}';

  @override
  String get cardTitle => 'Your card';
  @override
  String cardCategory(String pack) => 'Category · $pack';
  @override
  String get cardDrag => 'Drag the slider to see the word';
  @override
  String get cardDragLive => 'Let go and it hides';
  @override
  String get cardRedacted => 'Redacted';
  @override
  String get cardSpy => 'You are the spy';
  @override
  String get cardDontSayIt => "Don't say it out loud";
  @override
  String get cardGotIt => "I've got it";
  @override
  String cardPosition(int n, int total) => '${number(n)} / ${number(total)}';

  @override
  String clockTitle(int round) => 'Round ${number(round)}';
  @override
  String clockMeta(int players, int spies, String pack) =>
      '${number(players)} players · ${spies == 1 ? '1 spy' : '${number(spies)} spies'} · $pack';
  @override
  String get clockPause => 'Pause';
  @override
  String get clockResume => 'Paused — tap to continue';
  @override
  String get clockCallIt => 'Call it — reveal';
  @override
  String get clockTimeUp => 'Time';
  @override
  String get clockSilent => 'Your phone is on silent';
  @override
  String get clockSilentBody => 'The clock sound is on, but nobody will hear it.';

  @override
  String get verdictTitle => 'Verdict';
  @override
  String get verdictTheWordWas => 'The word was';
  @override
  String verdictTheSpiesWere(int n) => n == 1 ? 'The spy was' : 'The spies were';
  @override
  String get verdictBackToStart => 'Back to the start';

  @override
  String get abandonAction => 'Abandon round';
  @override
  String get abandonTitle => 'Abandon the round?';
  @override
  String abandonBody(int n) =>
      '${n == 1 ? '1 player has' : '${number(n)} players have'} already seen their cards. '
      'Abandoning throws the word away — nobody finds out who the spy was.';
  @override
  String get abandonKeep => 'Keep playing';
  @override
  String get abandonConfirm => 'Abandon';

  @override
  String get settingsTitle => 'Settings';
  @override
  String get settingsGroupSound => 'Sound & feel';
  @override
  String get settingsClockSound => 'Clock sound';
  @override
  String get settingsClockSoundHelp => 'A wall clock ticks while the round runs';
  @override
  String get settingsBell => 'Bell at zero';
  @override
  String get settingsBellHelp => 'One strike when time runs out';
  @override
  String get settingsHaptics => 'Haptics';
  @override
  String get settingsHapticsHelp => 'A pulse on reveal and in the last ten seconds';
  @override
  String get settingsGroupGame => 'The game';
  @override
  String get settingsSpyCategory => 'Spies see the category';
  @override
  String get settingsSpyCategoryHelp => 'Off makes the game much harder for spies';
  @override
  String get settingsNoRepeat => "Don't repeat words";
  @override
  String get settingsNoRepeatHelp => 'Until a pack runs out';
  @override
  String get settingsGroupLook => 'Appearance';
  @override
  String get settingsTheme => 'Theme';
  @override
  String get settingsThemeSystem => 'Follow the system';
  @override
  String get settingsThemeNoir => 'Noir';
  @override
  String get settingsThemeDaylight => 'Daylight';
  @override
  String get settingsLanguage => 'Language';
  @override
  String get settingsAwake => 'Keep the screen awake';
  @override
  String get settingsAwakeHelp => 'Only while the clock is running';
  @override
  String get settingsReset => 'Reset all settings';
  @override
  String get settingsResetDone => 'Settings reset';
  @override
  String get settingsResetConfirmTitle => 'Reset all settings?';
  @override
  String get settingsResetConfirmBody =>
      'Everything goes back to the defaults, including your packs and the last setup.';

  @override
  String get packsTitle => 'Word packs';
  @override
  String packsCount(int n) => n == 1 ? '1 word' : '${number(n)} words';
  @override
  String get packsMixNote => 'Packs mix. With two on, every round draws from both.';
  @override
  String get packsOn => 'ON';
  @override
  String get packsOff => 'OFF';
  @override
  String packsTurnOn(String pack) => 'Turn on $pack';
  @override
  String get packsExhausted => 'Not enough words';
  @override
  String packsExhaustedBody(String pack, int total, int used) =>
      '$pack has ${packsCount(total)} and you’ve played ${number(used)}. '
      'Reshuffle to start reusing, or switch on another pack.';
  @override
  String packsReshuffle(String pack) => 'Reshuffle $pack';
  @override
  String packsPlayedTonight(int n) =>
      n == 1 ? '1 played tonight' : '${number(n)} played tonight';

  @override
  String get downloadsTitle => 'Download packs';
  @override
  String get downloadsConnect =>
      'Connect to the network to download the latest packs';
  @override
  String downloadsConnectBody(int built) =>
      'Spy plays offline with the ${number(built)} packs it was built with. '
      'There are more on the server, in this language.';
  @override
  String get downloadsGet => 'Get';
  @override
  String get downloadsUpdate => 'Update';
  @override
  String get downloadsRemove => 'Remove';
  @override
  String get downloadsBuiltIn => 'Built in';
  @override
  String get downloadsGetting => 'Getting';
  @override
  String get downloadsLooking => 'Asking what is on offer';
  @override
  String get downloadsNothingNew => 'You have all of them';
  @override
  String get downloadsNothingNewBody =>
      'Every pack on the server is already on this phone. Look again another '
      'evening.';
  @override
  String downloadsSize(int bytes) => '${number((bytes / 1024).ceil())} KB';
  @override
  String downloadsReady(String pack) => '$pack is ready to play';
  @override
  String downloadsRemoveConfirm(String pack) => 'Remove $pack?';
  @override
  String get downloadsRemoveConfirmBody =>
      'The words come off the phone. You can download the pack again whenever '
      'you like.';
  @override
  String get downloadsNoStorage =>
      'This phone has nowhere to keep a downloaded pack, so one would not '
      'survive the evening.';

  @override
  String get netOffline => 'No network';
  @override
  String get netOfflineBody =>
      'Spy could not reach the server. Everything already on the phone still '
      'plays.';
  @override
  String get netTimeout => 'The server is slow to answer';
  @override
  String get netTimeoutBody => 'It gave up waiting. Try again in a moment.';
  @override
  String get netServer => 'The server is having a bad day';
  @override
  String get netServerBody =>
      'That one is ours to fix, not yours. Try again later.';
  @override
  String get netCorrupt => 'That pack arrived damaged';
  @override
  String get netCorruptBody =>
      'What came down the wire did not match what was promised, so nothing was '
      'saved. Try again.';

  @override
  String get nudgeTitle => 'There are more word packs than these';
  @override
  String get nudgeBody =>
      'New packs land on the server between builds. Connect to the network '
      'once and they are yours offline for good.';
  @override
  String get nudgeNotNow => 'Not now';

  @override
  String get updateTitle => 'There is a newer Spy';
  @override
  String updateBody(String version) =>
      'Version $version is on the store. This one keeps working.';
  @override
  String updateUrgentBody(String version) =>
      'Version $version is on the store, and this build is old enough that '
      'packs may stop arriving. The game itself keeps working.';
  @override
  String get updateAction => 'Open the store';

  @override
  String get howTitle => 'How to play';
  @override
  String get howStep1 =>
      'Everyone sees the same secret word. Everyone except the spies.';
  @override
  String get howStep2 =>
      'Take turns asking each other questions about the word. Answer well enough '
      'to prove you know it — badly enough that a spy can’t learn it.';
  @override
  String get howStep3 =>
      'When the clock runs out, argue, then vote out loud. Spy doesn’t take '
      'the vote — you do.';
  @override
  String get howSpy =>
      'You get the category and nothing else. Bluff. If you’re never named, '
      'you win — and if you can name the word, you win bigger.';
  @override
  String get howSpyLabel => 'Spy';

  @override
  String get aboutTitle => 'About';
  @override
  String get aboutNetwork => 'Spy goes online for packs, and nothing else';
  @override
  String get aboutNetworkBody =>
      'No accounts, no analytics, no tracking. Player names, your settings and '
      'the words you have played stay in one file on this phone. Downloading a '
      'pack asks the server for a list and a file, and that is the whole '
      'conversation. Every round can be played with the network off.';
  @override
  String aboutVersion(String version) => 'Version $version';
  @override
  String aboutBuild(int build) => 'Build ${number(build)}';

  @override
  String get interruptedTitle => 'The round was interrupted';
  @override
  String interruptedBody(String name) =>
      'A call came in while $name was holding the phone. Their card was sealed '
      'and is not recoverable — deal again to keep the game clean.';
  @override
  String get interruptedDealAgain => 'Deal again';

  @override
  String get storageTitle => 'Spy couldn’t save your settings';
  @override
  String get storageBody =>
      'The phone reported no free storage. Your choices will hold for this '
      'session but won’t survive a restart.';

  @override
  String get commonTryAgain => 'Try again';
  @override
  String get commonDone => 'Done';
  @override
  String get commonBack => 'Back';
  @override
  String get commonGotIt => 'Got it';
  @override
  String get commonUndo => 'Undo';
  @override
  String get commonCancel => 'Cancel';

  @override
  String get queueSeen => 'Seen';
  @override
  String get queueNow => 'Holding the phone now';
  @override
  String get queueWaiting => 'Waiting';
  @override
  String get queueTitle => 'Dealing';

  @override
  String playerDefault(int n) => 'Player ${number(n)}';

  @override
  String a11yCardSealed(String name, String pack) =>
      '$name’s card, sealed. Category: $pack. Drag the reveal slider to see your word.';
  @override
  String get a11yRevealSlider => 'Reveal your word';
  @override
  String a11yRevealValue(int n) => '${number(n)} percent revealed';
  @override
  String a11yCardOpen(String word) => 'Your word is $word. Don’t say it out loud.';
  @override
  String a11yCardOpenSpy(String pack) => 'You are the spy. The category is $pack.';
  @override
  String a11yTimeLeft(String left) => '$left left in the round';
  @override
  String get a11ySettings => 'Settings';
  @override
  String get a11yBack => 'Back';
}

class SpyStringsFa extends SpyStrings {
  const SpyStringsFa();

  @override
  String get localeName => 'fa';
  @override
  String get languageName => 'فارسی';

  static const _persianDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];

  @override
  String number(int value) => digits(value.toString());

  @override
  String digits(String latin) => latin.replaceAllMapped(
      RegExp(r'[0-9]'), (m) => _persianDigits[int.parse(m[0]!)]);

  @override
  String get appName => 'جاسوس';
  @override
  String get appTagline => 'یک واژه · یک دروغ‌گو';

  @override
  String get homeSameAgain => 'همان دوباره';
  @override
  String get homeChangeSetup => 'تغییر چیدمان';
  @override
  String get homeSetUpGame => 'یک بازی بچین';
  @override
  String get homeHowToPlay => 'چطور بازی کنیم';
  @override
  String homeLastSetup(int players, int spies, String length) =>
      '${number(players)} بازیکن · ${number(spies)} جاسوس · $length';
  @override
  String homeLastPlayed(String when) => 'آخرین بازی $when';
  @override
  String get homeWhenTonight => 'امشب';
  @override
  String get homeWhenYesterday => 'دیروز';
  @override
  String get homeWhenAWhileAgo => 'مدتی پیش';
  @override
  String get homeRoundInProgress => 'دوری در جریان است';
  @override
  String homeRoundInProgressBody(String left) => '$left باقی مانده.';
  @override
  String get homeAbout => 'درباره';

  @override
  String get setupTitle => 'چیدمان';
  @override
  String get setupPlayers => 'بازیکنان';
  @override
  String get setupSpies => 'جاسوس‌ها';
  @override
  String get setupLength => 'طول دور';
  @override
  String get setupPacks => 'بسته‌های واژه';
  @override
  String setupPacksOff(int n) => '${number(n)} خاموش';
  @override
  String get setupDeal => 'کارت‌ها را پخش کن';
  @override
  String setupSpyCeiling(int players, int max) =>
      'با ${number(players)} بازیکن، ${number(max)} جاسوس بیشترین چیزی است که بازی تحمل می‌کند';
  @override
  String setupSuggested(int players, String length) =>
      'پیشنهاد برای ${number(players)} بازیکن: $length';
  @override
  String get setupNoPacks => 'همهٔ بسته‌ها خاموش‌اند';
  @override
  String get setupNoPacksBody => 'دست‌کم یکی را روشن کن تا دور پخش شود.';
  @override
  String get setupPlayerNames => 'نام‌ها';
  @override
  String get setupPlayerNamesHelp => 'اختیاری. خالی‌ها شماره‌دار می‌مانند.';

  @override
  String get handoffPassTo => 'گوشی را بده به';
  @override
  String handoffIAm(String name) => '$name هستم';
  @override
  String handoffPosition(int n, int total) =>
      'بازیکن ${number(n)} از ${number(total)}';
  @override
  String handoffCase(int caseNumber, int round) =>
      'پرونده ${digits(caseNumber.toString().padLeft(2, '0'))} · دور ${number(round)}';

  @override
  String get cardTitle => 'کارت تو';
  @override
  String cardCategory(String pack) => 'دسته · $pack';
  @override
  String get cardDrag => 'برای دیدن واژه، اهرم را بکش';
  @override
  String get cardDragLive => 'رها کنی پنهان می‌شود';
  @override
  String get cardRedacted => 'سانسور شده';
  @override
  String get cardSpy => 'تو جاسوسی';
  @override
  String get cardDontSayIt => 'بلند نگو';
  @override
  String get cardGotIt => 'گرفتم';
  @override
  String cardPosition(int n, int total) => '${number(n)} / ${number(total)}';

  @override
  String clockTitle(int round) => 'دور ${number(round)}';
  @override
  String clockMeta(int players, int spies, String pack) =>
      '${number(players)} بازیکن · ${number(spies)} جاسوس · $pack';
  @override
  String get clockPause => 'مکث';
  @override
  String get clockResume => 'متوقف — برای ادامه بزن';
  @override
  String get clockCallIt => 'تمامش کن — رو کن';
  @override
  String get clockTimeUp => 'وقت';
  @override
  String get clockSilent => 'گوشی‌ات بی‌صداست';
  @override
  String get clockSilentBody => 'صدای ساعت روشن است، اما کسی نمی‌شنود.';

  @override
  String get verdictTitle => 'حکم';
  @override
  String get verdictTheWordWas => 'واژه این بود';
  @override
  String verdictTheSpiesWere(int n) => n == 1 ? 'جاسوس این بود' : 'جاسوس‌ها این‌ها بودند';
  @override
  String get verdictBackToStart => 'برگرد به ابتدا';

  @override
  String get abandonAction => 'رها کردن دور';
  @override
  String get abandonTitle => 'دور رها شود؟';
  @override
  String abandonBody(int n) =>
      '${number(n)} بازیکن کارتشان را دیده‌اند. رها کردن واژه را دور می‌ریزد — '
      'کسی نمی‌فهمد جاسوس که بود.';
  @override
  String get abandonKeep => 'ادامه بده';
  @override
  String get abandonConfirm => 'رها کن';

  @override
  String get settingsTitle => 'تنظیمات';
  @override
  String get settingsGroupSound => 'صدا و حس';
  @override
  String get settingsClockSound => 'صدای ساعت';
  @override
  String get settingsClockSoundHelp => 'ساعت دیواری در طول دور تیک‌تاک می‌کند';
  @override
  String get settingsBell => 'زنگ در صفر';
  @override
  String get settingsBellHelp => 'یک ضربه وقتی زمان تمام می‌شود';
  @override
  String get settingsHaptics => 'لرزش';
  @override
  String get settingsHapticsHelp => 'یک تپش هنگام رو شدن و در ده ثانیهٔ آخر';
  @override
  String get settingsGroupGame => 'بازی';
  @override
  String get settingsSpyCategory => 'جاسوس‌ها دسته را می‌بینند';
  @override
  String get settingsSpyCategoryHelp => 'خاموش، بازی را برای جاسوس‌ها بسیار سخت‌تر می‌کند';
  @override
  String get settingsNoRepeat => 'واژه‌ها تکرار نشوند';
  @override
  String get settingsNoRepeatHelp => 'تا وقتی بسته تمام شود';
  @override
  String get settingsGroupLook => 'ظاهر';
  @override
  String get settingsTheme => 'پوسته';
  @override
  String get settingsThemeSystem => 'پیروی از سیستم';
  @override
  String get settingsThemeNoir => 'نوآر';
  @override
  String get settingsThemeDaylight => 'روشنا';
  @override
  String get settingsLanguage => 'زبان';
  @override
  String get settingsAwake => 'صفحه روشن بماند';
  @override
  String get settingsAwakeHelp => 'فقط تا وقتی ساعت کار می‌کند';
  @override
  String get settingsReset => 'بازنشانی همهٔ تنظیمات';
  @override
  String get settingsResetDone => 'تنظیمات بازنشانی شد';
  @override
  String get settingsResetConfirmTitle => 'همهٔ تنظیمات بازنشانی شود؟';
  @override
  String get settingsResetConfirmBody =>
      'همه‌چیز به پیش‌فرض برمی‌گردد، از جمله بسته‌ها و آخرین چیدمان.';

  @override
  String get packsTitle => 'بسته‌های واژه';
  @override
  String packsCount(int n) => '${number(n)} واژه';
  @override
  String get packsMixNote => 'بسته‌ها با هم مخلوط می‌شوند. با دو بستهٔ روشن، هر دور از هر دو می‌کشد.';
  @override
  String get packsOn => 'روشن';
  @override
  String get packsOff => 'خاموش';
  @override
  String packsTurnOn(String pack) => '$pack را روشن کن';
  @override
  String get packsExhausted => 'واژه کم است';
  @override
  String packsExhaustedBody(String pack, int total, int used) =>
      '$pack ${packsCount(total)} دارد و ${number(used)} تا بازی شده. '
      'برای استفادهٔ دوباره بُر بزن، یا بستهٔ دیگری را روشن کن.';
  @override
  String packsReshuffle(String pack) => '$pack را بُر بزن';
  @override
  String packsPlayedTonight(int n) => '${number(n)} بازی‌شده امشب';

  @override
  String get downloadsTitle => 'دانلود بسته‌ها';
  @override
  String get downloadsConnect =>
      'برای دانلود آخرین بسته‌ها به شبکه وصل شو';
  @override
  String downloadsConnectBody(int built) =>
      'جاسوس با ${number(built)} بستهٔ درون‌برنامه بدون اینترنت بازی '
      'می‌شود. روی سرور بسته‌های بیشتری به همین زبان هست.';
  @override
  String get downloadsGet => 'بگیر';
  @override
  String get downloadsUpdate => 'به‌روزرسانی';
  @override
  String get downloadsRemove => 'حذف';
  @override
  String get downloadsBuiltIn => 'درون‌برنامه';
  @override
  String get downloadsGetting => 'در حال دریافت';
  @override
  String get downloadsLooking => 'دارد می‌پرسد چه چیزی هست';
  @override
  String get downloadsNothingNew => 'همه‌شان را داری';
  @override
  String get downloadsNothingNewBody =>
      'هر بسته‌ای که روی سرور هست همین حالا روی این گوشی است. '
      'یک شب دیگر دوباره سر بزن.';
  @override
  String downloadsSize(int bytes) => '${number((bytes / 1024).ceil())} کیلوبایت';
  @override
  String downloadsReady(String pack) => '$pack آمادهٔ بازی است';
  @override
  String downloadsRemoveConfirm(String pack) => '$pack حذف شود؟';
  @override
  String get downloadsRemoveConfirmBody =>
      'واژه‌ها از گوشی پاک می‌شوند. هر وقت خواستی دوباره دانلودش کن.';
  @override
  String get downloadsNoStorage =>
      'این گوشی جایی برای نگه داشتن بستهٔ دانلودشده ندارد، پس دانلود تا شب بعد نمی‌ماند.';

  @override
  String get netOffline => 'شبکه‌ای نیست';
  @override
  String get netOfflineBody =>
      'جاسوس به سرور نرسید. هر چه روی گوشی هست همچنان بازی می‌شود.';
  @override
  String get netTimeout => 'سرور دیر جواب می‌دهد';
  @override
  String get netTimeoutBody => 'از انتظار درآمد. کمی بعد دوباره تلاش کن.';
  @override
  String get netServer => 'سرور حالش خوب نیست';
  @override
  String get netServerBody => 'این یکی مشکل ماست، نه تو. بعداً دوباره تلاش کن.';
  @override
  String get netCorrupt => 'آن بسته خراب رسید';
  @override
  String get netCorruptBody =>
      'چیزی که رسید با چیزی که قرار بود بیاید یکی نبود، پس چیزی ذخیره نشد. '
      'دوباره تلاش کن.';

  @override
  String get nudgeTitle => 'بسته‌های واژهٔ بیشتری هم هست';
  @override
  String get nudgeBody =>
      'بین نسخه‌ها بسته‌های تازه روی سرور می‌آید. یک بار به شبکه وصل شو تا '
      'برای همیشه بدون اینترنت داشته باشی‌شان.';
  @override
  String get nudgeNotNow => 'الان نه';

  @override
  String get updateTitle => 'جاسوس تازه‌تری هست';
  @override
  String updateBody(String version) =>
      'نسخهٔ ${digits(version)} روی فروشگاه است. همین نسخه هم کار می‌کند.';
  @override
  String updateUrgentBody(String version) =>
      'نسخهٔ ${digits(version)} روی فروشگاه است و این نسخه آن‌قدر قدیمی هست که '
      'ممکن است بسته‌ها دیگر نرسند. خودِ بازی کار می‌کند.';
  @override
  String get updateAction => 'فروشگاه را باز کن';

  @override
  String get howTitle => 'چطور بازی کنیم';
  @override
  String get howStep1 => 'همه یک واژهٔ مشترک می‌بینند. همه جز جاسوس‌ها.';
  @override
  String get howStep2 =>
      'به نوبت از هم دربارهٔ واژه بپرسید. آن‌قدر خوب جواب بده که ثابت شود می‌دانی — '
      'و آن‌قدر بد که جاسوس یاد نگیرد.';
  @override
  String get howStep3 =>
      'وقتی ساعت تمام شد، بحث کنید و بلند رأی بدهید. جاسوس رأی نمی‌گیرد — شما می‌گیرید.';
  @override
  String get howSpy =>
      'تو فقط دسته را داری و بس. بلوف بزن. اگر نامت برده نشود، می‌بری — '
      'و اگر واژه را حدس بزنی، بیشتر می‌بری.';
  @override
  String get howSpyLabel => 'جاسوس';

  @override
  String get aboutTitle => 'درباره';
  @override
  String get aboutNetwork => 'جاسوس فقط برای بسته‌ها به شبکه می‌رود';
  @override
  String get aboutNetworkBody =>
      'نه حساب کاربری، نه آمارگیری، نه ردیابی. نام بازیکن‌ها، تنظیمات و '
      'واژه‌هایی که بازی کرده‌ای در یک فایل روی همین گوشی می‌ماند. دانلود یک '
      'بسته یعنی یک فهرست و یک فایل از سرور، و گفت‌وگو همین‌قدر است. هر دور را '
      'می‌شود با شبکهٔ خاموش بازی کرد.';
  @override
  String aboutVersion(String version) => 'نسخهٔ ${digits(version)}';
  @override
  String aboutBuild(int build) => 'ساخت ${number(build)}';

  @override
  String get interruptedTitle => 'دور قطع شد';
  @override
  String interruptedBody(String name) =>
      'وقتی گوشی دست $name بود تماسی آمد. کارتش مهر و موم شد و برگشتنی نیست — '
      'برای تمیز ماندن بازی دوباره پخش کن.';
  @override
  String get interruptedDealAgain => 'دوباره پخش کن';

  @override
  String get storageTitle => 'جاسوس نتوانست تنظیماتت را ذخیره کند';
  @override
  String get storageBody =>
      'گوشی گزارش داد که فضای خالی ندارد. انتخاب‌هایت در همین نشست می‌مانند اما '
      'با راه‌اندازی دوباره از بین می‌روند.';

  @override
  String get commonTryAgain => 'دوباره تلاش کن';
  @override
  String get commonDone => 'تمام';
  @override
  String get commonBack => 'بازگشت';
  @override
  String get commonGotIt => 'گرفتم';
  @override
  String get commonUndo => 'برگردان';
  @override
  String get commonCancel => 'بی‌خیال';

  @override
  String get queueSeen => 'دیده';
  @override
  String get queueNow => 'الان گوشی دستش است';
  @override
  String get queueWaiting => 'در انتظار';
  @override
  String get queueTitle => 'پخش کارت‌ها';

  @override
  String playerDefault(int n) => 'بازیکن ${number(n)}';

  @override
  String a11yCardSealed(String name, String pack) =>
      'کارت $name، مهر و موم. دسته: $pack. برای دیدن واژه‌ات اهرم را بکش.';
  @override
  String get a11yRevealSlider => 'واژه‌ات را رو کن';
  @override
  String a11yRevealValue(int n) => '${number(n)} درصد رو شده';
  @override
  String a11yCardOpen(String word) => 'واژهٔ تو $word است. بلند نگو.';
  @override
  String a11yCardOpenSpy(String pack) => 'تو جاسوسی. دسته $pack است.';
  @override
  String a11yTimeLeft(String left) => '$left از دور مانده';
  @override
  String get a11ySettings => 'تنظیمات';
  @override
  String get a11yBack => 'بازگشت';
}

class _SpyStringsDelegate extends LocalizationsDelegate<SpyStrings> {
  const _SpyStringsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'en' || locale.languageCode == 'fa';

  // Synchronous on purpose: an async load costs a blank first frame, and the
  // first frame here is Home, which is meant to be one tap from dealing.
  @override
  Future<SpyStrings> load(Locale locale) =>
      SynchronousFuture(SpyStrings.forLocale(locale));

  @override
  bool shouldReload(_SpyStringsDelegate old) => false;
}
