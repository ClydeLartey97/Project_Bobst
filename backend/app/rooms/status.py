"""Turns ingested slots into "is this room free right now?" answers."""

from datetime import datetime
from enum import Enum
from typing import List, Optional

from pydantic import BaseModel

from app.rooms.ingest import GroupSnapshot
from app.rooms.libcal import Slot


class RoomState(str, Enum):
    free = "free"  # bookable right now
    booked = "booked"  # someone has it
    closed = "closed"  # outside bookable hours


class Room(BaseModel):
    id: int
    name: str
    floor: Optional[str]
    capacity: Optional[int]
    state: RoomState
    free_until: Optional[datetime]  # when state is free
    next_free_at: Optional[datetime]  # when state is booked/closed; None = not today/tomorrow
    booking_url: str


class RoomGroupStatus(BaseModel):
    id: int
    name: str
    free_now: int
    total: int
    rooms: List[Room]
    updated_at: Optional[datetime]
    error: Optional[str]


class RoomsResponse(BaseModel):
    groups: List[RoomGroupStatus]


def room_state(slots: List[Slot], now: datetime):
    """(state, free_until, next_free_at) for one room's sorted slots."""
    current = next((s for s in slots if s.start <= now < s.end), None)
    upcoming = [s for s in slots if s.end > now]

    if current and current.available:
        free_until = current.end
        for s in upcoming:
            if s.start == free_until and s.available:
                free_until = s.end
        return RoomState.free, free_until, None

    next_free = next((s.start for s in upcoming if s.available and s.start >= now), None)
    state = RoomState.booked if current else RoomState.closed
    return state, None, next_free


_ORDER = {RoomState.free: 0, RoomState.booked: 1, RoomState.closed: 2}


def group_status(snapshot: GroupSnapshot, now: datetime) -> RoomGroupStatus:
    rooms = []
    for room_id, slots in snapshot.slots.items():
        info = snapshot.rooms.get(room_id)
        state, free_until, next_free_at = room_state(slots, now)
        rooms.append(
            Room(
                id=room_id,
                name=info.name if info else f"Room {room_id}",
                floor=info.floor if info else None,
                capacity=info.capacity if info else None,
                state=state,
                free_until=free_until,
                next_free_at=next_free_at,
                booking_url=f"https://nyu.libcal.com/space/{room_id}",
            )
        )
    # Free rooms first (longest free first), then soonest to free up, then by name.
    far = datetime.max.replace(tzinfo=now.tzinfo)
    rooms.sort(
        key=lambda r: (
            _ORDER[r.state],
            -(r.free_until - now).total_seconds() if r.free_until else 0,
            r.next_free_at or far,
            r.name,
        )
    )
    return RoomGroupStatus(
        id=snapshot.group.id,
        name=snapshot.group.name,
        free_now=sum(r.state == RoomState.free for r in rooms),
        total=len(rooms),
        rooms=rooms,
        updated_at=snapshot.slots_fetched_at,
        error=snapshot.error,
    )
