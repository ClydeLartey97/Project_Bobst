from datetime import datetime
from typing import List, Optional
from zoneinfo import ZoneInfo

from app.floors import FLOORS, Noise
from app.models import (
    Area,
    BestSpots,
    BobstResponse,
    Building,
    Busyness,
    Floor,
    FloorNoise,
)
from app.sources import DummySource, OccupancySource

NYC = ZoneInfo("America/New_York")

# Upper bound (exclusive) of fullness for each step; anything above is full.
BUSYNESS_SCALE = [
    (0.15, Busyness.empty),
    (0.35, Busyness.quite_empty),
    (0.55, Busyness.not_too_busy),
    (0.75, Busyness.busy),
    (0.90, Busyness.very_busy),
]

source: OccupancySource = DummySource()


def busyness_for(fullness: float) -> Busyness:
    for upper, level in BUSYNESS_SCALE:
        if fullness < upper:
            return level
    return Busyness.full


def _fullness(occupancy: int, capacity: int) -> float:
    return round(min(1.0, occupancy / capacity), 3)


def _floor_noise(areas: List[Area]) -> FloorNoise:
    kinds = {a.noise for a in areas}
    if kinds == {Noise.quiet}:
        return FloorNoise.quiet
    if kinds == {Noise.talkative}:
        return FloorNoise.talkative
    return FloorNoise.mixed


def _emptiest(areas: List[Area], noise: Noise) -> Optional[Area]:
    candidates = [a for a in areas if a.noise == noise]
    return min(candidates, key=lambda a: a.fullness, default=None)


def current_status(now: datetime = None) -> BobstResponse:
    now = now or datetime.now(NYC)
    counts = source.occupancy_by_area(now)

    floors = []
    for info in FLOORS:
        areas = []
        for area in info.areas:
            occupancy = counts.get((info.id, area.id), 0)
            fullness = _fullness(occupancy, area.capacity)
            areas.append(
                Area(
                    id=area.id,
                    name=area.name,
                    label=f"{info.short_name} {area.name}",
                    noise=area.noise,
                    occupancy=occupancy,
                    capacity=area.capacity,
                    fullness=fullness,
                    busyness=busyness_for(fullness),
                )
            )
        occupancy = sum(a.occupancy for a in areas)
        fullness = _fullness(occupancy, info.capacity)
        floors.append(
            Floor(
                id=info.id,
                name=info.name,
                noise=_floor_noise(areas),
                occupancy=occupancy,
                capacity=info.capacity,
                fullness=fullness,
                busyness=busyness_for(fullness),
                areas=areas,
            )
        )

    occupancy = sum(f.occupancy for f in floors)
    capacity = sum(f.capacity for f in floors)
    fullness = _fullness(occupancy, capacity)
    all_areas = [a for f in floors for a in f.areas]

    return BobstResponse(
        updated_at=now,
        building=Building(
            occupancy=occupancy,
            capacity=capacity,
            fullness=fullness,
            busyness=busyness_for(fullness),
        ),
        best_spots=BestSpots(
            quiet=_emptiest(all_areas, Noise.quiet),
            talkative=_emptiest(all_areas, Noise.talkative),
        ),
        floors=floors,
    )
