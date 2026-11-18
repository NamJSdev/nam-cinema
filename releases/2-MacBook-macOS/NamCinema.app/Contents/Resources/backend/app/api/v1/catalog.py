from typing import Literal, Optional
from fastapi import APIRouter, Depends, Query
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ExternalServiceError
from app.db.session import get_db_session
from app.models.entities import User, VideoAsset
from app.providers.vsmov import vsmov_provider
from app.schemas.api import (
    CountryItem,
    GenreItem,
    HomeFeedResponse,
    MediaSummary,
    MovieDetailResponse,
    PaginatedMediaResponse,
    SeasonDetailResponse,
    TvDetailResponse,
)
from app.security.auth import get_optional_user
from app.services.catalog import CatalogService
from app.services.tmdb import tmdb_client

router = APIRouter(tags=["Catalog"])


@router.get("/home", response_model=HomeFeedResponse)
async def get_home_feed(
    user: Optional[User] = Depends(get_optional_user),
    db: AsyncSession = Depends(get_db_session),
) -> HomeFeedResponse:
    service = CatalogService(db)
    return await service.get_home_feed(user_id=user.id if user else None)


@router.get("/catalog", response_model=PaginatedMediaResponse)
async def get_catalog_listing(
    page: int = Query(default=1, ge=1, le=2000),
    limit: int = Query(default=24, ge=1, le=60),
    type: Optional[Literal["single", "series", "newly_updated"]] = Query(default=None),
    category: Optional[str] = Query(default=None),
    country: Optional[str] = Query(default=None),
    year: Optional[int] = Query(default=None, ge=1900, le=2100),
    db: AsyncSession = Depends(get_db_session),
) -> PaginatedMediaResponse:
    service = CatalogService(db)
    if type == "newly_updated" and not category and not country and not year:
        vsmov_res = await vsmov_provider.get_newly_updated(page=page)
        return await service.map_vsmov_list_response(vsmov_res)
    if category and not type and not country and not year:
        vsmov_res = await vsmov_provider.get_movies_by_category(category, page=page, limit=limit)
        return await service.map_vsmov_list_response(vsmov_res)
    if country and not type and not category and not year:
        vsmov_res = await vsmov_provider.get_movies_by_country(country, page=page, limit=limit)
        return await service.map_vsmov_list_response(vsmov_res)

    effective_type = None if type == "newly_updated" else type
    forced: Optional[Literal["movie", "tv"]] = None
    if effective_type == "single":
        forced = "movie"
    elif effective_type == "series":
        forced = "tv"

    vsmov_res = await vsmov_provider.get_catalog_list(
        page=page,
        limit=limit,
        movie_type=effective_type,
        category=category,
        country=country,
        year=year,
    )
    return await service.map_vsmov_list_response(vsmov_res, forced_type=forced)


@router.get("/movies/trending", response_model=PaginatedMediaResponse)
async def get_trending_movies(
    page: int = Query(default=1, ge=1, le=2000),
    db: AsyncSession = Depends(get_db_session),
) -> PaginatedMediaResponse:
    service = CatalogService(db)
    try:
        vsmov_res = await vsmov_provider.get_newly_updated(page=page)
        return await service.map_vsmov_list_response(vsmov_res)
    except ExternalServiceError:
        if tmdb_client.is_configured:
            raw = await tmdb_client.get("/trending/movie/day", {"page": page})
            return await service.map_paginated_response(raw, "movie")
        raise


@router.get("/movies/popular", response_model=PaginatedMediaResponse)
async def get_popular_movies(
    page: int = Query(default=1, ge=1, le=2000),
    limit: int = Query(default=24, ge=1, le=60),
    db: AsyncSession = Depends(get_db_session),
) -> PaginatedMediaResponse:
    service = CatalogService(db)
    try:
        vsmov_res = await vsmov_provider.get_single_movies(page=page, limit=limit)
        return await service.map_vsmov_list_response(vsmov_res, forced_type="movie")
    except ExternalServiceError:
        if tmdb_client.is_configured:
            raw = await tmdb_client.get("/movie/popular", {"page": page})
            return await service.map_paginated_response(raw, "movie")
        raise


@router.get("/movies/top-rated", response_model=PaginatedMediaResponse)
async def get_top_rated_movies(
    page: int = Query(default=1, ge=1, le=2000),
    limit: int = Query(default=24, ge=1, le=60),
    db: AsyncSession = Depends(get_db_session),
) -> PaginatedMediaResponse:
    service = CatalogService(db)
    try:
        vsmov_res = await vsmov_provider.get_catalog_list(page=page, limit=limit)
        mapped = await service.map_vsmov_list_response(vsmov_res)
        mapped.results.sort(key=lambda m: (m.vote_average, m.vote_count), reverse=True)
        return mapped
    except ExternalServiceError:
        if tmdb_client.is_configured:
            raw = await tmdb_client.get("/movie/top_rated", {"page": page})
            return await service.map_paginated_response(raw, "movie")
        raise


@router.get("/movies/{identifier}", response_model=MovieDetailResponse)
async def get_movie_details(
    identifier: str,
    region: str = Query(default="VN", max_length=4),
    db: AsyncSession = Depends(get_db_session),
) -> MovieDetailResponse:
    service = CatalogService(db)
    return await service.get_movie_detail_by_identifier(identifier=identifier, region=region)


@router.get("/tv/popular", response_model=PaginatedMediaResponse)
async def get_popular_tv(
    page: int = Query(default=1, ge=1, le=2000),
    limit: int = Query(default=24, ge=1, le=60),
    db: AsyncSession = Depends(get_db_session),
) -> PaginatedMediaResponse:
    service = CatalogService(db)
    try:
        vsmov_res = await vsmov_provider.get_series_movies(page=page, limit=limit)
        return await service.map_vsmov_list_response(vsmov_res, forced_type="tv")
    except ExternalServiceError:
        if tmdb_client.is_configured:
            raw = await tmdb_client.get("/tv/popular", {"page": page})
            return await service.map_paginated_response(raw, "tv")
        raise


@router.get("/tv/{identifier}", response_model=TvDetailResponse)
async def get_tv_details(
    identifier: str,
    region: str = Query(default="VN", max_length=4),
    db: AsyncSession = Depends(get_db_session),
) -> TvDetailResponse:
    service = CatalogService(db)
    return await service.get_tv_detail_by_identifier(identifier=identifier, region=region)


@router.get("/tv/{identifier}/seasons/{season_number}", response_model=SeasonDetailResponse)
async def get_tv_season_details(
    identifier: str,
    season_number: int,
    db: AsyncSession = Depends(get_db_session),
) -> SeasonDetailResponse:
    service = CatalogService(db)
    return await service.get_tv_season_by_identifier(
        identifier=identifier,
        season_number=season_number,
    )


@router.get("/search", response_model=PaginatedMediaResponse)
async def search_catalog(
    q: str = Query(default="", max_length=200),
    type: Literal["all", "movie", "tv", "person"] = Query(default="all"),
    genre_id: Optional[int] = Query(default=None),
    genre_slug: Optional[str] = Query(default=None),
    country_slug: Optional[str] = Query(default=None),
    year: Optional[int] = Query(default=None, ge=1900, le=2100),
    sort_by: str = Query(default="popularity.desc"),
    page: int = Query(default=1, ge=1, le=2000),
    limit: int = Query(default=24, ge=1, le=60),
    db: AsyncSession = Depends(get_db_session),
) -> PaginatedMediaResponse:
    service = CatalogService(db)
    query_str = q.strip()

    try:
        if query_str:
            vsmov_res = await vsmov_provider.search_movies(
                keyword=query_str,
                page=page,
                limit=limit,
            )
            mapped = await service.map_vsmov_list_response(vsmov_res)
            if type in ("movie", "tv"):
                mapped.results = [m for m in mapped.results if m.content_type == type]
            if year is not None:
                mapped.results = [m for m in mapped.results if m.release_date == str(year)]
            return mapped

        if genre_slug:
            vsmov_res = await vsmov_provider.get_movies_by_category(
                slug=genre_slug,
                page=page,
                limit=limit,
            )
            mapped = await service.map_vsmov_list_response(vsmov_res)
            if type in ("movie", "tv"):
                mapped.results = [m for m in mapped.results if m.content_type == type]
            if year is not None:
                mapped.results = [m for m in mapped.results if m.release_date == str(year)]
            return mapped

        if country_slug:
            vsmov_res = await vsmov_provider.get_movies_by_country(
                slug=country_slug,
                page=page,
                limit=limit,
            )
            mapped = await service.map_vsmov_list_response(vsmov_res)
            if type in ("movie", "tv"):
                mapped.results = [m for m in mapped.results if m.content_type == type]
            if year is not None:
                mapped.results = [m for m in mapped.results if m.release_date == str(year)]
            return mapped

        vsmov_type = "single" if type == "movie" else ("series" if type == "tv" else None)
        vsmov_res = await vsmov_provider.get_catalog_list(
            page=page,
            limit=limit,
            movie_type=vsmov_type,
            year=year,
        )
        forced: Optional[Literal["movie", "tv"]] = (
            "movie" if type == "movie" else ("tv" if type == "tv" else None)
        )
        mapped = await service.map_vsmov_list_response(vsmov_res, forced_type=forced)
        if year is not None:
            mapped.results = [m for m in mapped.results if m.release_date == str(year)]
        return mapped

    except ExternalServiceError:
        # Graceful fallback to local playable assets if VSMOV is unreachable
        stmt = select(VideoAsset).where(VideoAsset.is_active.is_(True))
        if query_str:
            pattern = f"%{query_str}%"
            stmt = stmt.where(
                or_(VideoAsset.title.ilike(pattern), VideoAsset.synopsis.ilike(pattern))
            )
        if type in ("movie", "tv"):
            stmt = stmt.where(VideoAsset.content_type == type)
        assets = (await db.execute(stmt)).scalars().all()
        items = [
            MediaSummary(
                tmdb_id=a.tmdb_id,
                slug=f"playable-{a.tmdb_id}",
                content_type="tv" if a.content_type == "tv" else "movie",
                title=a.title,
                original_title=a.title,
                overview=a.synopsis or "",
                poster_url=a.poster_url,
                backdrop_url=a.backdrop_url,
                release_date="2024",
                vote_average=8.5,
                vote_count=1100,
                genre_ids=[16, 878],
                availability_badge="playable",
                playable_asset_id=a.id,
            )
            for a in assets
        ]
        return PaginatedMediaResponse(
            page=1,
            total_pages=1,
            total_results=len(items),
            results=items,
        )


@router.get("/genres", response_model=list[GenreItem])
async def get_genres() -> list[GenreItem]:
    try:
        categories = await vsmov_provider.get_categories()
        return [
            GenreItem(id=c.id, name=c.name, slug=c.slug)
            for c in categories
            if c.slug
        ]
    except ExternalServiceError:
        return [
            GenreItem(id=30, name="Hành Động", slug="hanh-dong"),
            GenreItem(id=21, name="Hoạt Hình", slug="hoat-hinh"),
            GenreItem(id=15, name="Chính Kịch", slug="chinh-kich"),
            GenreItem(id=17, name="Bí Ẩn", slug="bi-an"),
            GenreItem(id=20, name="Hài", slug="hai"),
            GenreItem(id=48, name="Hình Sự", slug="hinh-su"),
        ]


@router.get("/genres/{slug}", response_model=PaginatedMediaResponse)
async def get_movies_by_genre_slug(
    slug: str,
    page: int = Query(default=1, ge=1, le=2000),
    limit: int = Query(default=24, ge=1, le=60),
    db: AsyncSession = Depends(get_db_session),
) -> PaginatedMediaResponse:
    service = CatalogService(db)
    vsmov_res = await vsmov_provider.get_movies_by_category(slug=slug, page=page, limit=limit)
    return await service.map_vsmov_list_response(vsmov_res)


@router.get("/countries", response_model=list[CountryItem])
async def get_countries() -> list[CountryItem]:
    try:
        countries = await vsmov_provider.get_countries()
        return [
            CountryItem(id=c.id, name=c.name, slug=c.slug)
            for c in countries
            if c.slug
        ]
    except ExternalServiceError:
        return [
            CountryItem(id=10, name="Hàn Quốc", slug="han-quoc"),
            CountryItem(id=13, name="Trung Quốc", slug="trung-quoc"),
            CountryItem(id=7, name="Âu Mỹ", slug="au-my"),
            CountryItem(id=17, name="Nhật Bản", slug="nhat-ban"),
            CountryItem(id=9, name="Việt Nam", slug="viet-nam"),
        ]


@router.get("/countries/{slug}", response_model=PaginatedMediaResponse)
async def get_movies_by_country_slug(
    slug: str,
    page: int = Query(default=1, ge=1, le=2000),
    limit: int = Query(default=24, ge=1, le=60),
    db: AsyncSession = Depends(get_db_session),
) -> PaginatedMediaResponse:
    service = CatalogService(db)
    vsmov_res = await vsmov_provider.get_movies_by_country(slug=slug, page=page, limit=limit)
    return await service.map_vsmov_list_response(vsmov_res)
