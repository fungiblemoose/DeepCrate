"""Configuration loaded from .env file."""

from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
    )

    openai_api_key: str = ""
    openai_model: str = "gpt-4o-mini"
    spotify_client_id: str = ""
    spotify_client_secret: str = ""
    database_path: str = "data/deepcrate.sqlite"

    def db_path(self) -> Path:
        return Path(self.database_path)


def get_settings() -> Settings:
    return Settings()
