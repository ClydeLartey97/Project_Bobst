"""Thin client for NYU's LibCal room booking site (nyu.libcal.com).

Uses the same public endpoints the booking page itself calls: the space
listing page (room names) and the availability grid (15-minute slots).
LibCal's robots.txt asks for 10 seconds between requests; the ingester
enforces that.
"""

import json
import re
from dataclasses import dataclass
from datetime import date, datetime
from typing import Dict, List, Optional
from zoneinfo import ZoneInfo

import httpx

BASE_URL = "https://nyu.libcal.com"
BOBST_LOCATION_ID = 5703
NYC = ZoneInfo("America/New_York")
USER_AGENT = "ProjectBobst/0.1 (NYU student prototype)"


@dataclass(frozen=True)
class RoomGroup:
    id: int  # LibCal "gid"
    name: str


# Bobst room types as listed on nyu.libcal.com.
BOBST_GROUPS: List[RoomGroup] = [
    RoomGroup(14114, "Group Study Rooms"),
    RoomGroup(13943, "Individual Study Rooms"),
    RoomGroup(42537, "Sensory-Friendly Pods"),
    RoomGroup(13936, "Grad Collaborative Rooms"),
    RoomGroup(13938, "Grad Individual Rooms"),
]


@dataclass(frozen=True)
class RoomInfo:
    id: int  # LibCal "eid"
    name: str
    floor: Optional[str]
    capacity: Optional[int]

    @property
    def booking_url(self) -> str:
        return f"{BASE_URL}/space/{self.id}"


@dataclass(frozen=True)
class Slot:
    start: datetime
    end: datetime
    available: bool


_RESOURCE = re.compile(
    r'resources\.push\(\{\s*id:\s*"eid_(\d+)",\s*title:\s*("(?:[^"\\]|\\.)*")'
)
_CAPACITY = re.compile(r"\s*\(Capacity (\d+)\)\s*$")
# "Floor 8 …", "Floor LL2 …", "LL2 Pod-01", "8 Pod-1"
_FLOOR = re.compile(
    r"\b(?:Floor|FL)\s*(\d+)\b|\b(LL\s?\d)\b|^(\d{1,2})\s", re.IGNORECASE
)
_HEADING = re.compile(r"<h1[^>]*>(.*?)</h1>", re.DOTALL)
_TAG = re.compile(r"<[^>]+>")


def parse_rooms(html: str) -> Dict[int, RoomInfo]:
    """Room names from a LibCal space listing page."""
    rooms = {}
    for eid, raw_title in _RESOURCE.findall(html):
        title = json.loads(raw_title)  # decodes   etc.
        capacity_match = _CAPACITY.search(title)
        name = _CAPACITY.sub("", title).strip()
        rooms[int(eid)] = RoomInfo(
            id=int(eid),
            name=name,
            floor=_parse_floor(name),
            capacity=int(capacity_match.group(1)) if capacity_match else None,
        )
    return rooms


def _parse_floor(name: str) -> Optional[str]:
    match = _FLOOR.search(name)
    if not match:
        return None
    number, lower, leading = match.groups()
    if lower:
        return lower.replace(" ", "").upper()
    return number or leading


def parse_room_page(eid: int, html: str) -> Optional[RoomInfo]:
    """Fallback for rooms missing from the listing: read the room's own page."""
    match = _HEADING.search(html)
    if not match:
        return None
    title = " ".join(_TAG.sub("", match.group(1)).split())
    capacity = _CAPACITY.search(title)
    name = _CAPACITY.sub("", title).strip()
    return RoomInfo(
        id=eid,
        name=name,
        floor=_parse_floor(name),
        capacity=int(capacity.group(1)) if capacity else None,
    )


def parse_slots(payload: dict) -> Dict[int, List[Slot]]:
    """Availability grid JSON → slots per room, sorted by start time.

    A slot with no className is bookable; "s-lc-eq-checkout" means booked and
    "s-lc-eq-r-unavailable" means outside bookable hours.
    """
    by_room: Dict[int, List[Slot]] = {}
    for raw in payload.get("slots", []):
        slot = Slot(
            start=_parse_time(raw["start"]),
            end=_parse_time(raw["end"]),
            available=not raw.get("className"),
        )
        by_room.setdefault(int(raw["itemId"]), []).append(slot)
    for slots in by_room.values():
        slots.sort(key=lambda s: s.start)
    return by_room


def _parse_time(value: str) -> datetime:
    return datetime.strptime(value, "%Y-%m-%d %H:%M:%S").replace(tzinfo=NYC)


class LibCalClient:
    def __init__(self, client: Optional[httpx.AsyncClient] = None):
        self._client = client or httpx.AsyncClient(
            base_url=BASE_URL,
            headers={"User-Agent": USER_AGENT},
            timeout=20,
            follow_redirects=True,
        )

    async def fetch_rooms(self, group: RoomGroup) -> Dict[int, RoomInfo]:
        response = await self._client.get(
            "/spaces", params={"lid": BOBST_LOCATION_ID, "gid": group.id}
        )
        response.raise_for_status()
        return parse_rooms(response.text)

    async def fetch_room(self, eid: int) -> Optional[RoomInfo]:
        response = await self._client.get(f"/space/{eid}")
        response.raise_for_status()
        return parse_room_page(eid, response.text)

    async def fetch_slots(
        self, group: RoomGroup, start: date, end: date
    ) -> Dict[int, List[Slot]]:
        response = await self._client.post(
            "/spaces/availability/grid",
            data={
                "lid": BOBST_LOCATION_ID,
                "gid": group.id,
                "eid": -1,
                "seat": 0,
                "seatId": 0,
                "zone": 0,
                "start": start.isoformat(),
                "end": end.isoformat(),
                "pageIndex": 0,
                "pageSize": 200,
            },
            headers={
                "Referer": f"{BASE_URL}/spaces?lid={BOBST_LOCATION_ID}&gid={group.id}",
                "X-Requested-With": "XMLHttpRequest",
            },
        )
        response.raise_for_status()
        return parse_slots(response.json())

    async def aclose(self) -> None:
        await self._client.aclose()
