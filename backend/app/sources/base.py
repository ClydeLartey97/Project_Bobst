from datetime import datetime
from typing import Dict, Protocol, Tuple

# (floor id, area id)
AreaKey = Tuple[str, str]


class OccupancySource(Protocol):
    """Anything that can report how many people are in each area right now.

    The dummy source fakes this; a real source will aggregate client counts
    from NYU's Wi-Fi access points, each mapped to a floor and area.
    """

    def occupancy_by_area(self, now: datetime) -> Dict[AreaKey, int]:
        ...
