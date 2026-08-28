"""What the app is allowed to rely on.

These are contract tests, not coverage: each one pins something the phone
would break on if it changed.
"""

from __future__ import annotations

import hashlib
import json

import pytest
from fastapi.testclient import TestClient

from app.main import create_app


@pytest.fixture(scope="module")
def client():
    with TestClient(create_app()) as c:
        yield c


def test_health_reports_a_loaded_catalogue(client):
    body = client.get("/v1/health").json()
    assert body["ok"] is True
    assert body["packs"] > 0, "the catalogue failed to load from disk"


def test_config_answers_every_field_the_app_reads(client):
    body = client.get("/v1/config", params={"build": 1}).json()
    for key in (
        "latest_build",
        "latest_version",
        "min_supported_build",
        "update_url",
        "force_update",
        "maintenance",
        "flags",
    ):
        assert key in body, f"the app reads {key} on every launch"


def test_catalogue_filters_by_language(client):
    fa = client.get("/v1/packs", params={"lang": "fa"}).json()["packs"]
    assert fa, "the Persian build must have something to download"
    assert {p["language"] for p in fa} == {"fa"}, (
        "a Persian UI offering an English pack is a tell - the word is the "
        "thing being guessed"
    )


def test_catalogue_hides_packs_that_need_a_newer_build(client):
    everything = client.get("/v1/packs", params={"build": 999999}).json()["packs"]
    ancient = client.get("/v1/packs", params={"build": 1}).json()["packs"]
    assert len(ancient) <= len(everything)


def test_pack_body_matches_the_hash_the_catalogue_published(client):
    summary = client.get("/v1/packs", params={"lang": "en"}).json()["packs"][0]
    response = client.get(f"/v1/packs/{summary['id']}/{summary['version']}")

    assert response.status_code == 200
    # The app verifies exactly this before it writes the pack to disk.
    assert hashlib.sha256(response.content).hexdigest() == summary["sha256"]
    assert len(response.content) == summary["bytes"]

    pack = json.loads(response.content)
    assert pack["id"] == summary["id"]
    assert len(pack["words"]) == summary["word_count"]


def test_pack_bodies_are_cached_forever(client):
    summary = client.get("/v1/packs", params={"lang": "en"}).json()["packs"][0]
    response = client.get(f"/v1/packs/{summary['id']}/{summary['version']}")
    assert "immutable" in response.headers["cache-control"]

    # A client that already holds the version pays a few bytes, not the pack.
    again = client.get(
        f"/v1/packs/{summary['id']}/{summary['version']}",
        headers={"If-None-Match": response.headers["etag"]},
    )
    assert again.status_code == 304


def test_a_wrong_version_is_a_miss_not_the_latest_pack(client):
    summary = client.get("/v1/packs", params={"lang": "en"}).json()["packs"][0]
    response = client.get(f"/v1/packs/{summary['id']}/999")
    assert response.status_code == 404, (
        "serving the current version under an old number would let a phone "
        "believe it has a version it does not have"
    )


def test_every_request_carries_a_correlation_id(client):
    assert client.get("/v1/health").headers.get("X-Request-ID")
    supplied = client.get("/v1/health", headers={"X-Request-ID": "abc123"})
    assert supplied.headers["X-Request-ID"] == "abc123"
