"""The database, which exists because of money.

Packs did not need one - they are files, identical for everybody. Purchases and
the counts behind them do: they are per-install, they are written concurrently,
and getting one wrong costs somebody something real.

SQLite by default so a laptop needs no container; set `SPY_DATABASE_URL` to a
Postgres URL in production and nothing else changes.
"""

from __future__ import annotations

import logging
from collections.abc import Iterator
from datetime import datetime, timezone

from sqlalchemy import DateTime, TypeDecorator, create_engine, event
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from .config import get_settings

log = logging.getLogger("spy.db")


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


class UtcDateTime(TypeDecorator):
    """Always aware, always UTC, on SQLite as well as Postgres.

    SQLite hands back naive datetimes, which compare wrongly against an aware
    `utcnow()` and silently break every "in the last 24 hours" query.
    """

    impl = DateTime(timezone=True)
    cache_ok = True

    def process_bind_param(self, value: datetime | None, dialect):
        if value is None:
            return None
        return value.astimezone(timezone.utc)

    def process_result_value(self, value: datetime | None, dialect):
        if value is None:
            return None
        return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value


class Base(DeclarativeBase):
    pass


_settings = get_settings()
_url = _settings.database_url

engine = create_engine(
    _url,
    echo=False,
    future=True,
    connect_args={"check_same_thread": False} if _url.startswith("sqlite") else {},
)

if _url.startswith("sqlite"):

    @event.listens_for(engine, "connect")
    def _sqlite_pragmas(connection, _record):
        cursor = connection.cursor()
        # WAL so a write does not lock out every reader, and foreign keys on
        # because SQLite ignores them otherwise.
        cursor.execute("PRAGMA journal_mode=WAL")
        cursor.execute("PRAGMA foreign_keys=ON")
        cursor.execute("PRAGMA busy_timeout=5000")
        cursor.close()


SessionLocal = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)


def init_db() -> None:
    from . import models  # noqa: F401  (registers the tables)

    Base.metadata.create_all(engine)
    log.info("database ready", extra={"url": _url.split("://", 1)[0]})


def get_session() -> Iterator[Session]:
    session = SessionLocal()
    try:
        yield session
    finally:
        session.close()
