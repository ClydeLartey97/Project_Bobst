from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.routes import router
from app.config import settings
from app.rooms import ingest
from app.rooms.libcal import LibCalClient


@asynccontextmanager
async def lifespan(app: FastAPI):
    if settings.rooms_ingest:
        ingest.ingester = ingest.RoomIngester(LibCalClient())
        ingest.ingester.start()
    yield
    if ingest.ingester:
        await ingest.ingester.stop()
        ingest.ingester = None


app = FastAPI(title=settings.app_name, lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(router, prefix="/api")
