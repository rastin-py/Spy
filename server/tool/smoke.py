"""Exercise every endpoint against a running server and say what broke.

Standard library only, so it runs anywhere Python does:

    python tool/smoke.py                                  # localhost:8000
    python tool/smoke.py --url http://192.168.1.20:8000   # from another machine
    python tool/smoke.py --url https://api.topazapps.ir --token SECRET

It walks the same path the app walks - config, catalogue, download, counters,
receipt - and checks the answers rather than just the status codes. The pack
download is verified against the sha256 the catalogue published, which is the
one check that would catch a proxy quietly mangling a response.

Nothing here writes to the app. It creates one throwaway install id per run.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import secrets
import sys
import urllib.error
import urllib.parse
import urllib.request

GREEN, RED, DIM, BOLD, OFF = "\033[32m", "\033[31m", "\033[2m", "\033[1m", "\033[0m"

passed = 0
failed = 0


def check(name: str, ok: bool, detail: str = "") -> bool:
    global passed, failed
    if ok:
        passed += 1
        print(f"  {GREEN}pass{OFF}  {name}" + (f"  {DIM}{detail}{OFF}" if detail else ""))
    else:
        failed += 1
        print(f"  {RED}FAIL{OFF}  {name}" + (f"  {detail}" if detail else ""))
    return ok


def call(base: str, path: str, params=None, body=None, headers=None):
    """Returns (status, bytes). Never raises for an HTTP error status."""
    url = base.rstrip("/") + path
    if params:
        url += "?" + urllib.parse.urlencode(params)
    data = json.dumps(body).encode() if body is not None else None
    request = urllib.request.Request(url, data=data, method="POST" if data else "GET")
    request.add_header("Accept", "application/json")
    if data:
        request.add_header("Content-Type", "application/json")
    for key, value in (headers or {}).items():
        request.add_header(key, value)
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            return response.status, response.read()
    except urllib.error.HTTPError as error:
        return error.code, error.read()
    except Exception as error:  # noqa: BLE001 - the point is to report it
        print(f"  {RED}FAIL{OFF}  cannot reach {url}\n        {error}")
        sys.exit(1)


def as_json(raw: bytes):
    try:
        return json.loads(raw)
    except Exception:
        return None


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", default="http://127.0.0.1:8000")
    parser.add_argument("--token", default="", help="SPY_ADMIN_TOKEN, for /admin")
    parser.add_argument("--build", type=int, default=1)
    args = parser.parse_args()

    base = args.url
    install = "smoke" + secrets.token_hex(10)
    print(f"\n{BOLD}Spy API smoke test{OFF}  {DIM}{base}{OFF}")
    print(f"{DIM}install id {install}{OFF}\n")

    # ------------------------------------------------------------- health
    print(f"{BOLD}health{OFF}")
    status, raw = call(base, "/v1/health")
    health = as_json(raw) or {}
    check("the service is up", status == 200 and health.get("ok") is True, f"HTTP {status}")
    check("packs are loaded", health.get("packs", 0) > 0, f"{health.get('packs')} packs")

    # ------------------------------------------------------------- config
    print(f"\n{BOLD}config{OFF}")
    status, raw = call(base, "/v1/config", {"build": args.build, "install_id": install})
    config = as_json(raw) or {}
    check("config answers", status == 200, f"HTTP {status}")
    for field in ("latest_build", "min_supported_build", "update_url", "ads",
                  "packs_nudge", "ad_free"):
        check(f"carries {field}", field in config)

    ads = config.get("ads", {})
    check(
        "adverts only ever on Home",
        set(ads.get("placements", {})) <= {"home_start"},
        str(list(ads.get("placements", {}))),
    )
    print(
        f"  {DIM}ads: enabled={ads.get('enabled')} provider={ads.get('provider')} "
        f"cooldown={ads.get('cooldown_minutes')}m gap={ads.get('min_gap_seconds')}s "
        f"quiet={ads.get('quiet_rounds')} zone={ads.get('zones', {}).get('home_start') or '(unset)'}{OFF}"
    )
    if ads.get("enabled") and not ads.get("zones", {}).get("home_start"):
        print(f"  {RED}note{OFF}  adverts are on but no zone is set - nothing will show")

    # ------------------------------------------------------------- packs
    print(f"\n{BOLD}packs{OFF}")
    for language in ("en", "fa"):
        status, raw = call(base, "/v1/packs", {"lang": language, "build": args.build})
        listing = (as_json(raw) or {}).get("packs", [])
        check(f"{language} catalogue", status == 200 and len(listing) > 0,
              f"{len(listing)} packs")
        check(
            f"{language} catalogue is only {language}",
            all(p["language"] == language for p in listing),
        )

    status, raw = call(base, "/v1/packs", {"lang": "en", "build": args.build})
    first = (as_json(raw) or {}).get("packs", [{}])[0]
    if first:
        status, body = call(base, f"/v1/packs/{first['id']}/{first['version']}")
        digest = hashlib.sha256(body).hexdigest()
        check("a pack downloads", status == 200, f"{first['id']} {len(body)} bytes")
        check("its bytes match the published sha256", digest == first.get("sha256"))
        pack = as_json(body) or {}
        check(
            "its contents match the catalogue",
            pack.get("id") == first["id"]
            and len(pack.get("words", [])) == first.get("word_count"),
            f"{len(pack.get('words', []))} words",
        )
        status, _ = call(base, f"/v1/packs/{first['id']}/9999")
        check("a wrong version is a miss, not the latest pack", status == 404)

    # ------------------------------------------------------------ counters
    print(f"\n{BOLD}counters{OFF}")
    status, _ = call(base, "/v1/events", body={
        "install_id": install,
        "store": "bazaar",
        "build": args.build,
        "language": "fa",
        "events": [
            {"kind": "app_open"},
            {"kind": "game_started"},
            {"kind": "ad_suppressed", "detail": "cooldown"},
            {"kind": "not_a_real_event"},
        ],
    })
    check("a batch is accepted", status == 204, f"HTTP {status}")

    # ------------------------------------------------------------ receipts
    print(f"\n{BOLD}receipts{OFF}")
    receipt = {
        "install_id": install,
        "store": "bazaar",
        "product_id": "spy_ad_free",
        "token": "smoke-" + secrets.token_hex(8),
    }
    status, raw = call(base, "/v1/purchases/verify", body=receipt)
    entitlement = as_json(raw) or {}
    check("a receipt is taken", status == 200, f"HTTP {status}")
    check("and grants ad-free", entitlement.get("ad_free") is True,
          f"state={entitlement.get('state')}")

    status, raw = call(base, "/v1/purchases/verify", body=receipt)
    check("handing the same one in twice changes nothing",
          status == 200 and (as_json(raw) or {}) == entitlement)

    stolen = dict(receipt, install_id="smoke" + secrets.token_hex(10))
    status, _ = call(base, "/v1/purchases/verify", body=stolen)
    check("it cannot be replayed from another phone", status == 409, f"HTTP {status}")

    status, raw = call(base, "/v1/config", {"build": args.build, "install_id": install})
    after = as_json(raw) or {}
    check("config now says ad-free", after.get("ad_free") is True)
    check("and switches adverts off for them",
          after.get("ads", {}).get("enabled") is False)

    status, _ = call(base, "/v1/purchases/verify",
                     body=dict(receipt, store="playstore", token="x" + secrets.token_hex(6)))
    check("an unknown store is refused", status == 400, f"HTTP {status}")

    # --------------------------------------------------------------- admin
    print(f"\n{BOLD}admin{OFF}")
    if args.token:
        status, raw = call(base, "/admin/summary.json", {"token": args.token})
        summary = as_json(raw) or {}
        check("the numbers page answers", status == 200, f"HTTP {status}")
        if status == 200:
            installs = summary.get("installs", {})
            print(f"  {DIM}installs={installs.get('total')} "
                  f"ad-free={summary.get('purchases', {}).get('ad_free_installs')} "
                  f"events={sum(summary.get('events', {}).values())}{OFF}")
        status, _ = call(base, "/admin/summary.json", {"token": "wrong"})
        check("a wrong token gets nothing", status == 401, f"HTTP {status}")
    else:
        print(f"  {DIM}skipped - pass --token to check /admin{OFF}")

    print(f"\n{BOLD}{passed} passed, {failed} failed{OFF}\n")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
