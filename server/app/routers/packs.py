"""The catalogue and the pack bodies."""

from __future__ import annotations

import logging

from fastapi import APIRouter, Depends, Query, Request, Response

from ..catalog import IMMUTABLE_CACHE, catalog
from ..config import Settings, get_settings
from ..schemas import PackList

log = logging.getLogger("spy.packs")

router = APIRouter(prefix="/v1/packs", tags=["packs"])


def _base_url(request: Request) -> str:
    """The origin the client actually reached us on.

    Taken from the request rather than configured, so the same image works
    behind a CDN hostname, a bare IP during a deploy, and localhost in tests.
    """
    return str(request.base_url).rstrip("/")


@router.get("", response_model=PackList, summary="The pack catalogue")
def list_packs(
    request: Request,
    response: Response,
    lang: str | None = Query(
        default=None,
        pattern="^[a-z]{2}$",
        description="Only packs in this language. Packs are never translated.",
    ),
    build: int = Query(default=1, ge=1, description="The caller's build number."),
    settings: Settings = Depends(get_settings),
) -> PackList:
    packs = catalog.summaries(_base_url(request), lang, build)
    response.headers["Cache-Control"] = f"public, max-age={settings.manifest_max_age}"
    log.info("catalogue served", extra={"count": len(packs), "lang": lang or "all"})
    return PackList(packs=packs)


@router.get(
    "/{pack_id}/{version}",
    summary="One pack, words included",
    responses={404: {"description": "No such pack at that version"}},
)
def get_pack(pack_id: str, version: int, request: Request) -> Response:
    stored = catalog.get(pack_id, version)
    if stored is None:
        log.info("pack miss", extra={"pack": pack_id, "version": version})
        return Response(
            content='{"error":"not_found","detail":"no such pack at that version"}',
            media_type="application/json",
            status_code=404,
        )

    # A pack body never changes for a given version, so a client that already
    # has it should be told so in a few bytes rather than sent it again.
    if request.headers.get("If-None-Match") == stored.etag:
        return Response(status_code=304, headers={"ETag": stored.etag})

    return Response(
        content=stored.body,
        media_type="application/json",
        headers={
            "ETag": stored.etag,
            "Cache-Control": IMMUTABLE_CACHE,
            # Published so the app can check what it downloaded against what
            # the catalogue promised, without re-fetching the manifest.
            "X-Pack-SHA256": stored.sha256,
        },
    )
