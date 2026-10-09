from datetime import datetime
from zoneinfo import ZoneInfo

from app.floors import FLOORS
from app.models import (
    Building,
    BuildingStatus,
    BusynessLevel,
    Floor,
    FloorsResponse,
)
from app.sources import DummySource, OccupancySource

NYC = ZoneInfo("America/New_York")

# Share of total library capacity at which Bobst counts as full.
FULL_THRESHOLD = 0.8

source: OccupancySource = DummySource()


def level_for(busyness: float) -> BusynessLevel:
    if busyness < 0.4:
        return BusynessLevel.quiet
    if busyness < 0.7:
        return BusynessLevel.moderate
    return BusynessLevel.busy


def status_for(busyness: float) -> BuildingStatus:
    if busyness >= FULL_THRESHOLD:
        return BuildingStatus.full
    return BuildingStatus.available


def current_floors(now: datetime = None) -> FloorsResponse:
    now = now or datetime.now(NYC)
    counts = source.occupancy_by_floor(now)

    floors = []
    for info in FLOORS:
        occupancy = counts.get(info.id, 0)
        busyness = min(1.0, occupancy / info.capacity)
        floors.append(
            Floor(
                id=info.id,
                name=info.name,
                occupancy=occupancy,
                capacity=info.capacity,
                busyness=round(busyness, 3),
                level=level_for(busyness),
            )
        )

    occupancy = sum(f.occupancy for f in floors)
    capacity = sum(f.capacity for f in floors)
    busyness = min(1.0, occupancy / capacity)
    building = Building(
        occupancy=occupancy,
        capacity=capacity,
        busyness=round(busyness, 3),
        status=status_for(busyness),
    )
    return FloorsResponse(updated_at=now, building=building, floors=floors)
