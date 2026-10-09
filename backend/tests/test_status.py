from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

from fastapi.testclient import TestClient

from app.floors import FLOORS
from app.main import app
from app.models import Busyness
from app.services import busyness_for, current_status

client = TestClient(app)
NYC = ZoneInfo("America/New_York")
WEDNESDAY = datetime(2026, 10, 7, tzinfo=NYC)


def at(hour, minute=0, day=WEDNESDAY):
    return current_status(day.replace(hour=hour, minute=minute))


def test_status_endpoint_shape():
    response = client.get("/api/status")
    assert response.status_code == 200
    body = response.json()

    assert [f["id"] for f in body["floors"]] == [f.id for f in FLOORS]
    for floor in body["floors"]:
        assert floor["occupancy"] == sum(a["occupancy"] for a in floor["areas"])
        assert 0 <= floor["fullness"] <= 1
    building = body["building"]
    assert building["occupancy"] == sum(f["occupancy"] for f in body["floors"])
    assert "best_spots" not in body


def test_busyness_scale():
    assert busyness_for(0.05) == Busyness.empty
    assert busyness_for(0.2) == Busyness.quite_empty
    assert busyness_for(0.4) == Busyness.not_too_busy
    assert busyness_for(0.6) == Busyness.busy
    assert busyness_for(0.8) == Busyness.very_busy
    assert busyness_for(0.95) == Busyness.full


def test_area_labels():
    floor5 = next(f for f in at(12).floors if f.id == "5")
    assert "5th Floor East" in [a.label for a in floor5.areas]


def test_daily_pattern():
    assert at(4).building.busyness in (Busyness.empty, Busyness.quite_empty)
    assert at(15, 30).building.busyness in (Busyness.very_busy, Busyness.full)


def test_finals_and_weekends():
    finals = datetime(2026, 12, 9, tzinfo=NYC)
    saturday = datetime(2026, 10, 10, tzinfo=NYC)
    normal = at(14).building.occupancy
    assert at(14, day=finals).building.occupancy > normal
    assert at(14, day=saturday).building.occupancy < normal


def test_changes_smoothly_minute_to_minute():
    t = WEDNESDAY.replace(hour=13, minute=10)
    a = current_status(t).building.occupancy
    b = current_status(t + timedelta(minutes=1)).building.occupancy
    assert a != b
    assert abs(a - b) < 0.02 * at(13).building.capacity


def test_every_area_has_a_place_and_sides_dont_overlap():
    for floor in FLOORS:
        taken = [side for area in floor.areas for side in area.sides]
        assert all(area.sides for area in floor.areas), floor.id
        assert len(taken) == len(set(taken)), floor.id
