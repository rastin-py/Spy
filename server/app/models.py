"""Three tables. Nothing here is a person.

An install is a random number a phone made up on first run. There is no name,
no email, no phone number and no advertising id in this schema, and there is no
column anybody could add one to without noticing.
"""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import ForeignKey, Index, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .db import Base, UtcDateTime, utcnow


class Install(Base):
    """One copy of the app on one phone, as far as anyone can tell."""

    __tablename__ = "installs"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    first_seen: Mapped[datetime] = mapped_column(UtcDateTime, default=utcnow)
    last_seen: Mapped[datetime] = mapped_column(UtcDateTime, default=utcnow, index=True)

    platform: Mapped[str] = mapped_column(String(16), default="android")
    store: Mapped[str] = mapped_column(String(16), default="bazaar", index=True)
    build: Mapped[int] = mapped_column(default=1)
    language: Mapped[str] = mapped_column(String(8), default="en")

    events: Mapped[list["Event"]] = relationship(back_populates="install")
    purchases: Mapped[list["Purchase"]] = relationship(back_populates="install")


class Event(Base):
    """A counter with a timestamp on it.

    Deliberately coarse: how many rounds started, how many ads were asked for,
    how many arrived. Enough to tell whether the ad system is earning anything
    and whether it is annoying anybody, and not one field more.
    """

    __tablename__ = "events"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    install_id: Mapped[str] = mapped_column(
        ForeignKey("installs.id", ondelete="CASCADE"), index=True
    )
    kind: Mapped[str] = mapped_column(String(32), index=True)
    at: Mapped[datetime] = mapped_column(UtcDateTime, default=utcnow, index=True)

    store: Mapped[str] = mapped_column(String(16), default="bazaar")
    build: Mapped[int] = mapped_column(default=1)

    #: A short free-form label - a pack id, an ad zone, a failure reason. Never
    #: anything a player typed.
    detail: Mapped[str | None] = mapped_column(String(64), default=None)

    install: Mapped[Install] = relationship(back_populates="events")


Index("ix_events_kind_at", Event.kind, Event.at)


class Purchase(Base):
    """A receipt from a store, and what we decided about it.

    The token is unique: a receipt replayed from another phone must not mint a
    second entitlement.
    """

    __tablename__ = "purchases"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    install_id: Mapped[str] = mapped_column(
        ForeignKey("installs.id", ondelete="CASCADE"), index=True
    )

    store: Mapped[str] = mapped_column(String(16), index=True)
    product_id: Mapped[str] = mapped_column(String(64), index=True)
    token: Mapped[str] = mapped_column(String(255), unique=True, index=True)

    #: pending -> the store has not been asked yet or could not be reached.
    #: valid   -> the store confirmed it.
    #: refunded / invalid -> it is not an entitlement.
    state: Mapped[str] = mapped_column(String(16), default="pending", index=True)

    created_at: Mapped[datetime] = mapped_column(UtcDateTime, default=utcnow)
    checked_at: Mapped[datetime | None] = mapped_column(UtcDateTime, default=None)

    #: Whatever the store said, kept verbatim for the argument later.
    raw: Mapped[str | None] = mapped_column(Text, default=None)

    install: Mapped[Install] = relationship(back_populates="purchases")

    @property
    def entitles(self) -> bool:
        return self.state == "valid"
