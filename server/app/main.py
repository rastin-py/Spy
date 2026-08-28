"""Spy's backend.

A version check that also carries the ad rules, a pack catalogue, the pack
bodies, a counter endpoint, receipts, and one page with the numbers on it.

There is still no auth and no rate limiting: everything here is either public
and identical for everybody, or keyed by a random number a phone made up about
itself. The admin pages are the exception and they take a token.

The app must work with this service switched off. Every endpoint here is an
improvement on a working offline app, never a dependency of one - a phone that
cannot reach us plays the same game, with no adverts at all.
"""

from __future__ import annotations

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

from . import logging as spy_logging
from .catalog import catalog
from .config import get_settings
from .db import init_db
from .middleware import RequestContextMiddleware
from .routers import admin as admin_router
from .routers import config as config_router
from .routers import health as health_router
from .routers import packs as packs_router
from .routers import purchases as purchases_router
from .routers import telemetry as telemetry_router

log = logging.getLogger("spy")


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings = get_settings()
    spy_logging.configure(level=settings.log_level, fmt=settings.log_format)
    log.info("starting", extra={"release": settings.release})
    init_db()
    catalog.load(settings.packs_dir, settings.config_file)
    if not settings.admin_token:
        log.warning("SPY_ADMIN_TOKEN is unset - /admin is switched off")
    yield
    log.info("stopping")


def create_app() -> FastAPI:
    app = FastAPI(
        title="Spy",
        version="1.0.0",
        summary="Word packs and version checks for the Spy party game.",
        lifespan=lifespan,
    )
    app.add_middleware(RequestContextMiddleware)
    app.include_router(health_router.router)
    app.include_router(config_router.router)
    app.include_router(packs_router.router)
    app.include_router(telemetry_router.router)
    app.include_router(purchases_router.router)
    app.include_router(admin_router.router)

    @app.exception_handler(Exception)
    async def unhandled(request: Request, exc: Exception) -> JSONResponse:
        # The middleware has already logged this with the request context
        # attached; here we only make sure the client gets JSON rather than a
        # stack trace, and never a detail it could not act on anyway.
        return JSONResponse(
            status_code=500,
            content={"error": "internal", "detail": ""},
        )

    return app


app = create_app()
