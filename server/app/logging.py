"""Logging setup.

One line per request, correlated by a request id that also goes back to the
client in `X-Request-ID`. When something breaks in the field, the id in a bug
report is enough to find the exact request.

`SPY_LOG_FORMAT=text` gives a readable console for development; `json` gives
one JSON object per line for anything that ingests logs.
"""

from __future__ import annotations

import json
import logging
import sys
from contextvars import ContextVar
from typing import Any

#: Set by the request middleware, read by the formatter. Anything logged
#: anywhere during a request carries the id without having to pass it around.
request_id_var: ContextVar[str] = ContextVar("request_id", default="-")

#: Keys the standard LogRecord already owns; everything else a caller attaches
#: through `extra=` is treated as structured context.
_RESERVED = {
    "args", "asctime", "created", "exc_info", "exc_text", "filename",
    "funcName", "levelname", "levelno", "lineno", "module", "msecs",
    "message", "msg", "name", "pathname", "process", "processName",
    "relativeCreated", "stack_info", "thread", "threadName", "taskName",
    "color_message",
}


def _extras(record: logging.LogRecord) -> dict[str, Any]:
    return {k: v for k, v in record.__dict__.items() if k not in _RESERVED}


class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        payload: dict[str, Any] = {
            "ts": self.formatTime(record, "%Y-%m-%dT%H:%M:%S%z"),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
            "request_id": request_id_var.get(),
        }
        payload.update(_extras(record))
        if record.exc_info:
            payload["exception"] = self.formatException(record.exc_info)
        return json.dumps(payload, ensure_ascii=False, default=str)


class TextFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        head = (
            f"{self.formatTime(record, '%H:%M:%S')} "
            f"{record.levelname:<7} "
            f"[{request_id_var.get()}] "
            f"{record.getMessage()}"
        )
        extras = _extras(record)
        if extras:
            head += "  " + " ".join(f"{k}={v}" for k, v in extras.items())
        if record.exc_info:
            head += "\n" + self.formatException(record.exc_info)
        return head


def configure(level: str = "INFO", fmt: str = "text") -> None:
    formatter = JsonFormatter() if fmt == "json" else TextFormatter()

    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(formatter)

    root = logging.getLogger()
    root.handlers.clear()
    root.addHandler(handler)
    root.setLevel(level.upper())

    # Uvicorn's own access log would be a second, less useful copy of the line
    # the request middleware already writes.
    logging.getLogger("uvicorn.access").disabled = True
    for name in ("uvicorn", "uvicorn.error"):
        logger = logging.getLogger(name)
        logger.handlers.clear()
        logger.propagate = True
