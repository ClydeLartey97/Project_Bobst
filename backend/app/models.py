from datetime import datetime
from enum import Enum
from typing import List, Optional

from pydantic import BaseModel

from app.floors import Noise


class Busyness(str, Enum):
    """Six-step scale shared by the whole building, floors and areas."""

    empty = "empty"
    quite_empty = "quite_empty"
    not_too_busy = "not_too_busy"
    busy = "busy"
    very_busy = "very_busy"
    full = "full"


class FloorNoise(str, Enum):
    quiet = "quiet"
    talkative = "talkative"
    mixed = "mixed"


class Area(BaseModel):
    id: str
    name: str
    label: str  # e.g. "5th Floor East"
    noise: Noise
    occupancy: int
    capacity: int
    fullness: float  # occupancy / capacity, clamped to 0..1
    busyness: Busyness


class Floor(BaseModel):
    id: str
    name: str
    noise: FloorNoise
    occupancy: int
    capacity: int
    fullness: float
    busyness: Busyness
    areas: List[Area]


class Building(BaseModel):
    occupancy: int
    capacity: int
    fullness: float
    busyness: Busyness


class BestSpots(BaseModel):
    """Emptiest area of each noise type right now."""

    quiet: Optional[Area]
    talkative: Optional[Area]


class BobstResponse(BaseModel):
    updated_at: datetime
    building: Building
    best_spots: BestSpots
    floors: List[Floor]
