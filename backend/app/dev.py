"""Developer overrides for poking at the data from the app's Developer tab.

State is in memory and global to the server, so everyone pointed at this
backend sees the same tweaks. Disable with DEV_MODE=false in production.
"""

from datetime import date, datetime, time, timedelta
from typing import Annotated, Dict, Optional

from pydantic import BaseModel, Field


class DevSettings(BaseModel):
    hour: Optional[float] = Field(None, ge=0, lt=24)  # None = real time of day
    weekday: Optional[int] = Field(None, ge=0, le=6)  # 0 = Monday; None = today
    finals: Optional[bool] = None  # None = follow the real calendar
    crowd: float = Field(1.0, ge=0, le=3)  # multiplies everyone not overridden
    # floor id -> fullness 0..1, replacing that floor's data entirely
    floor_overrides: Dict[str, Annotated[float, Field(ge=0, le=1)]] = {}

    @property
    def active(self) -> bool:
        return self != DevSettings()


settings = DevSettings()


def simulated_now(real: datetime, s: DevSettings) -> datetime:
    """The moment the data should be generated for, given the overrides."""
    day = real.date()
    if s.finals is True:
        day = _same_weekday_in_week_of(day, date(day.year, 12, 14))
    elif s.finals is False:
        day = _same_weekday_in_week_of(day, date(day.year, 10, 14))
    if s.weekday is not None:
        day = _monday_of(day) + timedelta(days=s.weekday)

    clock = real.timetz()
    if s.hour is not None:
        minutes = round(s.hour * 60)
        clock = time(minutes // 60, minutes % 60, tzinfo=real.tzinfo)
    return datetime.combine(day, clock)


def _monday_of(day: date) -> date:
    return day - timedelta(days=day.weekday())


def _same_weekday_in_week_of(day: date, anchor: date) -> date:
    return _monday_of(anchor) + timedelta(days=day.weekday())
