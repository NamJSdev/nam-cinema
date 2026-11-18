from collections.abc import AsyncGenerator
import os
from typing import Any

import httpx
import pytest
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

os.environ["DATABASE_URL"] = "sqlite+aiosqlite:///./test_nam_cinema.db"
os.environ["REDIS_ENABLED"] = "false"
os.environ["PERSONAL_MODE_ENABLED"] = "false"
os.environ["TMDB_API_KEY"] = "test_tmdb_api_key_for_contract_tests"
os.environ["JWT_SECRET_KEY"] = "test-only-jwt-secret-key-with-more-than-thirty-two-bytes-length-123"
os.environ["PLAYBACK_SIGNING_SECRET"] = "test-only-playback-signing-secret-key-more-than-32-bytes-123"

from app.core.config import get_settings
get_settings.cache_clear()

from app.db.base import Base
from app.db.session import build_async_engine, get_db_session
from app.main import create_app
from app.models.entities import ProviderMapping
from app.providers.seed import seed_verified_legal_assets
import app.services.tmdb as tmdb_module


def _mock_tmdb_transport(request: httpx.Request) -> httpx.Response:
    path = request.url.path
    if path.endswith("/trending/movie/day") or path.endswith("/movie/popular") or path.endswith("/movie/top_rated") or path.endswith("/discover/movie"):
        return httpx.Response(
            200,
            json={
                "page": 1,
                "total_pages": 2,
                "total_results": 2,
                "results": [
                    {
                        "id": 10378,
                        "title": "Big Buck Bunny",
                        "original_title": "Big Buck Bunny",
                        "overview": "Open movie by Blender Foundation.",
                        "poster_path": "/poster_bbb.jpg",
                        "backdrop_path": "/backdrop_bbb.jpg",
                        "release_date": "2008-05-30",
                        "vote_average": 7.8,
                        "vote_count": 950,
                        "genre_ids": [16, 35],
                    },
                    {
                        "id": 550,
                        "title": "Fight Club",
                        "original_title": "Fight Club",
                        "overview": "An insomniac office worker and a devil-may-care soapmaker.",
                        "poster_path": "/poster_fc.jpg",
                        "backdrop_path": "/backdrop_fc.jpg",
                        "release_date": "1999-10-15",
                        "vote_average": 8.4,
                        "vote_count": 28000,
                        "genre_ids": [18],
                    },
                ],
            },
        )
    if path.endswith("/tv/popular"):
        return httpx.Response(
            200,
            json={
                "page": 1,
                "total_pages": 1,
                "total_results": 1,
                "results": [
                    {
                        "id": 60625,
                        "name": "Open Sci-Fi Chronicles",
                        "original_name": "Open Sci-Fi Chronicles",
                        "overview": "Sci-fi adventures.",
                        "poster_path": "/tv_poster.jpg",
                        "backdrop_path": "/tv_backdrop.jpg",
                        "first_air_date": "2024-01-01",
                        "vote_average": 8.7,
                        "vote_count": 4100,
                        "genre_ids": [16, 10765],
                    }
                ],
            },
        )
    if "/movie/" in path:
        movie_id = int(path.rstrip("/").split("/")[-1])
        return httpx.Response(
            200,
            json={
                "id": movie_id,
                "title": "Big Buck Bunny" if movie_id == 10378 else "External Provider Movie",
                "original_title": "Big Buck Bunny" if movie_id == 10378 else "External Provider Movie",
                "overview": "Detailed movie synopsis from TMDB.",
                "poster_path": "/poster.jpg",
                "backdrop_path": "/backdrop.jpg",
                "release_date": "2008-05-30",
                "runtime": 12,
                "vote_average": 8.1,
                "vote_count": 1200,
                "genres": [{"id": 16, "name": "Animation"}],
                "credits": {
                    "cast": [{"id": 1, "name": "Sacha Goedegebure", "character": "Big Buck Bunny", "profile_path": "/cast.jpg"}],
                    "crew": [{"id": 2, "name": "Sacha Goedegebure", "job": "Director"}],
                },
                "videos": {
                    "results": [{"id": "vid1", "key": "YE7VzlLtp-4", "name": "Official Trailer", "site": "YouTube", "type": "Trailer"}]
                },
                "recommendations": {"page": 1, "total_pages": 1, "total_results": 0, "results": []},
                "similar": {"page": 1, "total_pages": 1, "total_results": 0, "results": []},
                "watch/providers": {
                    "results": {
                        "VN": {
                            "link": "https://www.themoviedb.org/movie/550/watch?locale=VN",
                            "flatrate": [{"provider_id": 8, "provider_name": "Netflix", "logo_path": "/netflix.jpg"}],
                        }
                    }
                },
            },
        )
    if "/season/" in path:
        return httpx.Response(
            200,
            json={
                "id": 101,
                "season_number": 1,
                "name": "Season 1",
                "overview": "First season overview.",
                "poster_path": "/s1.jpg",
                "episodes": [
                    {
                        "id": 1001,
                        "episode_number": 1,
                        "season_number": 1,
                        "name": "Tập 1: Khởi Nguyên",
                        "overview": "Episode 1 synopsis.",
                        "still_path": "/ep1.jpg",
                        "air_date": "2024-01-01",
                        "runtime": 12,
                        "vote_average": 8.8,
                    },
                    {
                        "id": 1002,
                        "episode_number": 2,
                        "season_number": 1,
                        "name": "Tập 2: Hành Trình",
                        "overview": "Episode 2 synopsis.",
                        "still_path": "/ep2.jpg",
                        "air_date": "2024-01-08",
                        "runtime": 24,
                        "vote_average": 8.5,
                    },
                ],
            },
        )
    if "/tv/" in path:
        tv_id = int(path.rstrip("/").split("/")[-1])
        return httpx.Response(
            200,
            json={
                "id": tv_id,
                "name": "Open Sci-Fi Chronicles",
                "original_name": "Open Sci-Fi Chronicles",
                "overview": "TV series overview.",
                "poster_path": "/tv.jpg",
                "backdrop_path": "/tv_bg.jpg",
                "first_air_date": "2024-01-01",
                "number_of_seasons": 1,
                "number_of_episodes": 2,
                "vote_average": 8.7,
                "vote_count": 900,
                "genres": [{"id": 10765, "name": "Sci-Fi & Fantasy"}],
                "seasons": [
                    {
                        "id": 101,
                        "season_number": 1,
                        "name": "Season 1",
                        "episode_count": 2,
                        "overview": "Season 1",
                        "poster_path": "/s1.jpg",
                        "air_date": "2024-01-01",
                    }
                ],
                "credits": {"cast": []},
                "videos": {"results": []},
                "recommendations": {"results": []},
                "similar": {"results": []},
                "watch/providers": {"results": {}},
            },
        )
    if "/search/" in path:
        return httpx.Response(
            200,
            json={
                "page": 1,
                "total_pages": 1,
                "total_results": 1,
                "results": [
                    {
                        "id": 10378,
                        "media_type": "movie",
                        "title": "Big Buck Bunny",
                        "original_title": "Big Buck Bunny",
                        "overview": "Search result.",
                        "poster_path": "/poster_bbb.jpg",
                        "backdrop_path": "/backdrop_bbb.jpg",
                        "release_date": "2008-05-30",
                        "vote_average": 7.8,
                        "vote_count": 950,
                        "genre_ids": [16, 35],
                    }
                ],
            },
        )
    if "/genre/" in path:
        return httpx.Response(
            200,
            json={"genres": [{"id": 16, "name": "Hoạt Hình"}, {"id": 28, "name": "Hành Động"}]},
        )
    return httpx.Response(404, json={"status_message": "Not found"})


@pytest.fixture
async def db_session() -> AsyncGenerator[AsyncSession, None]:
    test_engine = build_async_engine("sqlite+aiosqlite:///:memory:")
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    session_maker = async_sessionmaker(test_engine, class_=AsyncSession, expire_on_commit=False)
    async with session_maker() as session:
        await seed_verified_legal_assets(session)
        session.add(
            ProviderMapping(
                tmdb_id=550,
                content_type="movie",
                region="VN",
                provider_type="external_watch_provider",
                provider_name="Netflix",
                monetization_type="flatrate",
                logo_path="https://image.tmdb.org/t/p/w185/netflix.jpg",
                external_watch_url="https://www.themoviedb.org/movie/550/watch?locale=VN",
            )
        )
        await session.commit()
        yield session

    await test_engine.dispose()


@pytest.fixture
async def api_client(db_session: AsyncSession) -> AsyncGenerator[httpx.AsyncClient, None]:
    mock_http = httpx.AsyncClient(transport=httpx.MockTransport(_mock_tmdb_transport))
    tmdb_module.tmdb_client._external_client = mock_http

    app = create_app()

    async def _override_db() -> AsyncGenerator[AsyncSession, None]:
        yield db_session

    app.dependency_overrides[get_db_session] = _override_db

    async with httpx.AsyncClient(
        transport=httpx.ASGITransport(app=app),
        base_url="http://testserver",
    ) as client:
        yield client

    tmdb_module.tmdb_client._external_client = None
    await mock_http.aclose()
