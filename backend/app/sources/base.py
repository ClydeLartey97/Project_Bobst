from datetime import datetime
from typing import Dict, Protocol


class OccupancySource(Protocol):
    """Anything that can report how many devices are on each floor right now.

    The dummy source fakes this; a real source will aggregate client counts
    from NYU's Wi-Fi access points, grouped by floor.
    """

    def occupancy_by_floor(self, now: datetime) -> Dict[str, int]:
        ...
