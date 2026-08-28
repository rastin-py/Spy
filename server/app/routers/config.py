"""Version check, ad rules and entitlement - the app's first call each launch.

One call rather than three. A phone that gets an answer here knows everything
it needs for the whole session; a phone that does not falls back to the
defaults compiled into it and behaves identically, only without adverts.
"""

from __future__ import annotations

import logging

from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy.orm import Session

from ..catalog import catalog
from ..db import get_session
from ..schemas import RemoteConfig
from .purchases import entitlement_for

log = logging.getLogger("spy.config")

router = APIRouter(prefix="/v1", tags=["config"])


@router.get("/config", response_model=RemoteConfig, summary="Version check and rules")
def get_config(
    response: Response,
    build: int = Query(default=1, ge=1, description="The caller's build number."),
    platform: str = Query(default="android", pattern="^[a-z]{1,16}$"),
    store: str = Query(default="bazaar", pattern="^[a-z]{1,16}$"),
    install_id: str | None = Query(
        default=None,
        min_length=8,
        max_length=64,
        pattern=r"^[A-Za-z0-9_-]+$",
        description="Anonymous, made up by the phone on first run.",
    ),
    session: Session = Depends(get_session),
) -> RemoteConfig:
    config = catalog.config.model_copy(deep=True)

    if install_id:
        config.ad_free = entitlement_for(session, install_id).ad_free

    # An install that has paid is told so, and told nothing about adverts. The
    # zone ids are not secret, but there is no reason to hand them to a phone
    # that will never ask for one.
    if config.ad_free:
        config.ads.enabled = False
        config.ads.zones = {}

    # Short cache: this carries the kill switch and the ad rules, and a stale
    # copy of a kill switch is not a kill switch. Private, because the answer
    # now depends on who is asking.
    response.headers["Cache-Control"] = "private, max-age=60"

    if build < config.min_supported_build:
        log.info(
            "unsupported build asked for config",
            extra={"app_build": build, "min": config.min_supported_build},
        )
    return config
