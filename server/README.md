# Spy — server

A version check that also carries the ad rules, a pack catalogue, the pack
bodies, a counter endpoint, receipts, and one page with the numbers on it.

Still no auth and no rate limiting: everything is either public and identical
for everybody, or keyed by a random number a phone made up about itself. The
admin pages are the exception and they take a token.

**The app must work with this switched off.** Every endpoint here is an
improvement on an app that already plays offline, never a dependency of one. If
you find yourself adding something the phone cannot do without, that is the
bug.

## Running it

```bash
python3 -m venv .venv && .venv/bin/pip install -e ".[dev]"
```

```bash
.venv/bin/python -m uvicorn app.main:app --reload --port 8010
```

Interactive docs at `/docs`. Tests, which are contract tests rather than
coverage — each one pins something a phone would break on:

```bash
.venv/bin/python -m pytest
```

## Checking it works

`tool/smoke.py` walks the same path the app walks - config, catalogue,
download, counters, receipt - and checks the answers rather than just the
status codes. Standard library only, so it runs anywhere Python does:

```sh
.venv/bin/python tool/smoke.py --token YOUR_ADMIN_TOKEN
```

Point it at anything: `--url http://192.168.1.20:8010` from another machine on
the network, or `--url https://api.topazapps.ir` once it is deployed. The pack
download is verified against the published sha256, which is the check that
catches a proxy quietly mangling a response.

## The endpoints

| | |
|---|---|
| `GET /v1/health` | Up, which release, how many packs loaded. |
| `GET /v1/config?build=&platform=&store=&install_id=` | Version check, ad rules and entitlement. The app's first call of every launch. |
| `GET /v1/packs?lang=&build=` | The catalogue. Metadata only, never words. |
| `GET /v1/packs/{id}/{version}` | One pack's words. Immutable, ETagged, cached for a year. |
| `POST /v1/events` | Coarse counters, batched. Returns 204 and nothing else. |
| `POST /v1/purchases/verify` | A store receipt in, an entitlement out. |
| `GET /v1/entitlements?install_id=` | What an install is owed. |
| `GET /admin` | The numbers, as one page. Token required. |
| `GET /admin/summary.json` | The same numbers as JSON. |

`min_supported_build` in `content/config.json` is the kill switch. Bazaar has no
forced updates, so it is the only lever that reaches an old install — it is in
the contract from day one even though it will not be used for a long time.

## Adverts

Every rule lives in `content/config.json` under `ads`, and every one of them
can be changed without shipping an app build:

```json
"ads": {
  "enabled": false,
  "provider": "none",
  "cooldown_minutes": 20,
  "reset_on_restart": true,
  "min_gap_seconds": 90,
  "quiet_rounds": 1,
  "placements": { "home_start": true },
  "zones": { "home_start": "" }
}
```

`enabled: false` is the shipped state. Switch it on by naming a provider the
app carries and filling in a zone id — until both are true the app shows
nothing, which is also what a phone with no network does.

`placements` is a closed set of one. A test asserts it can never grow to
include anything mid-round, because a full-screen advert pauses the app, and a
paused app during a card reveal voids the deal.

`packs_nudge` controls the quiet offer of more word packs on Home: how many
rounds somebody plays first, and how long it stays away once dismissed.

## Money

One product, `spy_ad_free`, sold by whichever store the build came from. The
app hands the receipt to `POST /v1/purchases/verify`; the token is unique
across the table, so a retry is idempotent and a receipt replayed from another
phone is a 409.

**Receipts are not verified against the stores yet.** `app/billing.py` is the
seam and says exactly what each store's API needs — both want OAuth
credentials from a developer console, which is configuration rather than code.
Until then a receipt is recorded as `pending`, and **pending counts as
entitled**. That default survives the real verifiers landing: a store we cannot
reach means pending, never invalid. Showing adverts to somebody who paid costs
a person money and a review; the other mistake costs a fraction of a rial.

## The numbers page

`GET /admin?token=…` renders installs, the advert funnel with its fill rate and
adverts-per-game, event counts, top packs and the last ten receipts. Set
`SPY_ADMIN_TOKEN`; leaving it blank makes the admin routes return 404, which is
the right behaviour on a machine nobody has configured.

Two questions get answered there — is the ad system earning anything, and is it
annoying anybody. `ads_per_game` creeping up means the cooldown is too short.
A low `fill_rate` means the network has no inventory, not that the app is
broken.

## Content

Packs are files in `content/packs/`, one JSON object each, and a pack is
published by editing a file and restarting. That is the whole workflow until
there is a reason for more; `Catalog` in `app/catalog.py` is the seam a database
slots behind when there is.

The packs compiled into the app are seeded from the app's own source so the two
cannot drift:

```bash
python tool/seed_from_app.py
```

Rules that matter:

- **`version` is monotonic and never reused.** The app installs a downloaded
  pack only when its version is higher than what it holds, so a pack still at
  version 1 will never replace the copy inside the binary.
- **Packs are never translated.** A Persian pack is written in Persian, not
  rendered from an English one — the word is the thing being guessed, and a
  translated word is a word nobody says out loud.
- **`min_build`** on a pack hides it from older clients entirely, rather than
  showing them something that fails when tapped.

Each pack is rendered to its final bytes once at startup, and the `sha256` in
the catalogue is the hash of exactly those bytes. The app hashes what it
downloaded and refuses anything that does not match — there is no
canonicalisation contract to get wrong.

## Deploying

`docker compose up -d --build` runs the API behind Caddy, which takes out and
renews TLS on its own. Put the real hostname in `Caddyfile` first, and set
`SPY_ADMIN_TOKEN` and `SPY_DATABASE_URL`.

SQLite is the default and is fine for a long time — WAL is on and the writes
are tiny. Move to Postgres by setting `SPY_DATABASE_URL`; nothing else changes.
Whichever it is, **back it up**: it holds the receipts, and a lost receipt is
somebody who paid and can prove nothing.

Host it inside Iran. Foreign clouds geo-block Iranian addresses, so the app
would simply fail to reach them — and pack bodies should come off a CDN rather
than the origin.

## Logging

One line per request, correlated by a request id that also goes back in
`X-Request-ID`. `SPY_LOG_FORMAT=text` for a readable console, `json` for
anything that ingests logs. Every line carries the caller's build, platform and
store, which is what makes "only build 42 on Myket is failing" answerable
without a database.
