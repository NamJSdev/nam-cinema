from contextlib import asynccontextmanager
from pathlib import Path
from typing import Any

from fastapi import Depends, FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.router import api_v1_router
from app.core.cache import cache_backend
from app.core.config import get_settings
from app.core.exceptions import register_exception_handlers
from app.core.logging import configure_logging
from app.db.base import Base
from app.db.session import AsyncSessionLocal, engine, get_db_session
import app.models  # noqa: F401
from app.providers.seed import seed_verified_legal_assets
from app.services.tmdb import tmdb_client


@asynccontextmanager
async def lifespan(_: FastAPI):
    settings = get_settings()
    configure_logging(debug=settings.DEBUG)
    await cache_backend.connect()
    try:
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
        async with AsyncSessionLocal() as session:
            await seed_verified_legal_assets(session)
    except Exception:
        # Tables may not be migrated yet during CLI inspection; seeding runs once tables exist
        pass
    yield
    await cache_backend.close()


def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(
        title=settings.APP_NAME,
        description="Nam Cinema — Your Cinema. Anywhere. Production Cross-Platform Streaming API.",
        version="1.0.0",
        lifespan=lifespan,
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origin_list,
        allow_credentials=True,
        allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
        allow_headers=["Authorization", "Content-Type", "Accept"],
    )

    register_exception_handlers(app)
    app.include_router(api_v1_router)

    static_dir = Path(__file__).resolve().parent.parent / "static"
    releases_dir = Path(__file__).resolve().parent.parent.parent / "releases"
    if static_dir.exists():
        app.mount("/static", StaticFiles(directory=str(static_dir)), name="static")
    if releases_dir.exists():
        app.mount("/releases", StaticFiles(directory=str(releases_dir)), name="releases")

    @app.get("/", include_in_schema=False)
    @app.get("/install", include_in_schema=False)
    async def web_preview_portal() -> FileResponse:
        return FileResponse(str(static_dir / "preview.html"))

    @app.get("/favicon.ico", include_in_schema=False)
    async def web_favicon() -> FileResponse:
        return FileResponse(str(static_dir / "favicon.ico"))

    @app.get("/download/windows", include_in_schema=False)
    async def download_windows_pkg() -> FileResponse:
        return FileResponse(
            str(releases_dir / "NamCinema-Windows-Installer.zip"),
            filename="NamCinema-Windows-Installer.zip",
            media_type="application/zip",
        )

    @app.get("/download/macbook", include_in_schema=False)
    async def download_macbook_pkg() -> FileResponse:
        return FileResponse(
            str(releases_dir / "NamCinema-MacBook-macOS.zip"),
            filename="NamCinema-MacBook-macOS.zip",
            media_type="application/zip",
        )

    @app.get("/download/android", include_in_schema=False)
    async def download_android_pkg() -> FileResponse:
        return FileResponse(
            str(releases_dir / "NamCinema-Android-Package.zip"),
            filename="NamCinema-Android-Package.zip",
            media_type="application/zip",
        )

    @app.get("/download/iphone", include_in_schema=False)
    async def download_iphone_profile() -> FileResponse:
        return FileResponse(
            str(releases_dir / "4-iPhone-iOS" / "NamCinema-iPhone-Installer.mobileconfig"),
            filename="NamCinema-iPhone-Installer.mobileconfig",
            media_type="application/x-apple-aspen-config",
        )

    @app.get("/download/lgtv", include_in_schema=False)
    async def download_lgtv_ipk() -> FileResponse:
        return FileResponse(
            str(releases_dir / "5-LG-WebOS-TV" / "com.namcinema.app_1.0.0_all.ipk"),
            filename="com.namcinema.app_1.0.0_all.ipk",
            media_type="application/vnd.webos.ipk",
        )

    @app.get("/health/live", tags=["Health"])
    async def health_live() -> dict[str, str]:
        return {"status": "alive", "service": "nam-cinema-backend"}

    @app.get("/health/ready", tags=["Health"])
    async def health_ready(db: AsyncSession = Depends(get_db_session)) -> dict[str, Any]:
        db_ok = False
        try:
            await db.execute(text("SELECT 1"))
            db_ok = True
        except Exception:
            db_ok = False

        cache_status = await cache_backend.is_healthy()
        return {
            "status": "ready" if db_ok else "degraded",
            "database": "connected" if db_ok else "unreachable",
            "cache": cache_status,
            "tmdb_configured": tmdb_client.is_configured,
        }

    return app


app = create_app()
