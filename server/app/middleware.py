"""Request correlation and the single access-log line."""

from __future__ import annotations

import logging
import time
import uuid

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

from .logging import request_id_var

log = logging.getLogger("spy.request")


class RequestContextMiddleware(BaseHTTPMiddleware):
    """Tags every request with an id, times it, and logs exactly one line.

    The client's build and store come in as query parameters rather than
    headers because they are already part of the config call, and having them
    on every log line is what makes "only build 42 on Myket is failing"
    answerable without a database.
    """

    async def dispatch(self, request: Request, call_next) -> Response:
        request_id = request.headers.get("X-Request-ID") or uuid.uuid4().hex[:12]
        token = request_id_var.set(request_id)
        started = time.perf_counter()

        context = {
            "method": request.method,
            "path": request.url.path,
            "client": request.client.host if request.client else "-",
        }
        for key in ("build", "platform", "store", "lang"):
            value = request.query_params.get(key)
            if value is not None:
                context[f"app_{key}" if key != "lang" else "lang"] = value

        try:
            response = await call_next(request)
        except Exception:
            elapsed = (time.perf_counter() - started) * 1000
            # Logged here, with the request context attached, and re-raised so
            # the exception handler still owns the response body.
            log.exception("request failed", extra={**context, "ms": round(elapsed, 1)})
            request_id_var.reset(token)
            raise

        elapsed = (time.perf_counter() - started) * 1000
        response.headers["X-Request-ID"] = request_id
        log.log(
            logging.WARNING if response.status_code >= 500 else logging.INFO,
            "%s %s -> %s",
            request.method,
            request.url.path,
            response.status_code,
            extra={**context, "status": response.status_code, "ms": round(elapsed, 1)},
        )
        request_id_var.reset(token)
        return response
