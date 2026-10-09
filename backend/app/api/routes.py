from fastapi import APIRouter

from app.models import BobstResponse
from app.services import current_status

router = APIRouter()


@router.get("/health")
def health() -> dict:
    return {"status": "ok"}


@router.get("/status", response_model=BobstResponse)
def status() -> BobstResponse:
    return current_status()
