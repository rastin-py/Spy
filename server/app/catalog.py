"""The pack catalogue, loaded from disk once at startup.

Packs are files, not database rows, on purpose: they are read-mostly, they are
identical for every caller, and a file that can be diffed in a pull request is
a better editing story than an admin panel nobody has built yet. When pack
management outgrows this, `Catalog` is the seam a database slots behind - the
routers only ever see the methods below.

Each pack is rendered to its final bytes here, once, and the sha256 published
in the manifest is the hash of exactly those bytes. The app hashes what it
downloaded and compares; there is no canonicalisation contract to get wrong.
"""

from __future__ import annotations

import hashlib
import json
import logging
from dataclasses import dataclass
from pathlib import Path

from .schemas import Pack, PackSummary, RemoteConfig

log = logging.getLogger("spy.catalog")

#: A pack body is immutable for a given version, so it can be cached forever.
IMMUTABLE_CACHE = "public, max-age=31536000, immutable"


@dataclass(frozen=True, slots=True)
class StoredPack:
    pack: Pack
    body: bytes
    sha256: str
    min_build: int
    premium: bool

    @property
    def etag(self) -> str:
        return f'"{self.sha256[:32]}"'

    def summary(self, base_url: str) -> PackSummary:
        return PackSummary(
            id=self.pack.id,
            language=self.pack.language,
            name=self.pack.name,
            version=self.pack.version,
            word_count=len(self.pack.words),
            bytes=len(self.body),
            sha256=self.sha256,
            url=f"{base_url}/v1/packs/{self.pack.id}/{self.pack.version}",
            min_build=self.min_build,
            premium=self.premium,
        )


class Catalog:
    def __init__(self) -> None:
        self._packs: dict[str, StoredPack] = {}
        self._config: RemoteConfig | None = None

    # ---------------------------------------------------------------- loading

    def load(self, packs_dir: Path, config_file: Path) -> None:
        self._packs = self._load_packs(packs_dir)
        self._config = self._load_config(config_file)
        log.info(
            "catalogue loaded",
            extra={"packs": len(self._packs), "dir": str(packs_dir)},
        )

    @staticmethod
    def _load_packs(directory: Path) -> dict[str, StoredPack]:
        packs: dict[str, StoredPack] = {}
        if not directory.is_dir():
            log.warning("no pack directory", extra={"dir": str(directory)})
            return packs

        for path in sorted(directory.glob("*.json")):
            try:
                raw = json.loads(path.read_text(encoding="utf-8"))
                pack = Pack.model_validate(raw)
            except Exception:
                # One bad file must not take the whole service down - the other
                # packs are still servable, and the log names the offender.
                log.exception("skipping unreadable pack", extra={"file": path.name})
                continue

            if not pack.words:
                log.warning("skipping empty pack", extra={"pack": pack.id})
                continue
            if pack.id in packs:
                log.warning("duplicate pack id", extra={"pack": pack.id})
                continue

            # Compact separators and no ASCII escaping: Persian packs are ~3x
            # smaller as UTF-8 than as \u sequences, and mobile data is not free.
            body = json.dumps(
                pack.model_dump(),
                ensure_ascii=False,
                separators=(",", ":"),
                sort_keys=True,
            ).encode("utf-8")

            packs[pack.id] = StoredPack(
                pack=pack,
                body=body,
                sha256=hashlib.sha256(body).hexdigest(),
                min_build=int(raw.get("min_build", 1)),
                premium=bool(raw.get("premium", False)),
            )
        return packs

    @staticmethod
    def _load_config(path: Path) -> RemoteConfig:
        try:
            return RemoteConfig.model_validate_json(path.read_text(encoding="utf-8"))
        except Exception:
            log.exception("config unreadable, serving a permissive default")
            # Never fail closed: a broken config file must not tell every
            # installed copy of the app that it is out of date.
            return RemoteConfig(
                latest_build=1,
                latest_version="1.0.0",
                min_supported_build=1,
                update_url="",
            )

    # ---------------------------------------------------------------- reading

    @property
    def config(self) -> RemoteConfig:
        assert self._config is not None, "catalogue not loaded"
        return self._config

    def summaries(self, base_url: str, language: str | None, build: int) -> list[PackSummary]:
        """Everything this caller can actually use, and nothing else.

        Filtering by build here rather than in the app means a pack that needs
        a newer client is simply invisible to an older one, instead of showing
        up as something that fails to install.
        """
        out = [
            stored.summary(base_url)
            for stored in self._packs.values()
            if (language is None or stored.pack.language == language)
            and build >= stored.min_build
        ]
        out.sort(key=lambda p: (p.language, p.name))
        return out

    def get(self, pack_id: str, version: int) -> StoredPack | None:
        stored = self._packs.get(pack_id)
        if stored is None or stored.pack.version != version:
            return None
        return stored

    def __len__(self) -> int:
        return len(self._packs)


#: One process-wide instance, populated by the app's lifespan.
catalog = Catalog()
