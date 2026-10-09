"""Bobst's study floors and the areas within them.

Layout is from the NYU Libraries self-guided tour
(https://guides.nyu.edu/bobst-library-tour) plus first-hand knowledge.
Left out on purpose: Floor 2 (Special Collections and classrooms, not really
study space), Floor 3 (closed for renovation) and Floors 11-12 (staff only).

Capacities are placeholder estimates until we have real seat counts.
"""

from dataclasses import dataclass
from enum import Enum
from typing import List, Tuple


class Noise(str, Enum):
    quiet = "quiet"
    talkative = "talkative"


@dataclass(frozen=True)
class AreaInfo:
    id: str
    name: str
    capacity: int
    noise: Noise
    popularity: float = 1.0  # dummy-data only: how busy this area runs vs average


@dataclass(frozen=True)
class FloorInfo:
    id: str
    name: str
    short_name: str  # used to build area labels like "5th Floor East"
    areas: Tuple[AreaInfo, ...]

    @property
    def capacity(self) -> int:
        return sum(a.capacity for a in self.areas)


Q, T = Noise.quiet, Noise.talkative


def _sides(*names: str, capacity: int, noise: Noise, popularity: float = 1.0):
    return tuple(
        AreaInfo(n.lower(), n, capacity, noise, popularity) for n in names
    )


# Top of the building first, like an elevator panel.
FLOORS: List[FloorInfo] = [
    FloorInfo("10", "10th Floor", "10th Floor", (
        AreaInfo("north-reading-room", "North Reading Room", 120, Q, 1.15),
        AreaInfo("grad-exchange", "Graduate Exchange", 60, T, 0.85),
    )),
    FloorInfo("9", "9th Floor", "9th Floor",
              _sides("East", "West", "South", capacity=70, noise=Q, popularity=1.1)),
    FloorInfo("8", "8th Floor", "8th Floor", (
        AreaInfo("north-reading-room", "North Reading Room", 120, Q, 1.15),
    ) + _sides("East", "West", "South", capacity=70, noise=Q, popularity=1.05)),
    FloorInfo("7", "7th Floor", "7th Floor", (
        AreaInfo("media-rooms", "Media Rooms", 50, T, 0.8),
    ) + _sides("East", "West", "South", capacity=50, noise=T, popularity=0.9)),
    FloorInfo("6", "6th Floor", "6th Floor", (
        AreaInfo("north-reading-room", "North Reading Room", 120, Q, 1.1),
    ) + _sides("East", "West", "South", capacity=70, noise=Q)),
    FloorInfo("5", "5th Floor", "5th Floor", (
        AreaInfo("research-commons", "Research Commons", 90, T, 1.2),
    ) + _sides("East", "West", capacity=70, noise=T, popularity=1.1)),
    FloorInfo("4", "4th Floor", "4th Floor", (
        AreaInfo("north-reading-room", "North Reading Room", 120, Q, 1.05),
    ) + _sides("East", "West", "South", capacity=70, noise=Q, popularity=0.95)),
    FloorInfo("M", "Mezzanine", "Mezzanine", (
        AreaInfo("tables", "Tables", 60, T, 0.9),
    )),
    FloorInfo("1", "1st Floor", "1st Floor", (
        AreaInfo("atrium", "Atrium", 80, T, 0.9),
        AreaInfo("gallery", "Gallery", 60, T, 0.95),
        AreaInfo("south-study", "South Study Area", 80, T, 1.1),
    )),
    FloorInfo("LL1", "Lower Level 1", "LL1", (
        AreaInfo("open-seating", "Open Seating", 140, T, 1.15),
        AreaInfo("reading-room", "Reading Room", 80, Q, 1.1),
        AreaInfo("group-rooms", "Group Study Rooms", 60, T, 1.0),
    )),
    FloorInfo("LL2", "Lower Level 2", "LL2", (
        AreaInfo("open-seating", "Open Seating", 140, T, 1.1),
        AreaInfo("study-rooms", "Study Rooms & Pods", 50, Q, 1.15),
    )),
]
