from fastapi import APIRouter, HTTPException

from app import dev
from app.config import settings
from app.models import BobstResponse
from app.services import current_status

router = APIRouter()


@router.get("/health")
def health() -> dict:
    return {"status": "ok"}


@router.get("/status", response_model=BobstResponse)
def status() -> BobstResponse:
    return current_status(overrides=dev.settings)


def _require_dev_mode() -> None:
    if not settings.dev_mode:
        raise HTTPException(status_code=404)


@router.get("/dev/settings", response_model=dev.DevSettings)
def get_dev_settings() -> dev.DevSettings:
    _require_dev_mode()
    return dev.settings


@router.put("/dev/settings", response_model=dev.DevSettings)
def put_dev_settings(new: dev.DevSettings) -> dev.DevSettings:
    _require_dev_mode()
    dev.settings = new
    return dev.settings


@router.delete("/dev/settings", response_model=dev.DevSettings)
def reset_dev_settings() -> dev.DevSettings:
    _require_dev_mode()
    dev.settings = dev.DevSettings()
    return dev.settings
