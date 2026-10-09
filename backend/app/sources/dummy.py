import math
import random
from datetime import datetime
from typing import Dict

from app.floors import FLOORS

# Rough share of each floor's capacity in use, by hour of day (NYC time).
_HOURLY_CURVE = [
    0.10, 0.08, 0.06, 0.04, 0.03, 0.03, 0.04, 0.08,  # 00-07
    0.20, 0.35, 0.50, 0.60, 0.65, 0.70, 0.78, 0.82,  # 08-15
    0.80, 0.75, 0.70, 0.72, 0.68, 0.55, 0.40, 0.22,  # 16-23
]


class DummySource:
    """Believable fake occupancy: a daily curve, per-floor bias and noise.

    Values are stable within a 5-minute window so repeated requests agree.
    """

    def occupancy_by_floor(self, now: datetime) -> Dict[str, int]:
        bucket = int(now.timestamp() // 300)
        hour = now.hour + now.minute / 60
        base = _interpolate(hour)
        if now.weekday() >= 5:
            base *= 0.75

        result = {}
        for floor in FLOORS:
            rng = random.Random(f"{floor.id}:{bucket}")
            share = base * floor.popularity + rng.uniform(-0.08, 0.08)
            result[floor.id] = max(0, round(floor.capacity * share))
        return result


def _interpolate(hour: float) -> float:
    lo = math.floor(hour) % 24
    hi = (lo + 1) % 24
    frac = hour - math.floor(hour)
    return _HOURLY_CURVE[lo] * (1 - frac) + _HOURLY_CURVE[hi] * frac
