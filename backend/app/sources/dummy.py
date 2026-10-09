import math
import random
from datetime import date, datetime
from typing import Dict

from app.floors import FLOORS, Noise
from app.sources.base import AreaKey

# Typical share of seats taken by hour of day (NYC time), weekday, term time.
_HOURLY_CURVE = [
    0.12, 0.09, 0.06, 0.04, 0.03, 0.03, 0.04, 0.08,  # 00-07
    0.18, 0.32, 0.46, 0.58, 0.64, 0.74, 0.86, 0.92,  # 08-15
    0.90, 0.84, 0.76, 0.76, 0.72, 0.60, 0.44, 0.24,  # 16-23
]

# Finals: Bobst is packed for two weeks every December and May.
_FINALS = [((12, 8), (12, 21)), ((5, 4), (5, 17))]


class DummySource:
    """Fake occupancy that drifts smoothly minute to minute.

    Built from: a daily curve, weekday/weekend and finals multipliers, a dip
    as people leave for class just before each hour, and slow per-area waves
    so areas rise and fall independently instead of jumping.
    """

    def occupancy_by_area(self, now: datetime) -> Dict[AreaKey, int]:
        minutes = now.timestamp() / 60
        base = (
            _daily_curve(now.hour + now.minute / 60)
            * _day_factor(now)
            * _finals_factor(now.date())
        )
        class_dip = _class_change_dip(now.minute)

        result = {}
        for floor in FLOORS:
            for area in floor.areas:
                wave = _area_wave(f"{floor.id}:{area.id}", minutes)
                share = base * area.popularity + wave
                # Talkative spaces empty out more between classes.
                share -= class_dip * (1.5 if area.noise == Noise.talkative else 0.7)
                share = min(max(share, 0.0), 1.05)
                result[(floor.id, area.id)] = round(area.capacity * share)
        return result


def _daily_curve(hour: float) -> float:
    lo = math.floor(hour) % 24
    hi = (lo + 1) % 24
    frac = hour - math.floor(hour)
    return _HOURLY_CURVE[lo] * (1 - frac) + _HOURLY_CURVE[hi] * frac


def _day_factor(now: datetime) -> float:
    weekday = now.weekday()
    if weekday == 5:  # Saturday
        return 0.6
    if weekday == 6:  # Sunday: quiet morning, busy evening cram
        return 0.65 if now.hour < 14 else 0.95
    if weekday == 4 and now.hour >= 15:  # Friday afternoon
        return 0.75
    return 1.0


def _finals_factor(day: date) -> float:
    for (m1, d1), (m2, d2) in _FINALS:
        if date(day.year, m1, d1) <= day <= date(day.year, m2, d2):
            return 1.2
    return 1.0


def _class_change_dip(minute: int) -> float:
    # Peaks at :50 as people head to classes starting on the hour.
    distance = min(abs(minute - 50), 60 - abs(minute - 50))
    return 0.06 * math.exp(-(distance ** 2) / 50)


def _area_wave(key: str, minutes: float) -> float:
    """Smooth, area-specific wobble of about ±8%."""
    rng = random.Random(key)
    total = 0.0
    for period, amplitude in ((23, 0.025), (61, 0.03), (157, 0.035)):
        phase = rng.uniform(0, 2 * math.pi)
        total += amplitude * math.sin(2 * math.pi * minutes / period + phase)
    return total
