from fastapi import APIRouter

from app.models import FloorsResponse
from app.services import current_floors

router = APIRouter()


@router.get("/health")
def health() -> dict:
    return {"status": "ok"}


@router.get("/floors", response_model=FloorsResponse)
def floors() -> FloorsResponse:
    return current_floors()
