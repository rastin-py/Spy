# Spy

One word. One liar. A pass-the-phone social deduction game for 3–12 people in
one room: everyone gets the same secret word except the spies, who get only the
category. The phone deals the cards and keeps the time; the accusations happen
out loud, across the table.

Android and iOS, portrait only. English and فارسی. Noir and Daylight, both
first-class. Built against `DESIGN_SYSTEM.md` v1.0.

Every round is playable with the network off. The server in `server/` only ever
adds to that: more word packs, and a note when there is a newer build on the
store.

## Running it

```bash
flutter run
```

Tests, including the secrecy checklist and the measured contrast ratios:

```bash
flutter test
```

## Layout

```
lib/
  design/     tokens.g.dart (generated) · theme · textures · icons
  l10n/       the whole string inventory, en + fa
  data/       word packs · the pack library · settings · the dealer and the clock
  services/   the one platform channel, the one API client
  widgets/    the component library, dossier card first
  screens/    home · setup · handoff · reveal · timer · verdict · packs · support
tool/         the three generators
server/       FastAPI: the catalogue and the version check
```

### Building for a store

```bash
flutter build apk --release --split-per-abi --dart-define=SPY_API=https://api.example.ir --dart-define=SPY_STORE=bazaar
```

`SPY_STORE` is `bazaar` or `myket`. It picks the update deep link and, once
billing lands, which store a receipt is checked against — a receipt is only
ever valid at the store that issued it, so this has to be right. Without
`SPY_API` the app runs on its built-in packs, shows no adverts and says nothing
about updates.

`--split-per-abi` takes the download from 50 MB to 16 MB. Data is expensive in
Iran and the size is on the listing page.

Signing reads `android/key.properties` (gitignored — see `key.properties.example`).
Without it, release builds fall back to the debug key so `flutter run --release`
still works.

Third-party keys live in `android/keys.properties` (also gitignored — see
`keys.properties.example`). A missing key leaves that feature switched off
rather than breaking the build: with no Tapsell key the SDK stays inert and
every ad request comes back empty, which is a working app.

The application id is **`ir.topazapps.spy`** and is fixed forever — it is the
app's identity on the store, in the update deep link, and on every receipt.

### Tokens are the API

`tokens.json` is the single source. Everything else is generated:

```bash
dart run tool/gen_tokens.dart   # -> lib/design/tokens.g.dart
python tool/gen_icons.py        # -> every launcher icon, from the mark
python tool/gen_audio.py        # -> assets/audio/tick.wav, bell.wav
```

Never hand-edit a generated file. A new value is a token proposal, not a local
constant — `test/design_system_test.dart` fails the build if `tokens.g.dart`
drifts from `tokens.json`, if a contrast pair drops below its floor, or if a
string picks up an exclamation mark.

Widgets read `context.spy` (semantic aliases) and `context.type`. They never
import `SpyPrimitives` directly.

### The signature component

`lib/widgets/dossier_card.dart` and `lib/widgets/reveal_slider.dart`. Every
word lives in a black redaction slab at opacity 0; dragging the slider burns it
through 1:1 with no easing, and the thumb springs back to zero the instant it is
released. The asymmetry is the security model:

- The word widget is **conditionally built** above 0, never `Opacity(0)` — an
  invisible word is still in the semantics tree and still in a screenshot.
- One `WidgetsBindingObserver` seals on `inactive`, `paused` and `hidden`
  alike. iOS fires `inactive` for the Control Centre pull-down and the
  screenshot flash. A real backgrounding also voids the whole deal.
- Switch access, screen readers and keyboards keep their value until focus
  leaves the card — arrow keys have no "release". That is the one place the
  secrecy rule bends, and it is deliberate.

Anything touching this card runs the secrecy checklist in
`test/dossier_card_test.dart`: backgrounding, screenshots, a thumb sliding off
the track, and a screen reader reading ahead.

## The Android build

Three things here are not stock Flutter, and all three are load-bearing.

**Maven mirrors.** `dl.google.com` answers 404 for every artifact from this
network, which for months made any third-party Android plugin unbuildable —
they pin their own AGP versions and none of those pins resolved.
`android/build.gradle.kts` and `settings.gradle.kts` put a reachable mirror of
Google's Maven ahead of `google()`, which fixed the whole class of problem.
Tapsell's own Maven and JitPack are added scoped by group, so nothing else is
ever fetched from them.

**Plugin `compileSdk` is raised.** Plugins pin whatever was current when they
were published; `sdkmanager` cannot download platform SDKs here for the same
reason as above. Every Android module is compiled against the platform the app
uses. This is the usual Flutter workaround and is safe.

**`tapsell_mediation` needs two overrides.** Its Flutter module declares the
namespace `ir.tapsell.mediation`, which is also the namespace of Tapsell's own
native library, and AGP 8+ refuses to merge two modules that share one.
Renaming it alone is not enough — the legacy `package` attribute in its
manifest then disagrees. So the module gets a new namespace *and* our copy of
its manifest (`android/tapsell/AndroidManifest.xml`). Present in 1.3.0 and
still in 1.4.0-alpha03; when a release drops the attribute, delete both.

Kotlin incremental compilation is off (`android/gradle.properties`), which is
**a Windows workaround and nothing more**: Kotlin cannot close its caches for
the `tapsell_mediation` module under a path containing a space and a dot. Full
compilation of one small plugin costs seconds. Delete the line on macOS or
Linux — it buys nothing there.

## Testing before anything reaches a store

Nothing here needs a Bazaar account, a domain or a certificate.

**1. Run the server.** Leave it running in its own terminal.

```sh
cd server
SPY_ADMIN_TOKEN=dev-token .venv/bin/python -m uvicorn app.main:app --host 0.0.0.0 --port 8010
```

`--host 0.0.0.0` matters: neither a phone nor the emulator can reach a server
bound to localhost.

Port 8010 rather than the usual 8000 because 8000 is the port every other dev
server on the machine also wants, and the app says nothing when it reaches the
wrong one - `UpdateStore.refresh` swallows a bad answer exactly as it is meant
to. If nothing seems to arrive, check the port is actually yours:

```sh
lsof -nP -iTCP:8010 -sTCP:LISTEN
```

**2. Check every endpoint.** In a second terminal:

```sh
cd server
.venv/bin/python tool/smoke.py --token dev-token
```

**3a. Run it on the emulator.** The emulator reaches the host machine at the
fixed address `10.0.2.2` — never `localhost`, which inside the emulator means
the emulator itself:

```sh
flutter run --dart-define=SPY_API=http://10.0.2.2:8010 --dart-define=SPY_STORE=bazaar
```

**3b. Run it on a real phone.** USB debugging on, phone plugged in. Tunnel the
port down the cable rather than going over the network:

```sh
adb reverse tcp:8010 tcp:8010
flutter run --dart-define=SPY_API=http://localhost:8010 --dart-define=SPY_STORE=bazaar
```

`adb reverse` makes the phone's own `localhost:8010` come out of the laptop's
8010. No LAN address to look up, nothing to change when the laptop moves to
another network, and nothing to open in a firewall. Re-run it after unplugging
the phone - the tunnel does not survive a disconnect, and the symptom is a
silent no-op. `adb reverse --list` shows whether it is up.

Over Wi-Fi instead, if the cable is not an option: get the laptop's LAN address
with `ipconfig getifaddr en0` and build against `http://<that-address>:8010`.
Both machines have to be on the same network, and macOS will ask once for
permission to accept incoming connections.

Debug builds carry `usesCleartextTraffic` so plain HTTP works on the local
network (`android/app/src/debug/AndroidManifest.xml`); the release APK does
not, and never talks anything but HTTPS. So test against a local server with
the debug variant — everything except signing behaves the same. To exercise a
`--release` build on the bench it needs an HTTPS server, or the local server
reached through a tunnel.

**4. Watch it happen.** The server logs one line per request with the caller's
build and store, and `/admin?token=dev-token` shows installs, the advert funnel
and the receipts.

### Exercising the parts that are hard to reach

Edit `server/content/config.json` and restart — the app picks changes up on its
next launch.

| To see | Set |
|---|---|
| The update banner | `latest_build` above the app's `AppInfo.build` |
| The "packs" nudge on Home | `packs_nudge.after_rounds` to 0 |
| Adverts at all | `ads.enabled` true, `provider` `tapsell`, and a real zone id |
| An advert every game | `cooldown_minutes` 0, `min_gap_seconds` 0, `quiet_rounds` 0 |
| The maintenance state | `maintenance` true |

The one thing that cannot be faked locally is an advert actually appearing:
that needs a Tapsell key in `android/keys.properties` and a zone id in the
config. Without them `TapsellNetwork` asks and gets nothing, which is the same
path a real empty-inventory night takes — worth seeing, since it is the common
case.

## Adverts

One placement, and it is the only one there will be: **pressing the button on
Home that starts a game.** Never mid-round, never on the card, never on the
clock. That is not taste, it is correctness — a full-screen advert launches its
own activity, which pauses Flutter, which is exactly what `DossierCard` treats
as somebody walking off with the phone. It seals the card and voids the deal.
An advert during a reveal would not be annoying, it would destroy the round.

`AdGate` in `lib/data/ads.dart` is the whole policy as one pure function, and
`test/ads_test.dart` is the file to read before changing any of it. The rules:

| | |
|---|---|
| Mid-game | Refused before anything else is considered. |
| Paid | Never, and remembered offline. |
| First rounds | Quiet until somebody has actually played (`quiet_rounds`). |
| Cooldown | 20 minutes, cleared by relaunching the app. |
| Floor | 90 seconds that a relaunch cannot get under, so closing and reopening is not a way to see an advert every ten seconds. |
| No network | No adverts at all. |

Every number above comes from the server and can be changed without shipping a
build. The defaults compiled into the app match, except `enabled`, which is
false — adverts are something the network switches on, never something the app
decides on its own.

An advert nobody actually saw does not start a cooldown, and a network that
hangs never holds up a game: `AdController` has a hard budget and the tap
continues without one.

**Tapsell is wired up.** `TapsellNetwork` in `lib/services/ad_network.dart`
is the only code allowed to put something full-screen on the display. Two rules
hold it together:

- **Only ever show what is already on the phone.** `show` never requests
  inline. If nothing is preloaded it says so immediately and the game starts.
  Requesting at the moment of the tap means either a stall or an advert that
  lands seconds later, over a deal that has already begun.
- **The timeout covers getting on screen, not watching.** Once an advert is
  displayed the wait is unbounded — cutting it short would start the game
  behind a full-screen advert.

`tapsell_mediation` was chosen over `tapsell_plus`: the latter is 18 months
stale and depends on `google_mobile_ads`, which is both unusable for an Iranian
developer and an AGP pin that will not resolve. The mediation adapters
(AppLovin, ironSource, Chartboost…) are separate opt-in packages; none are
installed, so Spy serves Tapsell's own inventory only.

The app key is a manifest placeholder filled from `android/keys.properties`.
Blank is safe.

## Five decisions worth knowing about

**No third-party plugins.** Persistence, audio, the wakelock, `FLAG_SECURE`,
the iOS snapshot cover and the store link all run over one `MethodChannel`
(`spy/platform`), implemented in `android/…/MainActivity.kt` and
`ios/Runner/SecureScreen.swift`. Owning ~170 lines of platform code is cheaper
than five plugins and their transitive build graphs, and it means the tick can
sit in the ambient audio session exactly as the design system specifies. The
network is `dart:io` in-process, so it adds no native code either; `crypto` is
the one package, pure Dart, and it is there to hash a downloaded pack.

**Downloaded packs are additive, and verified.** The packs compiled into the
binary are never removed and never re-fetched — a phone in aeroplane mode plays
exactly as well as one online. A downloaded pack joins the library as an equal
and only replaces a built-in one at a higher version. Nothing is written until
the bytes match the sha256 the catalogue published, so a mangled download leaves
the previous pack exactly where it was. See `lib/data/pack_store.dart` and
`test/packs_test.dart`.

**Player names are never uppercased.** §3 of the design system lists "Title
(player name)" as caps, but the case rule directly under it and the data
formatting table both say names are shown as typed. The rules win: `SpyType`
applies uppercase by style for the wordmark, screen titles, section labels,
large primary buttons and the secret word — and never to a name, including on
the verdict stamp.

**Every card is framed identically.** The spy's card used to carry a crimson
edge. Colour is still never the only channel — the word bay says `SPY` and the
spy's haptic is the heavier one — but an edge is visible from across the table,
before the slider has moved, and the whole point of the card is that it gives
nothing away to anybody but the person holding it. Crimson stays on the verdict
stamp, the spy chip and the spy count, where the round is already over or the
information is already public.

**The queue is the seating order.** Players are dealt 1..N in the order their
names were entered, every round, every seed — `deal()` shuffles nothing. The
phone goes round a table, and a queue that jumps about is a queue somebody gets
missed out of. The randomness lives entirely in which seats are spies.

## What leaves the phone

- `/v1/config` once per launch — build, platform, store and the install id, so
  the server can answer with the ad rules, whether there is a newer version,
  and whether this phone has paid.
- `/v1/packs` and one pack body, only when somebody opens **Download packs**.
- `/v1/events` — coarse counters, batched, dropped when they cannot be
  delivered. Rounds started, adverts asked for and shown, packs installed.
- `/v1/purchases/verify` — a store receipt, when somebody buys their way out of
  adverts.

The one identifier is `installId`: 32 hex characters from the secure random
generator, made up on first run and stored in Spy's own settings file. Not a
device id, not an advertising id, not derived from anything about the phone or
the person holding it. It means nothing outside Spy and clearing the app's data
makes a new one.

No accounts, no names, no email, nothing typed and no word anybody played.
`test/ads_test.dart` and `server/tests/test_ads.py` both assert this, the
latter by checking no column exists that a person could fit in.

The About screen says all this in plain language; `lib/screens/about.dart` is
the place to keep it honest if it ever changes.

Updating is a link, never an install: Bazaar forbids an app installing a build
itself, and the permission it would need is one a party game has no business
holding.

## Setting up a new development machine

The repository is machine-independent - no tracked file names a path outside
it - but four things live outside git and have to be arranged by hand.

**1. The two mirror environment variables.** The easiest thing in this whole
project to forget, and the failure looks like a network fault rather than a
missing setting. `pubspec.lock` records its hosts, so a machine without these
argues with the lock file:

```sh
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
```

Put them in `~/.zshrc`, not in a single shell.

**2. The Android SDK.** `sdkmanager` fetches from `dl.google.com`, which is
unreachable here (see below), so expect the first-run SDK download to be the
one genuinely awkward step - either use a VPN for it, or pull the packages
from a mirror such as `mirrors.cloud.tencent.com/AndroidSDK/` and unzip them
into the SDK by hand. Needed: platform-tools, build-tools, and the platform
matching `flutter.compileSdkVersion`. Android Studio also supplies the JDK that
Gradle and `keytool` should both use.

**3. The secrets git does not carry**, all correctly gitignored:
`android/spy-release.jks`, `android/key.properties`, `android/keys.properties`.
Move them over an encrypted channel, never email or chat. The keystore is the
irreplaceable one - see `android/key.properties.example`.

**4. The server virtualenv.** `server/.venv` holds platform-specific binaries.
Recreate it rather than copying it.

`server/*.db` is ignored too, so a new machine starts with an empty database.
That is fine; it holds only development rows.

## Known environment limits

- This network gets a 404 from `dl.google.com` for every Maven artifact. The
  fix is the Aliyun mirrors prepended in `android/build.gradle.kts` and
  `android/settings.gradle.kts`, which is what made Tapsell - and any future
  third-party SDK - installable at all. They cover Maven only: the Android SDK
  itself still comes from Google, which is why setting up a machine is harder
  than building on one.
- `lint { checkReleaseBuilds = false }` in `android/app/build.gradle.kts` skips
  the one release task that still needed a download. Correctness is covered by
  `flutter analyze` plus the test suite.
- `kotlin.incremental=false` in `android/gradle.properties` is a **Windows-only**
  workaround for a file-locking failure in the `tapsell_mediation` module.
  Delete it on macOS or Linux; it only makes builds slower there.

## Not built yet

- **Store billing.** `spy_ad_free` is a product the server knows about and can
  grant, and the app has a place to send a receipt. What is missing is the
  purchase flow itself, and the server-side verifiers in `server/app/billing.py`.

  `flutter_poolakey` is **not** the way in: it is twelve months stale, from an
  unverified uploader, and its build script calls `jcenter()`, which Gradle 9
  removed — nothing outside the package can patch that. The plan instead is to
  bind Bazaar's Poolakey *Android* library directly in `MainActivity.kt` over
  the platform channel the app already owns. That matches how everything else
  native works here, and it means the payment path is code we control rather
  than an unmaintained wrapper.
- The ongoing notification and the local-notification bell scheduled at
  `endsAt`. Both need a notifications plugin, which cannot build here. The
  in-process bell and the on-screen clock work; a round that expires while the
  app is backgrounded still lands on the verdict, because the clock is derived
  from the wall clock rather than a counter.

Everything else in the design system's screen list is built, including the
unglamorous states: no packs switched on, a pack exhausted, a round interrupted
by a call, a settings write that failed, and a phone on silent with the clock
sound on.
