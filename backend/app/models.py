from datetime import datetime
from enum import Enum
from typing import List

from pydantic import BaseModel


class BusynessLevel(str, Enum):
    quiet = "quiet"
    moderate = "moderate"
    busy = "busy"


class Floor(BaseModel):
    id: str
    name: str
    occupancy: int
    capacity: int
    busyness: float  # occupancy / capacity, clamped to 0..1
    level: BusynessLevel


class FloorsResponse(BaseModel):
    updated_at: datetime
    floors: List[Floor]
