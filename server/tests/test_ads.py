"""Ad rules, counters, receipts and the admin page.

Contract tests again: each one pins something the app or the money depends on.
"""

from __future__ import annotations

import os
import uuid

import pytest
from fastapi.testclient import TestClient

os.environ.setdefault("SPY_ADMIN_TOKEN", "test-token")


@pytest.fixture(scope="module")
def client(tmp_path_factory):
    # A database per run, so counts are not inherited from the last one.
    db = tmp_path_factory.mktemp("db") / "test.db"
    os.environ["SPY_DATABASE_URL"] = f"sqlite:///{db}"

    from app.config import get_settings

    get_settings.cache_clear()
    # `db` binds its engine at import, so it has to be reloaded after the URL
    # is set rather than merely re-read.
    import importlib

    from app import db as db_module

    importlib.reload(db_module)
    import app.models
    import app.routers.admin
    import app.routers.purchases
    import app.routers.telemetry

    importlib.reload(app.models)
    importlib.reload(app.routers.telemetry)
    importlib.reload(app.routers.purchases)
    importlib.reload(app.routers.admin)

    from app import main

    importlib.reload(main)
    with TestClient(main.create_app()) as c:
        yield c


def an_install() -> str:
    return uuid.uuid4().hex


class TestAdRules:
    def test_the_app_is_told_every_rule_it_needs(self, client):
        ads = client.get("/v1/config").json()["ads"]
        for key in (
            "enabled",
            "provider",
            "cooldown_minutes",
            "reset_on_restart",
            "min_gap_seconds",
            "quiet_rounds",
            "placements",
            "zones",
        ):
            assert key in ads, f"the app reads {key} before showing anything"

    def test_the_only_placement_is_home(self, client):
        placements = client.get("/v1/config").json()["ads"]["placements"]
        assert set(placements) <= {"home_start"}, (
            "an advert must not be configurable into the middle of a round - "
            "backgrounding the app during a reveal voids the deal"
        )

    def test_packs_are_nudged_only_after_somebody_has_played(self, client):
        nudge = client.get("/v1/config").json()["packs_nudge"]
        assert nudge["after_rounds"] >= 1, (
            "asking a stranger to go online before they have finished a game "
            "is a way to lose them"
        )


class TestCounters:
    def test_a_batch_creates_the_install_and_keeps_known_events(self, client):
        install = an_install()
        response = client.post(
            "/v1/events",
            json={
                "install_id": install,
                "store": "myket",
                "build": 3,
                "events": [
                    {"kind": "app_open"},
                    {"kind": "game_started"},
                    {"kind": "ad_shown", "detail": "home_start"},
                ],
            },
        )
        assert response.status_code == 204

        summary = client.get(
            "/admin/summary.json", params={"token": "test-token"}
        ).json()
        assert summary["installs"]["total"] >= 1
        assert summary["events"]["game_started"] >= 1
        assert summary["installs"]["by_store"].get("myket", 0) >= 1

    def test_an_unknown_event_is_dropped_rather_than_stored(self, client):
        install = an_install()
        before = client.get(
            "/admin/summary.json", params={"token": "test-token"}
        ).json()["events"]

        client.post(
            "/v1/events",
            json={
                "install_id": install,
                "events": [{"kind": "something_a_later_build_invented"}],
            },
        )

        after = client.get(
            "/admin/summary.json", params={"token": "test-token"}
        ).json()["events"]
        assert "something_a_later_build_invented" not in after
        assert set(after) == set(before) or set(after) >= set(before)

    def test_nothing_about_a_player_can_be_sent(self, client):
        from app.models import Event, Install

        columns = {c.name for c in Event.__table__.columns} | {
            c.name for c in Install.__table__.columns
        }
        # If somebody adds one of these, this test is the argument.
        assert not columns & {"name", "email", "phone", "ad_id", "ip"}


class TestReceipts:
    def test_a_receipt_grants_ad_free_even_before_it_is_verified(self, client):
        install = an_install()
        response = client.post(
            "/v1/purchases/verify",
            json={
                "install_id": install,
                "store": "bazaar",
                "product_id": "spy_ad_free",
                "token": "receipt-" + install,
            },
        )
        assert response.status_code == 200
        body = response.json()
        assert body["ad_free"] is True
        assert body["state"] == "pending", (
            "no store credentials are configured yet, and somebody who paid "
            "must not see adverts because of that"
        )

    def test_the_config_call_tells_a_payer_the_ads_are_off(self, client):
        install = an_install()
        client.post(
            "/v1/purchases/verify",
            json={
                "install_id": install,
                "store": "bazaar",
                "product_id": "spy_ad_free",
                "token": "receipt-" + install,
            },
        )
        config = client.get("/v1/config", params={"install_id": install}).json()
        assert config["ad_free"] is True
        assert config["ads"]["enabled"] is False
        assert config["ads"]["zones"] == {}, "no zones for a phone that will not ask"

    def test_handing_the_same_receipt_in_twice_changes_nothing(self, client):
        install = an_install()
        body = {
            "install_id": install,
            "store": "bazaar",
            "product_id": "spy_ad_free",
            "token": "receipt-" + install,
        }
        first = client.post("/v1/purchases/verify", json=body).json()
        second = client.post("/v1/purchases/verify", json=body).json()
        assert first == second, "a retry after a dropped connection is not a purchase"

    def test_a_receipt_cannot_be_replayed_from_another_phone(self, client):
        mine, yours = an_install(), an_install()
        token = "receipt-" + mine
        client.post(
            "/v1/purchases/verify",
            json={
                "install_id": mine,
                "store": "bazaar",
                "product_id": "spy_ad_free",
                "token": token,
            },
        )
        stolen = client.post(
            "/v1/purchases/verify",
            json={
                "install_id": yours,
                "store": "bazaar",
                "product_id": "spy_ad_free",
                "token": token,
            },
        )
        assert stolen.status_code == 409
        assert client.get(
            "/v1/entitlements", params={"install_id": yours}
        ).json()["ad_free"] is False

    def test_an_unknown_store_or_product_is_refused(self, client):
        install = an_install()
        for bad in (
            {"store": "playstore", "product_id": "spy_ad_free"},
            {"store": "bazaar", "product_id": "spy_everything_free"},
        ):
            response = client.post(
                "/v1/purchases/verify",
                json={"install_id": install, "token": "t-" + install, **bad},
            )
            assert response.status_code == 400

    def test_an_install_that_has_paid_nothing_is_owed_nothing(self, client):
        response = client.get(
            "/v1/entitlements", params={"install_id": an_install()}
        )
        assert response.json() == {
            "ad_free": False,
            "state": "none",
            "checked_at": None,
        }


class TestAdminPage:
    def test_the_numbers_page_renders(self, client):
        page = client.get("/admin", params={"token": "test-token"})
        assert page.status_code == 200
        assert "Adverts" in page.text
        assert "Receipts" in page.text

    def test_a_bearer_token_works_too(self, client):
        response = client.get(
            "/admin/summary.json", headers={"Authorization": "Bearer test-token"}
        )
        assert response.status_code == 200

    def test_the_wrong_token_gets_nothing(self, client):
        assert client.get("/admin", params={"token": "nope"}).status_code == 401
        assert client.get("/admin").status_code == 401
