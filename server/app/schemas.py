"""The wire contract.

These models are the only description of what the app may rely on. A field
removed here is a field that breaks a phone somebody cannot be made to update,
so treat every one as permanent and add rather than change.
"""

from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


class Health(BaseModel):
    ok: bool = True
    release: str
    packs: int


class AdsConfig(BaseModel):
    """Every rule about when an advert may appear, set from here.

    The app ships with the same defaults compiled in, so a phone that cannot
    reach the server behaves identically rather than falling into some other
    mode. Nothing below can make an advert appear anywhere except Home.
    """

    enabled: bool = False

    #: Which network the app should ask. The app only knows the ones it was
    #: built with; an unknown name switches adverts off rather than guessing.
    provider: Literal["none", "tapsell"] = "none"

    #: The floor between two adverts under normal use.
    cooldown_minutes: int = Field(default=20, ge=0, le=1440)

    #: Relaunching the app clears the cooldown - a new evening should not be
    #: silent because somebody played twenty minutes ago.
    reset_on_restart: bool = True

    #: The floor a relaunch cannot get under. Without it, closing and
    #: reopening the app is a way to see an advert every ten seconds, and the
    #: person who discovers that uninstalls.
    min_gap_seconds: int = Field(default=90, ge=0, le=3600)

    #: How many rounds somebody plays before the first advert. A game nobody
    #: has finished once yet has not earned the right to interrupt them.
    quiet_rounds: int = Field(default=1, ge=0, le=50)

    #: The only placement there is, and the only one there will be: pressing
    #: the button on Home that starts a game. Never mid-round, never on the
    #: card, never on the clock.
    placements: dict[str, bool] = Field(default_factory=lambda: {"home_start": True})

    #: Placement -> the network's zone id. Empty means the app has nothing to
    #: ask for and shows nothing.
    zones: dict[str, str] = Field(default_factory=dict)


class PacksNudge(BaseModel):
    """Whether, and how often, to mention that there are more word packs."""

    enabled: bool = True

    #: Not before somebody has played this many rounds. Asking a stranger to
    #: go online before they have finished a game is a way to lose them.
    after_rounds: int = Field(default=2, ge=0, le=100)

    #: Once dismissed, stay quiet this long. Zero means never come back.
    repeat_after_hours: int = Field(default=72, ge=0, le=8760)


class RemoteConfig(BaseModel):
    """Version check and remote config, answered in one call at startup."""

    latest_build: int = Field(description="Highest build published to any store.")
    latest_version: str = Field(description='Human-facing, e.g. "1.2.0".')
    min_supported_build: int = Field(
        description=(
            "Builds below this can no longer talk to the server usefully and "
            "should insist on an update. The one lever that works on a store "
            "with no forced updates."
        )
    )
    update_url: str = Field(
        description='Store deep link, e.g. "bazaar://details?id=...".'
    )
    changelog: str = ""
    force_update: bool = False

    #: True takes the app offline-only and says so, rather than letting every
    #: call fail one at a time.
    maintenance: bool = False

    #: Free-form switches the app reads defensively - an unknown key is
    #: ignored, a missing key falls back to the built-in default.
    flags: dict[str, bool] = Field(default_factory=dict)

    ads: AdsConfig = Field(default_factory=AdsConfig)
    packs_nudge: PacksNudge = Field(default_factory=PacksNudge)

    #: True when this install has bought its way out of adverts. Answered here
    #: so the app learns it in the call it already makes, rather than in a
    #: second one it would have to handle failing separately.
    ad_free: bool = False


class PackSummary(BaseModel):
    """One entry in the catalogue. Metadata only - never the words."""

    id: str
    language: str
    name: str
    version: int
    word_count: int
    bytes: int
    sha256: str
    url: str
    min_build: int = 1
    premium: bool = False


class PackList(BaseModel):
    packs: list[PackSummary]


class Pack(BaseModel):
    """A pack body. Immutable for a given (id, version)."""

    id: str
    language: str
    name: str
    version: int
    words: list[str]


# --------------------------------------------------------------------- events


class EventIn(BaseModel):
    """One counter tick. Never anything a player typed."""

    kind: str = Field(max_length=32)
    at: datetime | None = None

    #: A pack id, an ad zone, a failure reason. Short and non-identifying.
    detail: str | None = Field(default=None, max_length=64)


class EventBatch(BaseModel):
    """Sent when convenient, dropped when not. Nothing waits on this."""

    install_id: str = Field(min_length=8, max_length=64, pattern=r"^[A-Za-z0-9_-]+$")
    platform: str = Field(default="android", max_length=16)
    store: str = Field(default="bazaar", max_length=16)
    build: int = Field(default=1, ge=1)
    language: str = Field(default="en", max_length=8)
    events: list[EventIn] = Field(default_factory=list, max_length=100)


# ------------------------------------------------------------------ purchases


class PurchaseIn(BaseModel):
    install_id: str = Field(min_length=8, max_length=64, pattern=r"^[A-Za-z0-9_-]+$")
    store: str = Field(max_length=16)
    product_id: str = Field(max_length=64)

    #: The receipt the store's billing library handed the app.
    token: str = Field(min_length=4, max_length=255)


class Entitlement(BaseModel):
    ad_free: bool = False

    #: pending means the store could not be reached yet. The app treats it as
    #: granted - somebody who has paid must not see adverts because our
    #: verifier is having a bad afternoon.
    state: str = "none"
    checked_at: datetime | None = None


class Error(BaseModel):
    error: str
    detail: str = ""
