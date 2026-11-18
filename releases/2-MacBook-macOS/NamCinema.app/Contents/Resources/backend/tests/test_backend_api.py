import uuid
import httpx
import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import AuthorizationError
from app.providers.seed import BIG_BUCK_BUNNY_ASSET_ID, TEARS_OF_STEEL_ASSET_ID
from app.providers.streaming import (
    ExternalWatchProvider,
    LicensedHlsProvider,
    PublicDemoContentProvider,
)


async def _register_and_get_headers(client: httpx.AsyncClient, email: str = "nam@namcinema.vn") -> tuple[dict[str, str], dict]:
    res = await client.post(
        "/api/v1/auth/register",
        json={
            "email": email,
            "full_name": "Nam Nguyễn",
            "password": "StrongPassword!2026",
            "preferred_language": "vi-VN",
        },
    )
    assert res.status_code == 201, res.text
    data = res.json()
    headers = {"Authorization": f"Bearer {data['access_token']}"}
    return headers, data


async def test_health_endpoints(api_client: httpx.AsyncClient) -> None:
    live = await api_client.get("/health/live")
    assert live.status_code == 200
    assert live.json()["status"] == "alive"

    ready = await api_client.get("/health/ready")
    assert ready.status_code == 200
    assert ready.json()["database"] == "connected"


async def test_authentication_register_login_refresh_and_logout(api_client: httpx.AsyncClient) -> None:
    headers, reg_data = await _register_and_get_headers(api_client, "auth_user@namcinema.vn")
    assert "password_hash" not in reg_data["user"]
    assert reg_data["user"]["email"] == "auth_user@namcinema.vn"

    # Duplicate email registration should return 409 Conflict
    dup = await api_client.post(
        "/api/v1/auth/register",
        json={
            "email": "auth_user@namcinema.vn",
            "full_name": "Duplicate",
            "password": "StrongPassword!2026",
        },
    )
    assert dup.status_code == 409

    # Current user endpoint
    me = await api_client.get("/api/v1/auth/me", headers=headers)
    assert me.status_code == 200
    assert me.json()["full_name"] == "Nam Nguyễn"

    # Login with valid credentials
    login_res = await api_client.post(
        "/api/v1/auth/login",
        json={
            "email": "auth_user@namcinema.vn",
            "password": "StrongPassword!2026",
            "device_info": "Pixel 8 Pro",
        },
    )
    assert login_res.status_code == 200
    login_tokens = login_res.json()

    # Refresh token rotation
    refresh_res = await api_client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": login_tokens["refresh_token"]},
    )
    assert refresh_res.status_code == 200
    rotated_tokens = refresh_res.json()
    assert rotated_tokens["refresh_token"] != login_tokens["refresh_token"]

    # Re-using an already rotated refresh token must fail with 401
    reuse_res = await api_client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": login_tokens["refresh_token"]},
    )
    assert reuse_res.status_code == 401

    # Logout revokes active refresh token
    logout_res = await api_client.post(
        "/api/v1/auth/logout",
        headers={"Authorization": f"Bearer {rotated_tokens['access_token']}"},
        json={"refresh_token": rotated_tokens["refresh_token"]},
    )
    assert logout_res.status_code == 200

    post_logout_refresh = await api_client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": rotated_tokens["refresh_token"]},
    )
    assert post_logout_refresh.status_code == 401


async def test_protected_routes_reject_unauthenticated_requests(api_client: httpx.AsyncClient) -> None:
    for endpoint in ("/api/v1/auth/me", "/api/v1/me/watchlist", "/api/v1/me/history"):
        res = await api_client.get(endpoint)
        assert res.status_code == 401


async def test_catalog_home_details_tv_seasons_and_search(api_client: httpx.AsyncClient) -> None:
    home_res = await api_client.get("/api/v1/home")
    assert home_res.status_code == 200
    home = home_res.json()
    assert len(home["featured_hero"]) >= 2
    assert len(home["recently_added_playable"]) >= 3
    assert len(home["trending_today"]) >= 1

    # Movie with direct legal playback (Big Buck Bunny - 10378)
    movie_playable = await api_client.get("/api/v1/movies/10378")
    assert movie_playable.status_code == 200
    mp = movie_playable.json()
    assert mp["availability"]["is_directly_playable"] is True
    assert mp["availability"]["availability_type"] == "playable"
    assert len(mp["availability"]["playable_assets"]) == 1

    # Movie available only via external watch provider (Fight Club - 550)
    movie_ext = await api_client.get("/api/v1/movies/550")
    assert movie_ext.status_code == 200
    me = movie_ext.json()
    assert me["availability"]["is_directly_playable"] is False
    assert me["availability"]["availability_type"] == "external"
    assert me["availability"]["external_providers"][0]["provider_name"] == "Netflix"

    # TV series details and season episodes
    tv_res = await api_client.get("/api/v1/tv/60625")
    assert tv_res.status_code == 200
    assert tv_res.json()["number_of_seasons"] == 1

    season_res = await api_client.get("/api/v1/tv/60625/seasons/1")
    assert season_res.status_code == 200
    episodes = season_res.json()["episodes"]
    assert len(episodes) == 2
    assert episodes[0]["is_playable"] is True
    assert episodes[1]["is_playable"] is False

    # Search
    search_res = await api_client.get("/api/v1/search", params={"q": "Big Buck", "type": "movie"})
    assert search_res.status_code == 200
    results = search_res.json()["results"]
    assert len(results) == 1
    assert results[0]["tmdb_id"] == 10378
    assert results[0]["availability_badge"] == "playable"


async def test_streaming_provider_contracts(db_session: AsyncSession) -> None:
    demo_provider = PublicDemoContentProvider(db_session)
    avail = await demo_provider.get_availability("movie:10378", "VN")
    assert len(avail) == 1
    assert avail[0]["is_directly_playable"] is True

    licensed_provider = LicensedHlsProvider(db_session)
    licensed_avail = await licensed_provider.get_availability("movie:136418", "VN")
    assert len(licensed_avail) == 1
    assert licensed_avail[0]["provider_category"] == "licensed_hls"

    ext_provider = ExternalWatchProvider(db_session)
    ext_avail = await ext_provider.get_availability("movie:550", "VN")
    assert len(ext_avail) == 1
    assert ext_avail[0]["is_directly_playable"] is False

    with pytest.raises(AuthorizationError):
        await ext_provider.create_playback_session(str(uuid.uuid4()), str(uuid.uuid4()))


async def test_playback_session_heartbeat_resume_and_end(api_client: httpx.AsyncClient) -> None:
    headers, _ = await _register_and_get_headers(api_client, "player_user@namcinema.vn")

    # Create signed HLS session for Tears of Steel
    session_res = await api_client.post(
        "/api/v1/playback/sessions",
        headers=headers,
        json={"asset_id": str(TEARS_OF_STEEL_ASSET_ID), "resume_from_history": True},
    )
    assert session_res.status_code == 201
    session_data = session_res.json()
    session_id = session_data["session_id"]
    assert "nc_sig=" in session_data["sources"][0]["manifest_url"]
    assert len(session_data["subtitles"]) == 2
    assert any(s["language_code"] == "vi" for s in session_data["subtitles"])

    # Send heartbeat saving playback progress at 185 seconds
    hb_res = await api_client.post(
        f"/api/v1/playback/sessions/{session_id}/heartbeat",
        headers=headers,
        json={"position_seconds": 185, "duration_seconds": 734, "is_paused": False},
    )
    assert hb_res.status_code == 200
    assert hb_res.json()["position_seconds"] == 185
    assert hb_res.json()["is_completed"] is False

    # End session
    end_res = await api_client.delete(
        f"/api/v1/playback/sessions/{session_id}",
        headers=headers,
    )
    assert end_res.status_code == 200

    # Creating a new session must restore resume_position_seconds == 185
    resumed_session = await api_client.post(
        "/api/v1/playback/sessions",
        headers=headers,
        json={"asset_id": str(TEARS_OF_STEEL_ASSET_ID), "resume_from_history": True},
    )
    assert resumed_session.status_code == 201
    assert resumed_session.json()["resume_position_seconds"] == 185


async def test_watchlist_and_watch_history_persistence(api_client: httpx.AsyncClient) -> None:
    headers, _ = await _register_and_get_headers(api_client, "library_user@namcinema.vn")

    # Add to watchlist
    add_res = await api_client.post(
        "/api/v1/me/watchlist",
        headers=headers,
        json={
            "tmdb_id": 10378,
            "content_type": "movie",
            "title": "Big Buck Bunny",
            "poster_path": "https://image.tmdb.org/t/p/w500/poster.jpg",
            "vote_average": 7.8,
            "release_year": "2008",
        },
    )
    assert add_res.status_code == 201
    watchlist_item_id = add_res.json()["id"]

    # Idempotent duplicate add updates existing row instead of duplicating
    dup_add = await api_client.post(
        "/api/v1/me/watchlist",
        headers=headers,
        json={
            "tmdb_id": 10378,
            "content_type": "movie",
            "title": "Big Buck Bunny",
            "vote_average": 8.0,
        },
    )
    assert dup_add.status_code == 201

    list_res = await api_client.get("/api/v1/me/watchlist", headers=headers)
    assert list_res.status_code == 200
    assert len(list_res.json()) == 1

    # Remove from watchlist
    del_res = await api_client.delete(f"/api/v1/me/watchlist/{watchlist_item_id}", headers=headers)
    assert del_res.status_code == 200
    assert (await api_client.get("/api/v1/me/watchlist", headers=headers)).json() == []

    # Update watch progress directly and verify continue watching in /api/v1/home
    prog_res = await api_client.put(
        "/api/v1/me/progress",
        headers=headers,
        json={
            "tmdb_id": 10378,
            "content_type": "movie",
            "asset_id": str(BIG_BUCK_BUNNY_ASSET_ID),
            "title": "Big Buck Bunny",
            "current_position_seconds": 120,
            "duration_seconds": 634,
        },
    )
    assert prog_res.status_code == 200
    history_id = prog_res.json()["id"]

    home_auth = await api_client.get("/api/v1/home", headers=headers)
    assert len(home_auth.json()["continue_watching"]) == 1
    assert home_auth.json()["continue_watching"][0]["current_position_seconds"] == 120

    # Delete history entry
    del_hist = await api_client.delete(f"/api/v1/me/history/{history_id}", headers=headers)
    assert del_hist.status_code == 200
    assert (await api_client.get("/api/v1/me/history", headers=headers)).json() == []
