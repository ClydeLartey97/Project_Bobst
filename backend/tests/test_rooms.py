import asyncio
from datetime import datetime, timedelta

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.rooms import ingest
from app.rooms.ingest import RoomIngester
from app.rooms.libcal import (
    NYC,
    RoomGroup,
    parse_room_page,
    parse_rooms,
    parse_slots,
)
from app.rooms.status import RoomState, group_status, room_state

# Trimmed from a real nyu.libcal.com listing page.
LISTING_HTML = r"""
<script>
                                    resources.push({
    id: "eid_108309",
    title: "Floor 8 Individual Study Room 838 (Capacity 1)",
    url: "/space/108309",
    eid: 108309,
    gid: 13943,
    lid: 5703,
                                    resources.push({
    id: "eid_200001",
    title: "LL2 Group Study Room 10 (Capacity 6)",
    url: "/space/200001",
</script>
"""

# Same shape as POST /spaces/availability/grid.
GRID = {
    "slots": [
        {"start": "2026-10-09 17:00:00", "end": "2026-10-09 17:15:00", "itemId": 108309, "checksum": "a"},
        {"start": "2026-10-09 17:15:00", "end": "2026-10-09 17:30:00", "itemId": 108309, "checksum": "b"},
        {"start": "2026-10-09 17:30:00", "end": "2026-10-09 17:45:00", "itemId": 108309, "checksum": "c", "className": "s-lc-eq-checkout"},
        {"start": "2026-10-09 17:00:00", "end": "2026-10-09 17:15:00", "itemId": 200001, "checksum": "d", "className": "s-lc-eq-checkout"},
        {"start": "2026-10-09 17:15:00", "end": "2026-10-09 17:30:00", "itemId": 200001, "checksum": "e"},
    ],
    "bookings": [],
    "isPreCreatedBooking": False,
    "windowEnd": False,
}

NOW = datetime(2026, 10, 9, 17, 5, tzinfo=NYC)


def test_parse_rooms_decodes_names_floor_and_capacity():
    rooms = parse_rooms(LISTING_HTML)
    room = rooms[108309]
    assert room.name == "Floor 8 Individual Study Room 838"
    assert room.floor == "8"
    assert room.capacity == 1
    assert rooms[200001].floor == "LL2"
    assert rooms[200001].capacity == 6


@pytest.mark.parametrize(
    "title, floor",
    [
        ("Floor 8 Individual Study Room 838", "8"),
        ("Floor LL2 Group Study Room LL2-19", "LL2"),
        ("LL2 Pod-01", "LL2"),
        ("8 Pod-1", "8"),
        ("Study Room 1021", None),
    ],
)
def test_floor_parsing(title, floor):
    html = f'resources.push({{ id: "eid_1", title: "{title}",'
    assert parse_rooms(html)[1].floor == floor


def test_parse_room_page_fallback():
    html = "<h1 class='x'>\n  Floor LL2 Group Study Room LL2-19\n</h1>"
    room = parse_room_page(108111, html)
    assert room.name == "Floor LL2 Group Study Room LL2-19"
    assert room.floor == "LL2"


def test_parse_slots_marks_booked_slots_unavailable():
    slots = parse_slots(GRID)
    assert [s.available for s in slots[108309]] == [True, True, False]
    assert slots[108309][0].start == datetime(2026, 10, 9, 17, 0, tzinfo=NYC)


def test_free_room_reports_how_long_it_stays_free():
    state, free_until, next_free = room_state(parse_slots(GRID)[108309], NOW)
    assert state == RoomState.free
    assert free_until == datetime(2026, 10, 9, 17, 30, tzinfo=NYC)
    assert next_free is None


def test_booked_room_reports_when_it_frees_up():
    state, free_until, next_free = room_state(parse_slots(GRID)[200001], NOW)
    assert state == RoomState.booked
    assert next_free == datetime(2026, 10, 9, 17, 15, tzinfo=NYC)


def test_room_with_no_current_slot_is_closed():
    late = NOW + timedelta(hours=8)
    state, _, next_free = room_state(parse_slots(GRID)[108309], late)
    assert state == RoomState.closed
    assert next_free is None


class FakeLibCal:
    def __init__(self, listing=LISTING_HTML):
        self.calls = []
        self.listing = listing

    async def fetch_rooms(self, group):
        self.calls.append(("rooms", group.id))
        return parse_rooms(self.listing)

    async def fetch_room(self, eid):
        self.calls.append(("room", eid))
        return parse_room_page(eid, f"<h1>Mystery Room {eid}</h1>")

    async def fetch_slots(self, group, start, end):
        self.calls.append(("slots", group.id))
        return parse_slots(GRID)

    async def aclose(self):
        pass


def test_ingester_fetches_room_lists_once_and_slots_every_time():
    fake = FakeLibCal()
    ingester = RoomIngester(fake, groups=[RoomGroup(1, "Test Rooms")])
    asyncio.run(ingester.refresh_all())
    asyncio.run(ingester.refresh_all())
    assert fake.calls == [("rooms", 1), ("slots", 1), ("slots", 1)]

    status = group_status(ingester.snapshots[1], NOW)
    assert (status.free_now, status.total) == (1, 2)
    assert status.rooms[0].state == RoomState.free  # free rooms sort first
    assert status.rooms[0].booking_url == "https://nyu.libcal.com/space/108309"


def test_ingester_looks_up_rooms_missing_from_listing_once():
    listing_without_200001 = LISTING_HTML.split("resources.push", 2)
    listing_without_200001 = "resources.push".join(listing_without_200001[:2])
    fake = FakeLibCal(listing=listing_without_200001)
    ingester = RoomIngester(fake, groups=[RoomGroup(1, "Test Rooms")])
    asyncio.run(ingester.refresh_all())
    asyncio.run(ingester.refresh_all())

    assert fake.calls.count(("room", 200001)) == 1
    assert ingester.snapshots[1].rooms[200001].name == "Mystery Room 200001"


class BrokenLibCal(FakeLibCal):
    async def fetch_slots(self, group, start, end):
        raise RuntimeError("LibCal is down")


def test_ingester_keeps_last_good_data_on_failure():
    ingester = RoomIngester(FakeLibCal(), groups=[RoomGroup(1, "Test Rooms")])
    asyncio.run(ingester.refresh_all())
    ingester.client = BrokenLibCal()
    asyncio.run(ingester.refresh_all())

    snapshot = ingester.snapshots[1]
    assert snapshot.error == "LibCal is down"
    assert len(snapshot.slots) == 2


@pytest.fixture
def fake_ingester():
    ingest.ingester = RoomIngester(FakeLibCal(), groups=[RoomGroup(1, "Test Rooms")])
    asyncio.run(ingest.ingester.refresh_all())
    yield
    ingest.ingester = None


def test_rooms_endpoint(fake_ingester):
    body = TestClient(app).get("/api/rooms").json()
    group = body["groups"][0]
    assert group["name"] == "Test Rooms"
    assert group["total"] == 2
    assert {r["state"] for r in group["rooms"]} <= {"free", "booked", "closed"}


def test_rooms_endpoint_503_when_ingestion_off():
    ingest.ingester = None
    assert TestClient(app).get("/api/rooms").status_code == 503
