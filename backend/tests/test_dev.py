from datetime import datetime
from zoneinfo import ZoneInfo

import pytest
from fastapi.testclient import TestClient

from app import dev
from app.dev import DevSettings, simulated_now
from app.main import app
from app.models import Busyness
from app.services import current_status

client = TestClient(app)
NYC = ZoneInfo("America/New_York")
# Thursday afternoon in term time.
REAL = datetime(2026, 10, 8, 14, 30, tzinfo=NYC)


@pytest.fixture(autouse=True)
def reset_overrides():
    dev.settings = DevSettings()
    yield
    dev.settings = DevSettings()


def test_no_overrides_is_real_time():
    assert simulated_now(REAL, DevSettings()) == REAL
    assert current_status(REAL).simulated is False


def test_hour_and_weekday_overrides():
    t = simulated_now(REAL, DevSettings(hour=3.5, weekday=5))
    assert (t.weekday(), t.hour, t.minute) == (5, 3, 30)


def test_finals_override_moves_into_finals_week():
    t = simulated_now(REAL, DevSettings(finals=True))
    assert t.month == 12 and 8 <= t.day <= 21
    assert t.weekday() == REAL.weekday()


def test_crowd_scales_occupancy():
    normal = current_status(REAL).building.occupancy
    doubled = current_status(REAL, DevSettings(crowd=2)).building.occupancy
    assert doubled == pytest.approx(2 * normal, rel=0.02)


def test_floor_override_forces_fullness():
    status = current_status(REAL, DevSettings(floor_overrides={"5": 1.0}))
    floor5 = next(f for f in status.floors if f.id == "5")
    assert floor5.busyness == Busyness.full
    assert all(a.busyness == Busyness.full for a in floor5.areas)
    assert status.simulated is True


def test_dev_endpoints_round_trip():
    body = {"hour": 3, "crowd": 0.5, "floor_overrides": {"9": 0.0}}
    assert client.put("/api/dev/settings", json=body).status_code == 200
    assert client.get("/api/dev/settings").json()["hour"] == 3

    status = client.get("/api/status").json()
    assert status["simulated"] is True
    floor9 = next(f for f in status["floors"] if f["id"] == "9")
    assert floor9["occupancy"] == 0

    client.delete("/api/dev/settings")
    assert client.get("/api/status").json()["simulated"] is False


def test_rejects_out_of_range_values():
    bad = client.put("/api/dev/settings", json={"floor_overrides": {"5": 1.5}})
    assert bad.status_code == 422
