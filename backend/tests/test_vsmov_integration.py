import httpx
import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ExternalServiceError
from app.providers.vsmov import VsmovProvider
from app.services.catalog import CatalogService


async def test_live_vsmov_all_10_endpoints() -> None:
    """Tests all 10 required live VSMOV endpoints and validates response schemas."""
    provider = VsmovProvider()

    # 1. GET /danh-sach/phim-moi-cap-nhat?page=1
    newly = await provider.get_newly_updated(page=1)
    assert newly.status is True
    assert len(newly.items) > 0
    assert newly.pagination.currentPage == 1
    assert newly.pagination.totalPages >= 1
    first_item = newly.items[0]
    assert first_item.slug
    assert first_item.name
    normalized_poster = provider.normalize_image_url(first_item.poster_url, newly.pathImage)
    assert normalized_poster is not None and normalized_poster.startswith("https://")

    # 2. GET /danh-sach?page=1&limit=24
    catalog_p1 = await provider.get_catalog_list(page=1, limit=24)
    assert len(catalog_p1.items) == 24
    assert catalog_p1.pagination.currentPage == 1

    # Pagination check: page 2 must return page 2
    catalog_p2 = await provider.get_catalog_list(page=2, limit=24)
    assert catalog_p2.pagination.currentPage == 2
    assert catalog_p2.items[0].slug != catalog_p1.items[0].slug

    # 3. GET /danh-sach?type=single
    singles = await provider.get_single_movies(page=1, limit=12)
    assert len(singles.items) > 0
    single_slug = singles.items[0].slug

    # 4. GET /danh-sach?type=series
    series = await provider.get_series_movies(page=1, limit=12)
    assert len(series.items) > 0
    series_slug = series.items[0].slug

    # 5. GET /tim-kiem?keyword={keyword}&page=1&limit=24
    search_res = await provider.search_movies(keyword="anh", page=1, limit=24)
    assert len(search_res.items) > 0
    assert search_res.pagination.currentPage == 1

    # 6. GET /phim/{slug} (single movie & series with episodes)
    single_detail = await provider.get_movie_detail(single_slug)
    assert single_detail.movie is not None
    assert single_detail.movie.slug == single_slug
    assert single_detail.movie.name

    series_detail = await provider.get_movie_detail(series_slug)
    assert series_detail.movie is not None
    assert series_detail.movie.slug == series_slug
    assert len(series_detail.episodes) >= 1
    assert len(series_detail.episodes[0].server_data) >= 1

    # 7. GET /the-loai
    categories = await provider.get_categories()
    assert len(categories) > 5
    cat_slug = categories[0].slug
    assert cat_slug

    # 8. GET /quoc-gia
    countries = await provider.get_countries()
    assert len(countries) > 5
    country_slug = next((c.slug for c in countries if c.slug == "han-quoc"), countries[0].slug)
    assert country_slug

    # 9. GET /the-loai/{slug}
    by_cat = await provider.get_movies_by_category(cat_slug, page=1, limit=12)
    assert by_cat.pagination.currentPage == 1
    assert len(by_cat.items) > 0

    # 10. GET /quoc-gia/{slug}
    by_country = await provider.get_movies_by_country(country_slug, page=1, limit=12)
    assert by_country.pagination.currentPage == 1
    assert len(by_country.items) > 0


async def test_fastapi_vsmov_endpoints_and_playback_safety(
    api_client: httpx.AsyncClient,
    db_session: AsyncSession,
) -> None:
    """Verifies FastAPI endpoints serving VSMOV catalog data, genres, countries,
    movie/TV details by slug, and strict playback authorization boundaries.
    """
    # Genres & Countries endpoints
    genres_res = await api_client.get("/api/v1/genres")
    assert genres_res.status_code == 200
    genres = genres_res.json()
    assert len(genres) > 5
    assert "slug" in genres[0]

    countries_res = await api_client.get("/api/v1/countries")
    assert countries_res.status_code == 200
    countries = countries_res.json()
    assert len(countries) > 5
    assert any(c["slug"] == "han-quoc" for c in countries)

    # Filter by genre slug and country slug
    genre_movies = await api_client.get(f"/api/v1/genres/{genres[0]['slug']}?page=1&limit=6")
    assert genre_movies.status_code == 200
    assert len(genre_movies.json()["results"]) > 0

    country_movies = await api_client.get("/api/v1/countries/han-quoc?page=1&limit=6")
    assert country_movies.status_code == 200
    assert len(country_movies.json()["results"]) > 0

    # Catalog listing endpoint (/api/v1/catalog)
    single_list = await api_client.get("/api/v1/catalog?type=single&page=1&limit=6")
    assert single_list.status_code == 200
    first_single = single_list.json()["results"][0]
    assert first_single["slug"]

    series_list = await api_client.get("/api/v1/catalog?type=series&page=1&limit=6")
    assert series_list.status_code == 200
    first_series = series_list.json()["results"][0]
    assert first_series["slug"]

    # Movie detail by VSMOV slug
    detail_res = await api_client.get(f"/api/v1/movies/{first_single['slug']}")
    assert detail_res.status_code == 200
    detail = detail_res.json()
    assert detail["slug"] == first_single["slug"]
    # Verify third-party VSMOV embed servers are parsed into catalog_servers
    # but NOT marked as directly playable internal streams
    assert detail["availability"]["is_directly_playable"] is False
    if detail["availability"]["catalog_servers"]:
        first_ep = detail["availability"]["catalog_servers"][0]["episodes"][0]
        assert first_ep["is_authorized_direct_stream"] is False

    # TV detail and season episodes by VSMOV slug
    tv_res = await api_client.get(f"/api/v1/tv/{first_series['slug']}")
    assert tv_res.status_code == 200
    tv_data = tv_res.json()
    assert tv_data["slug"] == first_series["slug"]
    season_num = tv_data["seasons"][0]["season_number"]

    season_res = await api_client.get(f"/api/v1/tv/{first_series['slug']}/seasons/{season_num}")
    assert season_res.status_code == 200
    season_data = season_res.json()
    assert len(season_data["episodes"]) >= 1


async def test_vsmov_downtime_graceful_handling(db_session: AsyncSession) -> None:
    """Verifies that VsmovProvider retries transient 503 errors and CatalogService
    gracefully falls back when VSMOV is down.
    """
    def _failing_transport(_: httpx.Request) -> httpx.Response:
        return httpx.Response(503, json={"status": False, "msg": "Service Unavailable"})

    failing_http = httpx.AsyncClient(transport=httpx.MockTransport(_failing_transport))
    broken_vsmov = VsmovProvider(http_client=failing_http, use_cache=False)

    with pytest.raises(ExternalServiceError):
        await broken_vsmov.get_newly_updated(page=1)

    service = CatalogService(db=db_session, vsmov=broken_vsmov)
    home = await service.get_home_feed()
    assert len(home.recently_added_playable) >= 3
    await failing_http.aclose()
