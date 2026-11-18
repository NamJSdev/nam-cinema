from functools import lru_cache
from pathlib import Path
from typing import List

from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=(".env", "../.env"),
        env_file_encoding="utf-8",
        extra="ignore",
    )

    APP_NAME: str = "Nam Cinema API"
    APP_ENV: str = "development"
    DEBUG: bool = True
    PERSONAL_MODE_ENABLED: bool = True
    HOST: str = "0.0.0.0"
    PORT: int = 8000
    PUBLIC_BASE_URL: str = "http://localhost:8000"

    CORS_ORIGINS: str = "*"

    # Database: SQLite by default for zero-config cloud/local deployment; supports PostgreSQL via env var
    DATABASE_URL: str = "sqlite+aiosqlite:///./nam_cinema_dev.db"

    # Redis
    REDIS_URL: str = "redis://localhost:6379/0"
    REDIS_ENABLED: bool = False
    METADATA_CACHE_TTL_SECONDS: int = 900

    # JWT & Playback Signing
    JWT_SECRET_KEY: str = "nam-cinema-dev-only-jwt-secret-key-replace-in-production-64b-min"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30
    PLAYBACK_SIGNING_SECRET: str = "nam-cinema-dev-only-playback-signing-secret-replace-in-prod-64b"
    PLAYBACK_SESSION_TTL_MINUTES: int = 240

    # Rate Limiting
    LOGIN_RATE_LIMIT_REQUESTS: int = 10
    LOGIN_RATE_LIMIT_WINDOW_SECONDS: int = 60

    # TMDB Configuration
    TMDB_API_KEY: str = ""
    TMDB_READ_ACCESS_TOKEN: str = ""
    TMDB_BASE_URL: str = "https://api.themoviedb.org/3"
    TMDB_IMAGE_BASE_URL: str = "https://image.tmdb.org/t/p"
    DEFAULT_LANGUAGE: str = "vi-VN"
    DEFAULT_REGION: str = "VN"

    # VSMOV Primary Catalog Configuration
    VSMOV_BASE_URL: str = "https://vsmov.com/api"
    VSMOV_TIMEOUT_SECONDS: float = 12.0
    VSMOV_CACHE_TTL_SECONDS: int = 600

    @property
    def cors_origin_list(self) -> List[str]:
        return [origin.strip() for origin in self.CORS_ORIGINS.split(",") if origin.strip()]

    @property
    def has_tmdb_credentials(self) -> bool:
        return bool(self.TMDB_API_KEY.strip() or self.TMDB_READ_ACCESS_TOKEN.strip())

    @field_validator("JWT_SECRET_KEY")
    @classmethod
    def validate_jwt_secret(cls, value: str) -> str:
        if len(value.strip()) < 32:
            raise ValueError("JWT_SECRET_KEY must be at least 32 characters long.")
        return value


@lru_cache
def get_settings() -> Settings:
    return Settings()
