"""Keeps an in-memory copy of Bobst study room availability fresh."""

import asyncio
import logging
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from typing import Dict, List, Optional

from app.rooms.libcal import (
    BOBST_GROUPS,
    NYC,
    LibCalClient,
    RoomGroup,
    RoomInfo,
    Slot,
)

log = logging.getLogger(__name__)

REQUEST_SPACING = 10  # seconds; LibCal's robots.txt Crawl-delay
ROOM_LIST_TTL = timedelta(hours=6)


@dataclass
class GroupSnapshot:
    group: RoomGroup
    rooms: Dict[int, RoomInfo] = field(default_factory=dict)
    slots: Dict[int, List[Slot]] = field(default_factory=dict)
    rooms_fetched_at: Optional[datetime] = None
    slots_fetched_at: Optional[datetime] = None
    error: Optional[str] = None


class RoomIngester:
    def __init__(
        self,
        client: LibCalClient,
        groups: List[RoomGroup] = BOBST_GROUPS,
        refresh_every: float = 300,
    ):
        self.client = client
        self.refresh_every = refresh_every
        self.snapshots: Dict[int, GroupSnapshot] = {
            g.id: GroupSnapshot(g) for g in groups
        }
        self._task: Optional[asyncio.Task] = None
        self._requests_made = 0

    def start(self) -> None:
        self._task = asyncio.create_task(self._run())

    async def stop(self) -> None:
        if self._task:
            self._task.cancel()
        await self.client.aclose()

    async def _run(self) -> None:
        while True:
            await self.refresh_all(spacing=REQUEST_SPACING)
            await asyncio.sleep(self.refresh_every)

    async def refresh_all(self, spacing: float = 0) -> None:
        self._spacing = spacing
        self._requests_made = 0
        for snapshot in self.snapshots.values():
            if await self._refresh_rooms(snapshot) is False:
                continue
            if await self._refresh_slots(snapshot) is False:
                continue
            await self._fill_missing_rooms(snapshot)

    async def _pace(self) -> None:
        """Wait between requests so we never hit LibCal faster than allowed."""
        if self._requests_made:
            await asyncio.sleep(self._spacing)
        self._requests_made += 1

    async def _refresh_rooms(self, snapshot: GroupSnapshot) -> Optional[bool]:
        """Room lists rarely change, so only refetch every few hours."""
        now = datetime.now(NYC)
        fresh = snapshot.rooms_fetched_at and now - snapshot.rooms_fetched_at < ROOM_LIST_TTL
        if fresh:
            return None
        await self._pace()
        try:
            snapshot.rooms = await self.client.fetch_rooms(snapshot.group)
            snapshot.rooms_fetched_at = now
            snapshot.error = None
        except Exception as e:  # keep serving the last good data
            log.warning("LibCal rooms fetch failed for %s: %s", snapshot.group.name, e)
            snapshot.error = str(e)
            return False
        return True

    async def _refresh_slots(self, snapshot: GroupSnapshot) -> Optional[bool]:
        now = datetime.now(NYC)
        await self._pace()
        try:
            # Two days out so "free until" can run past midnight.
            snapshot.slots = await self.client.fetch_slots(
                snapshot.group, now.date(), now.date() + timedelta(days=2)
            )
            snapshot.slots_fetched_at = now
            snapshot.error = None
        except Exception as e:
            log.warning("LibCal slots fetch failed for %s: %s", snapshot.group.name, e)
            snapshot.error = str(e)
            return False
        return True

    async def _fill_missing_rooms(self, snapshot: GroupSnapshot) -> None:
        """Some bookable rooms aren't on the listing page; look them up once."""
        for eid in sorted(set(snapshot.slots) - set(snapshot.rooms)):
            await self._pace()
            try:
                info = await self.client.fetch_room(eid)
            except Exception as e:
                log.warning("LibCal room %s lookup failed: %s", eid, e)
                continue
            if info:
                snapshot.rooms[eid] = info


ingester: Optional[RoomIngester] = None
