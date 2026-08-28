"""Runtime configuration, read once from the environment.

Everything is overridable with a `SPY_` prefixed variable, so the container
needs no config file baked into the image.
"""

from __future__ import annotations

from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

_ROOT = Path(__file__).resolve().parent.parent


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_prefix="SPY_",
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    #: Where the pack sources and the remote-config seed live.
    content_dir: Path = _ROOT / "content"

    #: "text" for a readable console, "json" for anything that ships logs.
    log_format: str = "text"
    log_level: str = "INFO"

    #: How long clients may cache the pack manifest. Pack bodies are immutable
    #: and cached for a year regardless - only this list can change.
    manifest_max_age: int = 300

    #: Included in /v1/health so a deploy can be identified from outside.
    release: str = "dev"

    #: SQLite needs no container; production sets a Postgres URL and nothing
    #: else about the code changes.
    database_url: str = "sqlite:///./spy.db"

    #: Guards /admin. Blank leaves the admin pages switched off entirely,
    #: which is the right default for a machine that has not been configured.
    admin_token: str = ""

    #: The product a store sells to switch the ads off. One product, one price,
    #: forever - a game this small does not need a catalogue.
    ad_free_product_id: str = "spy_ad_free"

    #: Stores whose receipts we will look at. Anything else is refused before
    #: it reaches the verifier.
    known_stores: tuple[str, ...] = ("bazaar", "myket")

    @property
    def packs_dir(self) -> Path:
        return self.content_dir / "packs"

    @property
    def config_file(self) -> Path:
        return self.content_dir / "config.json"


@lru_cache
def get_settings() -> Settings:
    return Settings()
