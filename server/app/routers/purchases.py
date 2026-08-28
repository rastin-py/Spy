"""Receipts in, entitlements out."""

from __future__ import annotations

import logging

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.orm import Session

from .. import billing
from ..config import Settings, get_settings
from ..db import get_session, utcnow
from ..models import Event, Install, Purchase
from ..schemas import Entitlement, PurchaseIn

log = logging.getLogger("spy.purchases")

router = APIRouter(prefix="/v1", tags=["purchases"])


def entitlement_for(session: Session, install_id: str) -> Entitlement:
    """What this install is owed.

    `pending` counts. A receipt we have not managed to check yet belongs to
    somebody who has already paid, and the cost of being wrong the other way is
    a fraction of a rial.
    """
    rows = session.scalars(
        select(Purchase)
        .where(Purchase.install_id == install_id)
        .order_by(Purchase.created_at.desc())
    ).all()

    for state in ("valid", "pending"):
        for purchase in rows:
            if purchase.state == state:
                return Entitlement(
                    ad_free=True,
                    state=state,
                    checked_at=purchase.checked_at,
                )
    return Entitlement(ad_free=False, state="none")


@router.post(
    "/purchases/verify",
    response_model=Entitlement,
    summary="Hand in a store receipt",
)
def verify(
    body: PurchaseIn,
    session: Session = Depends(get_session),
    settings: Settings = Depends(get_settings),
) -> Entitlement:
    if body.store not in settings.known_stores:
        raise HTTPException(status_code=400, detail="unknown store")
    if body.product_id != settings.ad_free_product_id:
        raise HTTPException(status_code=400, detail="unknown product")

    # A token is unique across the whole table: the same receipt handed in from
    # a second phone must not mint a second entitlement. It is also how a
    # retry after a dropped connection stays idempotent.
    existing = session.scalar(select(Purchase).where(Purchase.token == body.token))
    if existing is not None:
        if existing.install_id != body.install_id:
            log.warning(
                "receipt replayed from another install",
                extra={"store": body.store, "product": body.product_id},
            )
            raise HTTPException(status_code=409, detail="receipt already used")
        return entitlement_for(session, body.install_id)

    if session.get(Install, body.install_id) is None:
        session.add(
            Install(id=body.install_id, store=body.store, platform="android")
        )

    verdict = billing.verifier_for(body.store).verify(body.product_id, body.token)
    purchase = Purchase(
        install_id=body.install_id,
        store=body.store,
        product_id=body.product_id,
        token=body.token,
        state=verdict.state,
        checked_at=utcnow() if verdict.state != "pending" else None,
        raw=verdict.raw,
    )
    session.add(purchase)
    session.add(
        Event(
            install_id=body.install_id,
            kind="purchase_completed",
            store=body.store,
            detail=verdict.state,
        )
    )
    session.commit()

    log.info(
        "receipt taken",
        extra={"store": body.store, "state": verdict.state},
    )
    return entitlement_for(session, body.install_id)


@router.get(
    "/entitlements",
    response_model=Entitlement,
    summary="What this install is owed",
)
def entitlements(
    install_id: str = Query(min_length=8, max_length=64, pattern=r"^[A-Za-z0-9_-]+$"),
    session: Session = Depends(get_session),
) -> Entitlement:
    return entitlement_for(session, install_id)
