"""Counters from the app.

Nothing the phone does waits on this endpoint, and nothing it returns changes
what the phone does. If it disappeared tomorrow the game would be identical -
which is the test every line here has to keep passing.
"""

from __future__ import annotations

import logging

from fastapi import APIRouter, Depends, Response, status
from sqlalchemy.orm import Session

from ..db import get_session, utcnow
from ..models import Event, Install
from ..schemas import EventBatch

log = logging.getLogger("spy.events")

router = APIRouter(prefix="/v1", tags=["telemetry"])

#: Anything not on this list is dropped. A closed set means a future build
#: cannot quietly start reporting something nobody agreed to, and it keeps the
#: admin page's vocabulary fixed.
KNOWN_EVENTS = frozenset({
    "app_open",
    "game_started",
    "round_finished",
    "ad_eligible",
    "ad_requested",
    "ad_shown",
    "ad_failed",
    "ad_suppressed",
    "pack_installed",
    "packs_opened",
    "purchase_started",
    "purchase_completed",
})


def touch_install(session: Session, batch: EventBatch) -> Install:
    """Upsert the install row. First sighting creates it; later ones age it."""
    install = session.get(Install, batch.install_id)
    if install is None:
        install = Install(
            id=batch.install_id,
            platform=batch.platform,
            store=batch.store,
            build=batch.build,
            language=batch.language,
        )
        session.add(install)
    else:
        install.last_seen = utcnow()
        install.store = batch.store
        install.build = batch.build
        install.language = batch.language
    return install


@router.post(
    "/events",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Counters, batched",
)
def post_events(
    batch: EventBatch,
    session: Session = Depends(get_session),
) -> Response:
    install = touch_install(session, batch)

    kept = 0
    for incoming in batch.events:
        if incoming.kind not in KNOWN_EVENTS:
            continue
        session.add(
            Event(
                install_id=install.id,
                kind=incoming.kind,
                at=incoming.at or utcnow(),
                store=batch.store,
                build=batch.build,
                detail=incoming.detail,
            )
        )
        kept += 1

    session.commit()
    log.info(
        "events stored",
        extra={"kept": kept, "dropped": len(batch.events) - kept},
    )
    return Response(status_code=status.HTTP_204_NO_CONTENT)
