"""A page with the numbers on it.

Not a dashboard. Two questions get answered here - is the ad system earning
anything, and is it annoying anybody - plus a list of receipts for when
somebody emails to say they paid and still see adverts. Anything beyond that
belongs in a query, not in more HTML.

Guarded by `SPY_ADMIN_TOKEN`. Blank means these routes do not exist at all,
which is the right behaviour on a machine nobody has configured.
"""

from __future__ import annotations

import html
from datetime import timedelta

from fastapi import APIRouter, Depends, Header, HTTPException, Query
from fastapi.responses import HTMLResponse
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from ..config import Settings, get_settings
from ..db import get_session, utcnow
from ..models import Event, Install, Purchase

router = APIRouter(prefix="/admin", tags=["admin"], include_in_schema=False)


def require_admin(
    token: str | None = Query(default=None),
    authorization: str | None = Header(default=None),
    settings: Settings = Depends(get_settings),
) -> None:
    if not settings.admin_token:
        # Not "forbidden": on an unconfigured machine these routes should look
        # like they were never deployed.
        raise HTTPException(status_code=404, detail="not found")
    supplied = token
    if authorization and authorization.lower().startswith("bearer "):
        supplied = authorization[7:]
    if supplied != settings.admin_token:
        raise HTTPException(status_code=401, detail="unauthorised")


def summarise(session: Session, days: int = 7) -> dict:
    now = utcnow()
    since = now - timedelta(days=days)
    day_ago = now - timedelta(days=1)

    def count(stmt) -> int:
        return session.scalar(stmt) or 0

    installs_total = count(select(func.count()).select_from(Install))
    installs_24h = count(
        select(func.count()).select_from(Install).where(Install.last_seen >= day_ago)
    )
    installs_week = count(
        select(func.count()).select_from(Install).where(Install.last_seen >= since)
    )
    new_week = count(
        select(func.count()).select_from(Install).where(Install.first_seen >= since)
    )

    by_store = dict(
        session.execute(
            select(Install.store, func.count()).group_by(Install.store)
        ).all()
    )

    events = dict(
        session.execute(
            select(Event.kind, func.count())
            .where(Event.at >= since)
            .group_by(Event.kind)
        ).all()
    )

    purchases_by_state = dict(
        session.execute(
            select(Purchase.state, func.count()).group_by(Purchase.state)
        ).all()
    )

    recent_purchases = session.scalars(
        select(Purchase).order_by(Purchase.created_at.desc()).limit(10)
    ).all()

    packs = session.execute(
        select(Event.detail, func.count())
        .where(Event.kind == "pack_installed", Event.detail.is_not(None))
        .group_by(Event.detail)
        .order_by(func.count().desc())
        .limit(10)
    ).all()

    requested = events.get("ad_requested", 0)
    shown = events.get("ad_shown", 0)
    games = events.get("game_started", 0)

    return {
        "days": days,
        "installs": {
            "total": installs_total,
            "active_24h": installs_24h,
            "active_7d": installs_week,
            "new_7d": new_week,
            "by_store": by_store,
        },
        "events": events,
        "ads": {
            "eligible": events.get("ad_eligible", 0),
            "requested": requested,
            "shown": shown,
            "failed": events.get("ad_failed", 0),
            "suppressed": events.get("ad_suppressed", 0),
            # What share of asks turned into an advert. The number that tells
            # you whether the network has inventory in Iran tonight.
            "fill_rate": round(shown / requested, 3) if requested else None,
            # How often a game start carried an advert. If this creeps up, the
            # cooldown is too short.
            "ads_per_game": round(shown / games, 3) if games else None,
        },
        "purchases": {
            "by_state": purchases_by_state,
            "ad_free_installs": purchases_by_state.get("valid", 0)
            + purchases_by_state.get("pending", 0),
            "recent": [
                {
                    "install": p.install_id[:8],
                    "store": p.store,
                    "state": p.state,
                    "at": p.created_at.isoformat(timespec="minutes"),
                }
                for p in recent_purchases
            ],
        },
        "packs_installed": [{"pack": name, "count": n} for name, n in packs],
    }


@router.get("/summary.json", dependencies=[Depends(require_admin)])
def summary_json(
    days: int = Query(default=7, ge=1, le=90),
    session: Session = Depends(get_session),
) -> dict:
    return summarise(session, days)


_STYLE = """
:root { color-scheme: light dark; --line:#d8d4cc; }
* { box-sizing: border-box; }
body { margin:0; padding:28px 20px 60px; font:14px/1.5 ui-sans-serif,system-ui,sans-serif;
       background:#f2f0ec; color:#1b1b1a; }
main { max-width: 900px; margin: 0 auto; }
h1 { font-size:19px; letter-spacing:.14em; text-transform:uppercase; margin:0 0 4px; }
h2 { font-size:11px; letter-spacing:.16em; text-transform:uppercase; color:#8a857c;
     margin:30px 0 8px; font-weight:700; }
.sub { color:#8a857c; margin:0 0 8px; font-size:12px; }
.cards { display:grid; grid-template-columns:repeat(auto-fit,minmax(150px,1fr)); gap:10px; }
.card { background:#fff; border:1px solid #e3dfd7; border-radius:10px; padding:12px 14px; }
.card b { display:block; font-size:26px; font-weight:700; letter-spacing:-.02em; }
.card span { font-size:11px; letter-spacing:.1em; text-transform:uppercase; color:#8a857c; }
table { width:100%; border-collapse:collapse; background:#fff; border:1px solid #e3dfd7;
        border-radius:10px; overflow:hidden; }
th,td { text-align:left; padding:8px 12px; border-bottom:1px solid #efece6; }
th { font-size:10px; letter-spacing:.12em; text-transform:uppercase; color:#8a857c; }
tr:last-child td { border-bottom:none; }
td.n, th.n { text-align:right; font-variant-numeric:tabular-nums; }
.none { color:#8a857c; font-style:italic; padding:10px 0; }
@media (prefers-color-scheme: dark) {
  body { background:#111213; color:#e9e6e0; }
  .card, table { background:#191a1c; border-color:#2a2c2f; }
  th,td { border-bottom-color:#232527; }
}
"""


def _rows(pairs, label: str) -> str:
    if not pairs:
        return '<p class="none">Nothing yet.</p>'
    body = "".join(
        f"<tr><td>{html.escape(str(k))}</td><td class='n'>{v}</td></tr>"
        for k, v in pairs
    )
    return (
        f"<table><tr><th>{html.escape(label)}</th><th class='n'>Count</th></tr>"
        f"{body}</table>"
    )


@router.get("", response_class=HTMLResponse, dependencies=[Depends(require_admin)])
def dashboard(
    days: int = Query(default=7, ge=1, le=90),
    session: Session = Depends(get_session),
) -> HTMLResponse:
    data = summarise(session, days)
    ads = data["ads"]
    installs = data["installs"]

    def card(value, label: str) -> str:
        shown = "—" if value is None else value
        return f"<div class='card'><b>{shown}</b><span>{html.escape(label)}</span></div>"

    fill = ads["fill_rate"]
    per_game = ads["ads_per_game"]

    purchase_rows = "".join(
        "<tr>"
        f"<td>{html.escape(p['install'])}</td>"
        f"<td>{html.escape(p['store'])}</td>"
        f"<td>{html.escape(p['state'])}</td>"
        f"<td>{html.escape(p['at'])}</td>"
        "</tr>"
        for p in data["purchases"]["recent"]
    ) or "<tr><td colspan='4' class='none'>No receipts yet.</td></tr>"

    page = f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="robots" content="noindex,nofollow">
<title>Spy · numbers</title><style>{_STYLE}</style></head>
<body><main>
  <h1>Spy</h1>
  <p class="sub">Last {days} days. Refresh for current.</p>

  <h2>Installs</h2>
  <div class="cards">
    {card(installs['total'], 'total')}
    {card(installs['active_24h'], 'active 24h')}
    {card(installs['active_7d'], f'active {days}d')}
    {card(installs['new_7d'], f'new {days}d')}
    {card(data['purchases']['ad_free_installs'], 'ad-free')}
  </div>

  <h2>Adverts</h2>
  <div class="cards">
    {card(ads['eligible'], 'eligible')}
    {card(ads['requested'], 'requested')}
    {card(ads['shown'], 'shown')}
    {card(ads['failed'], 'failed')}
    {card(f"{fill:.0%}" if fill is not None else None, 'fill rate')}
    {card(per_game, 'per game')}
  </div>

  <h2>Events</h2>
  {_rows(sorted(data['events'].items()), 'Kind')}

  <h2>Stores</h2>
  {_rows(sorted(installs['by_store'].items()), 'Store')}

  <h2>Packs installed</h2>
  {_rows([(p['pack'], p['count']) for p in data['packs_installed']], 'Pack')}

  <h2>Receipts</h2>
  <table>
    <tr><th>Install</th><th>Store</th><th>State</th><th>When</th></tr>
    {purchase_rows}
  </table>
</main></body></html>"""
    return HTMLResponse(page)
