from datetime import datetime
from zoneinfo import ZoneInfo

from app.floors import FLOORS
from app.models import BusynessLevel, Floor, FloorsResponse
from app.sources import DummySource, OccupancySource

NYC = ZoneInfo("America/New_York")

source: OccupancySource = DummySource()


def level_for(busyness: float) -> BusynessLevel:
    if busyness < 0.4:
        return BusynessLevel.quiet
    if busyness < 0.7:
        return BusynessLevel.moderate
    return BusynessLevel.busy


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
    return FloorsResponse(updated_at=now, floors=floors)
