from dataclasses import dataclass
from typing import List


@dataclass(frozen=True)
class FloorInfo:
    id: str
    name: str
    capacity: int
    popularity: float = 1.0  # dummy-data only: how busy this floor runs vs average


# Placeholder capacities until we have real numbers.
FLOORS: List[FloorInfo] = [
    FloorInfo("LL2", "Lower Level 2", 250, 1.15),
    FloorInfo("LL1", "Lower Level 1", 300, 1.20),
    FloorInfo("1", "Floor 1", 200, 0.70),
    FloorInfo("2", "Floor 2", 220, 1.05),
    FloorInfo("3", "Floor 3", 220, 0.90),
    FloorInfo("4", "Floor 4", 220, 1.00),
    FloorInfo("5", "Floor 5", 220, 1.10),
    FloorInfo("6", "Floor 6", 200, 0.95),
    FloorInfo("7", "Floor 7", 200, 0.85),
    FloorInfo("8", "Floor 8", 180, 0.80),
    FloorInfo("9", "Floor 9", 180, 0.75),
    FloorInfo("10", "Floor 10", 160, 0.60),
    FloorInfo("11", "Floor 11", 160, 0.55),
    FloorInfo("12", "Floor 12", 150, 0.50),
]
