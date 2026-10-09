from typing import List

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env")

    app_name: str = "Project Bobst API"
    cors_origins: List[str] = ["http://localhost:5173"]


settings = Settings()
