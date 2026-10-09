from datetime import datetime
from zoneinfo import ZoneInfo

from fastapi.testclient import TestClient

from app.floors import FLOORS
from app.main import app
from app.services import current_floors, level_for, status_for

client = TestClient(app)
NYC = ZoneInfo("America/New_York")


def test_floors_endpoint_lists_every_floor():
    response = client.get("/api/floors")
    assert response.status_code == 200
    body = response.json()
    assert [f["id"] for f in body["floors"]] == [f.id for f in FLOORS]
    for floor in body["floors"]:
        assert 0 <= floor["busyness"] <= 1
        assert floor["level"] in {"quiet", "moderate", "busy"}

    building = body["building"]
    assert building["occupancy"] == sum(f["occupancy"] for f in body["floors"])
    assert building["status"] in {"available", "full"}


def test_afternoon_busier_than_early_morning():
    def total(hour):
        floors = current_floors(datetime(2026, 10, 7, hour, tzinfo=NYC)).floors
        return sum(f.occupancy for f in floors)

    assert total(15) > total(4)


def test_level_thresholds():
    assert level_for(0.1).value == "quiet"
    assert level_for(0.5).value == "moderate"
    assert level_for(0.9).value == "busy"


def test_building_status_threshold():
    assert status_for(0.5).value == "available"
    assert status_for(0.8).value == "full"


def test_dummy_data_fills_up_midafternoon_on_weekdays():
    afternoon = current_floors(datetime(2026, 10, 7, 15, 30, tzinfo=NYC))
    night = current_floors(datetime(2026, 10, 7, 3, tzinfo=NYC))
    assert afternoon.building.status.value == "full"
    assert night.building.status.value == "available"
