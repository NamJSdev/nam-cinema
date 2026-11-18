import asyncio
import logging
import re
from typing import Any, Literal, Optional
import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.exceptions import ExternalServiceError, ResourceNotFoundError
from app.models.entities import ProviderMapping, VideoAsset, WatchHistory
from app.providers.streaming import (
    ExternalWatchProvider,
    LicensedHlsProvider,
    PublicDemoContentProvider,
    SelfHostedLibraryProvider,
    parse_title_identifier,
)
from app.providers.vsmov import VsmovProvider, vsmov_provider
from app.schemas.api import (
    AvailabilityResponse,
    CastMember,
    CountryItem,
    EpisodeItem,
    ExternalProviderBadge,
    GenreItem,
    HomeFeedResponse,
    MediaSummary,
    MovieDetailResponse,
    PaginatedMediaResponse,
    ParsedEpisodeSource,
    ParsedServerGroup,
    PlayableAssetSummary,
    SeasonDetailResponse,
    SeasonSummary,
    TvDetailResponse,
    VideoTrailer,
    WatchHistoryItemResponse,
)
from app.schemas.vsmov import (
    VsmovDetailResponse,
    VsmovListResponse,
    VsmovMovieListItem,
    VsmovServerGroup,
)
from app.services.tmdb import TmdbClient, tmdb_client

logger = logging.getLogger(__name__)


def _parse_minutes(duration_str: Optional[str]) -> Optional[int]:
    if not duration_str:
        return None
    match = re.search(r"(\d+)", duration_str)
    if match:
        val = int(match.group(1))
        return val if val > 0 else None
    return None


def _parse_youtube_key(url: Optional[str]) -> Optional[str]:
    if not url:
        return None
    match = re.search(r"(?:v=|youtu\.be/|embed/)([A-Za-z0-9_-]{6,20})", url)
    return match.group(1) if match else None


class CatalogService:
    """Orchestrates VSMOV as the primary catalog provider and enriches metadata
    with TMDB high-resolution posters, backdrops, cast, crew, trailers, and recommendations
    when TMDB credentials are configured.
    """

    def __init__(
        self,
        db: AsyncSession,
        client: Optional[TmdbClient] = None,
        vsmov: Optional[VsmovProvider] = None,
    ) -> None:
        self._db = db
        self._tmdb = client or tmdb_client
        self._vsmov = vsmov or vsmov_provider
        self._settings = get_settings()

    async def _load_playable_map(self) -> dict[tuple[str, int], VideoAsset]:
        stmt = select(VideoAsset).where(VideoAsset.is_active.is_(True))
        result = await self._db.execute(stmt)
        assets = result.scalars().all()
        mapping: dict[tuple[str, int], VideoAsset] = {}
        for asset in assets:
            key = (asset.content_type, asset.tmdb_id)
            if key not in mapping:
                mapping[key] = asset
        return mapping

    async def _load_external_provider_set(self, region: str) -> set[tuple[str, int]]:
        stmt = select(ProviderMapping.content_type, ProviderMapping.tmdb_id).where(
            ProviderMapping.region == region.upper(),
            ProviderMapping.provider_type == "external_watch_provider",
        )
        result = await self._db.execute(stmt)
        return {(row[0], row[1]) for row in result.all()}

    def _map_vsmov_item(
        self,
        item: VsmovMovieListItem,
        path_image: Optional[str],
        playable_map: dict[tuple[str, int], VideoAsset],
        external_set: set[tuple[str, int]],
        forced_type: Optional[Literal["movie", "tv"]] = None,
    ) -> MediaSummary:
        content_type: Literal["movie", "tv"] = (
            forced_type
            if forced_type is not None
            else ("tv" if item.resolved_content_type == "tv" else "movie")
        )
        tmdb_id = item.resolved_tmdb_id
        key = (content_type, tmdb_id)
        playable_asset = playable_map.get(key) or playable_map.get(("movie", tmdb_id)) or playable_map.get(("tv", tmdb_id))

        if playable_asset is not None:
            badge: Literal["playable", "external", "metadata_only"] = "playable"
            asset_id: Optional[uuid.UUID] = playable_asset.id
        elif key in external_set:
            badge = "external"
            asset_id = None
        else:
            badge = "metadata_only"
            asset_id = None

        poster = self._vsmov.normalize_image_url(item.poster_url, path_image)
        backdrop = self._vsmov.normalize_image_url(item.thumb_url, path_image) or poster

        return MediaSummary(
            tmdb_id=tmdb_id,
            slug=item.slug,
            content_type=content_type,
            title=item.name,
            original_title=item.origin_name or item.name,
            overview="",
            poster_url=poster,
            backdrop_url=backdrop,
            release_date=str(item.year) if item.year else None,
            vote_average=item.tmdb.vote_average,
            vote_count=item.tmdb.vote_count,
            availability_badge=badge,
            playable_asset_id=asset_id,
        )

    async def map_vsmov_list_response(
        self,
        vsmov_res: VsmovListResponse,
        forced_type: Optional[Literal["movie", "tv"]] = None,
    ) -> PaginatedMediaResponse:
        playable_map = await self._load_playable_map()
        external_set = await self._load_external_provider_set(self._settings.DEFAULT_REGION)
        results = [
            self._map_vsmov_item(
                item,
                vsmov_res.pathImage,
                playable_map,
                external_set,
                forced_type=forced_type,
            )
            for item in vsmov_res.items
        ]
        return PaginatedMediaResponse(
            page=vsmov_res.pagination.currentPage,
            total_pages=max(1, vsmov_res.pagination.totalPages),
            total_results=vsmov_res.pagination.totalItems,
            results=results,
        )

    def _map_tmdb_summary(
        self,
        raw: dict[str, Any],
        default_type: Literal["movie", "tv"],
        playable_map: dict[tuple[str, int], VideoAsset],
        external_set: set[tuple[str, int]],
    ) -> Optional[MediaSummary]:
        media_type_raw = raw.get("media_type", default_type)
        if media_type_raw not in ("movie", "tv"):
            return None
        content_type: Literal["movie", "tv"] = "tv" if media_type_raw == "tv" else "movie"
        tmdb_id = int(raw["id"])
        title = raw.get("title") or raw.get("name") or "Untitled"
        original_title = raw.get("original_title") or raw.get("original_name")
        release_date = raw.get("release_date") or raw.get("first_air_date")

        key = (content_type, tmdb_id)
        playable_asset = playable_map.get(key)
        if playable_asset is not None:
            badge: Literal["playable", "external", "metadata_only"] = "playable"
            asset_id: Optional[uuid.UUID] = playable_asset.id
        elif key in external_set:
            badge = "external"
            asset_id = None
        else:
            badge = "metadata_only"
            asset_id = None

        return MediaSummary(
            tmdb_id=tmdb_id,
            content_type=content_type,
            title=title,
            original_title=original_title,
            overview=raw.get("overview") or "",
            poster_url=self._tmdb.poster_url(raw.get("poster_path")),
            backdrop_url=self._tmdb.backdrop_url(raw.get("backdrop_path")),
            release_date=release_date,
            vote_average=round(float(raw.get("vote_average") or 0.0), 1),
            vote_count=int(raw.get("vote_count") or 0),
            genre_ids=[int(g) for g in (raw.get("genre_ids") or [])],
            availability_badge=badge,
            playable_asset_id=asset_id,
        )

    async def map_paginated_response(
        self,
        payload: dict[str, Any],
        default_type: Literal["movie", "tv"] = "movie",
    ) -> PaginatedMediaResponse:
        playable_map = await self._load_playable_map()
        external_set = await self._load_external_provider_set(self._settings.DEFAULT_REGION)
        items: list[MediaSummary] = []
        for raw in payload.get("results", []):
            mapped = self._map_tmdb_summary(raw, default_type, playable_map, external_set)
            if mapped is not None:
                items.append(mapped)
        return PaginatedMediaResponse(
            page=int(payload.get("page", 1)),
            total_pages=int(payload.get("total_pages", 1)),
            total_results=int(payload.get("total_results", len(items))),
            results=items,
        )

    async def get_recently_added_playable(self) -> list[MediaSummary]:
        stmt = (
            select(VideoAsset)
            .where(VideoAsset.is_active.is_(True))
            .order_by(VideoAsset.created_at.desc())
        )
        result = await self._db.execute(stmt)
        assets = result.scalars().all()
        summaries: list[MediaSummary] = []
        seen: set[tuple[str, int]] = set()
        for asset in assets:
            key = (asset.content_type, asset.tmdb_id)
            if key in seen:
                continue
            seen.add(key)
            content_type: Literal["movie", "tv"] = "tv" if asset.content_type == "tv" else "movie"
            summaries.append(
                MediaSummary(
                    tmdb_id=asset.tmdb_id,
                    slug=str(asset.tmdb_id),
                    content_type=content_type,
                    title=asset.title,
                    original_title=asset.title,
                    overview=asset.synopsis or "",
                    poster_url=asset.poster_url,
                    backdrop_url=asset.backdrop_url,
                    release_date="2024",
                    vote_average=8.6,
                    vote_count=1240,
                    genre_ids=[16, 878, 28],
                    availability_badge="playable",
                    playable_asset_id=asset.id,
                )
            )
        return summaries

    async def get_continue_watching(self, user_id: Optional[uuid.UUID]) -> list[WatchHistoryItemResponse]:
        if user_id is None:
            return []
        stmt = (
            select(WatchHistory)
            .where(
                WatchHistory.user_id == user_id,
                WatchHistory.is_completed.is_(False),
                WatchHistory.current_position_seconds > 0,
            )
            .order_by(WatchHistory.last_watched_at.desc())
            .limit(12)
        )
        result = await self._db.execute(stmt)
        rows = result.scalars().all()
        return [
            WatchHistoryItemResponse(
                id=row.id,
                tmdb_id=row.tmdb_id,
                content_type=row.content_type,
                season_number=row.season_number,
                episode_number=row.episode_number,
                asset_id=row.asset_id,
                title=row.title,
                poster_path=row.poster_path,
                backdrop_path=row.backdrop_path,
                current_position_seconds=row.current_position_seconds,
                duration_seconds=row.duration_seconds,
                progress_ratio=round(min(1.0, row.current_position_seconds / max(1, row.duration_seconds)), 3),
                is_completed=row.is_completed,
                last_watched_at=row.last_watched_at,
            )
            for row in rows
        ]

    async def get_home_feed(self, user_id: Optional[uuid.UUID] = None) -> HomeFeedResponse:
        recently_added = await self.get_recently_added_playable()
        continue_watching = await self.get_continue_watching(user_id)

        try:
            (
                newly_updated_res,
                single_res,
                series_res,
                korean_res,
                chinese_res,
                hollywood_res,
                animation_res,
            ) = await asyncio.gather(
                self._vsmov.get_newly_updated(page=1),
                self._vsmov.get_single_movies(page=1, limit=24),
                self._vsmov.get_series_movies(page=1, limit=24),
                self._vsmov.get_movies_by_country("han-quoc", page=1, limit=18),
                self._vsmov.get_movies_by_country("trung-quoc", page=1, limit=18),
                self._vsmov.get_movies_by_country("au-my", page=1, limit=18),
                self._vsmov.get_movies_by_category("hoat-hinh", page=1, limit=18),
            )

            trending = (await self.map_vsmov_list_response(newly_updated_res)).results
            popular_movies = (await self.map_vsmov_list_response(single_res, forced_type="movie")).results
            popular_tv = (await self.map_vsmov_list_response(series_res, forced_type="tv")).results
            korean = (await self.map_vsmov_list_response(korean_res)).results
            chinese = (await self.map_vsmov_list_response(chinese_res)).results
            hollywood = (await self.map_vsmov_list_response(hollywood_res)).results
            animation = (await self.map_vsmov_list_response(animation_res)).results

            # Sort highest rated from combined catalog for Top Rated
            combined_pool = {
                (m.content_type, m.slug or str(m.tmdb_id)): m
                for m in (trending + popular_movies + popular_tv + hollywood)
            }
            top_rated = sorted(
                combined_pool.values(),
                key=lambda x: (x.vote_average, x.vote_count),
                reverse=True,
            )[:18]

            featured_hero = trending[:6] + recently_added[:2]
            recommended = top_rated[:8] + korean[:6]

            return HomeFeedResponse(
                featured_hero=featured_hero,
                trending_today=trending,
                popular_movies=popular_movies,
                popular_tv_series=popular_tv,
                top_rated_movies=top_rated,
                korean_movies=korean,
                chinese_movies=chinese,
                hollywood_movies=hollywood,
                animation_movies=animation,
                continue_watching=continue_watching,
                recommended_titles=recommended,
                recently_added_playable=recently_added,
                tmdb_configured=self._tmdb.is_configured,
                primary_provider="vsmov",
            )
        except Exception as vsmov_exc:
            logger.warning("VSMOV home feed unavailable (%s); attempting TMDB/local fallback.", str(vsmov_exc))
            if self._tmdb.is_configured:
                try:
                    trending_raw, pop_m_raw, pop_tv_raw, top_raw = await asyncio.gather(
                        self._tmdb.get("/trending/movie/day", {"page": 1}),
                        self._tmdb.get("/movie/popular", {"page": 1}),
                        self._tmdb.get("/tv/popular", {"page": 1}),
                        self._tmdb.get("/movie/top_rated", {"page": 1}),
                    )
                    trending = (await self.map_paginated_response(trending_raw, "movie")).results
                    pop_m = (await self.map_paginated_response(pop_m_raw, "movie")).results
                    pop_tv = (await self.map_paginated_response(pop_tv_raw, "tv")).results
                    top = (await self.map_paginated_response(top_raw, "movie")).results
                    return HomeFeedResponse(
                        featured_hero=recently_added[:2] + trending[:4],
                        trending_today=trending,
                        popular_movies=pop_m,
                        popular_tv_series=pop_tv,
                        top_rated_movies=top,
                        continue_watching=continue_watching,
                        recommended_titles=top[:8],
                        recently_added_playable=recently_added,
                        tmdb_configured=True,
                        primary_provider="tmdb_fallback",
                    )
                except Exception:
                    pass

            return HomeFeedResponse(
                featured_hero=recently_added,
                recently_added_playable=recently_added,
                continue_watching=continue_watching,
                tmdb_configured=self._tmdb.is_configured,
                primary_provider="local_playable_fallback",
                upstream_notice="Không thể kết nối tới VSMOV tạm thời. Bạn vẫn có thể phát các phim HLS hợp pháp bên dưới.",
            )

    def _parse_vsmov_servers(
        self,
        server_groups: list[VsmovServerGroup],
        playable_assets_by_ep: dict[int, VideoAsset],
        default_movie_asset: Optional[VideoAsset] = None,
    ) -> list[ParsedServerGroup]:
        """Parses VSMOV episode/server metadata into a separate playback-source model.
        Third-party embed links are recorded as metadata only (`is_authorized_direct_stream=False`)
        unless backed by a verified playable asset.
        """
        parsed_groups: list[ParsedServerGroup] = []
        for group in server_groups:
            episodes: list[ParsedEpisodeSource] = []
            for idx, ep in enumerate(group.server_data, start=1):
                ep_num = int(ep.name) if ep.name.isdigit() else idx
                matched_asset = playable_assets_by_ep.get(ep_num) or (
                    default_movie_asset if idx == 1 else None
                )
                episodes.append(
                    ParsedEpisodeSource(
                        server_name=group.server_name,
                        episode_name=ep.name or str(idx),
                        episode_slug=ep.slug or f"tap-{idx}",
                        filename=ep.filename,
                        embed_url=ep.link_embed,
                        direct_stream_url=ep.link_m3u8,
                        is_authorized_direct_stream=matched_asset is not None,
                        playable_asset_id=matched_asset.id if matched_asset else None,
                    )
                )
            parsed_groups.append(
                ParsedServerGroup(
                    server_name=group.server_name,
                    episodes=episodes,
                )
            )
        return parsed_groups

    async def get_title_availability(
        self,
        title_id: str,
        region: str = "VN",
        tmdb_watch_providers_payload: Optional[dict[str, Any]] = None,
        vsmov_servers: Optional[list[VsmovServerGroup]] = None,
        slug: Optional[str] = None,
    ) -> AvailabilityResponse:
        content_type_str, tmdb_id, _, _ = parse_title_identifier(title_id)
        content_type: Literal["movie", "tv"] = "tv" if content_type_str == "tv" else "movie"

        provider_a = LicensedHlsProvider(self._db)
        provider_b = SelfHostedLibraryProvider(self._db)
        provider_c = PublicDemoContentProvider(self._db)

        internal_lists = await asyncio.gather(
            provider_a.get_availability(title_id, region),
            provider_b.get_availability(title_id, region),
            provider_c.get_availability(title_id, region),
        )
        playable_assets: list[PlayableAssetSummary] = []
        for group in internal_lists:
            for item in group:
                playable_assets.append(
                    PlayableAssetSummary(
                        asset_id=uuid.UUID(item["asset_id"]),
                        provider_category=item["provider_category"],
                        duration_seconds=item["duration_seconds"],
                        license_name=item["license_name"],
                        license_url=item["license_url"],
                        attribution=item["attribution"],
                        season_number=item.get("season_number"),
                        episode_number=item.get("episode_number"),
                    )
                )

        parsed_tmdb_providers: list[dict[str, Any]] = []
        if tmdb_watch_providers_payload:
            results_by_region = tmdb_watch_providers_payload.get("results", {})
            region_data = (
                results_by_region.get(region.upper())
                or results_by_region.get("US")
                or {}
            )
            link = region_data.get("link")
            for monetization in ("flatrate", "free", "ads", "rent", "buy"):
                for p in region_data.get(monetization, []):
                    parsed_tmdb_providers.append(
                        {
                            "provider_name": p.get("provider_name"),
                            "monetization_type": monetization,
                            "logo_url": self._tmdb.poster_url(p.get("logo_path"), size="w185"),
                            "external_watch_url": link,
                        }
                    )

        provider_d = ExternalWatchProvider(self._db, tmdb_watch_providers=parsed_tmdb_providers)
        ext_raw = await provider_d.get_availability(title_id, region)
        external_providers = [
            ExternalProviderBadge(
                provider_name=e["provider_name"],
                monetization_type=e["monetization_type"],
                logo_url=e.get("logo_url"),
                external_watch_url=e.get("external_watch_url"),
                region=e.get("region", region.upper()),
            )
            for e in ext_raw
        ]

        catalog_servers: list[ParsedServerGroup] = []
        if vsmov_servers:
            catalog_servers = self._parse_vsmov_servers(vsmov_servers, {})

        if playable_assets:
            availability_type: Literal["playable", "external", "metadata_only"] = "playable"
        elif external_providers:
            availability_type = "external"
        else:
            availability_type = "metadata_only"

        return AvailabilityResponse(
            tmdb_id=tmdb_id,
            slug=slug,
            content_type=content_type,
            region=region.upper(),
            is_directly_playable=bool(playable_assets),
            availability_type=availability_type,
            playable_assets=playable_assets,
            external_providers=external_providers,
            catalog_servers=catalog_servers,
        )

    async def _resolve_vsmov_detail_by_id_or_slug(self, identifier: str) -> Optional[VsmovDetailResponse]:
        """Resolves a VSMOV detail payload either directly by slug or by matching tmdb_id."""
        if not identifier.isdigit():
            try:
                return await self._vsmov.get_movie_detail(identifier)
            except (ResourceNotFoundError, ExternalServiceError):
                return None

        # Numeric ID: scan first page of newly updated or single/series cache if available
        target_id = int(identifier)
        try:
            newly = await self._vsmov.get_newly_updated(page=1)
            for item in newly.items:
                if item.resolved_tmdb_id == target_id or item.internal_id == target_id:
                    return await self._vsmov.get_movie_detail(item.slug)
        except Exception:
            pass
        return None

    async def _enrich_from_tmdb(
        self,
        tmdb_id: Optional[int],
        content_type: Literal["movie", "tv"],
        origin_name: str,
        year: Optional[int],
    ) -> Optional[dict[str, Any]]:
        """Conservative TMDB metadata enrichment:
        1. Uses explicit numeric TMDB ID when valid.
        2. Otherwise performs conservative title + exact release year matching.
        """
        if not self._tmdb.is_configured:
            return None

        resolved_id = tmdb_id if (tmdb_id and tmdb_id > 0) else None
        try:
            if resolved_id is None and origin_name.strip():
                search_ep = f"/search/{content_type}"
                params: dict[str, Any] = {"query": origin_name.strip(), "page": 1}
                if year:
                    if content_type == "movie":
                        params["primary_release_year"] = year
                    else:
                        params["first_air_date_year"] = year
                search_res = await self._tmdb.get(search_ep, params)
                for candidate in search_res.get("results", []):
                    cand_title = (
                        candidate.get("original_title")
                        or candidate.get("title")
                        or candidate.get("original_name")
                        or candidate.get("name")
                        or ""
                    )
                    cand_date = candidate.get("release_date") or candidate.get("first_air_date") or ""
                    if cand_title.strip().lower() == origin_name.strip().lower():
                        if not year or cand_date.startswith(str(year)):
                            resolved_id = int(candidate["id"])
                            break

            if resolved_id is None:
                return None

            return await self._tmdb.get(
                f"/{content_type}/{resolved_id}",
                {"append_to_response": "credits,videos,recommendations,similar,watch/providers"},
            )
        except Exception as exc:
            logger.debug("TMDB enrichment skipped for %s (%s): %s", origin_name, resolved_id, str(exc))
            return None

    async def get_movie_detail_by_identifier(
        self,
        identifier: str,
        region: str = "VN",
    ) -> MovieDetailResponse:
        if identifier.startswith("playable-"):
            identifier = identifier.removeprefix("playable-")
        # 1. Check local playable asset if numeric ID matches
        local_asset: Optional[VideoAsset] = None
        if identifier.isdigit():
            stmt = select(VideoAsset).where(
                VideoAsset.tmdb_id == int(identifier),
                VideoAsset.is_active.is_(True),
            )
            local_asset = (await self._db.execute(stmt)).scalars().first()

        # 2. Try VSMOV primary catalog detail
        vsmov_detail = await self._resolve_vsmov_detail_by_id_or_slug(identifier)
        if vsmov_detail is not None and vsmov_detail.movie is not None:
            vmovie = vsmov_detail.movie
            tmdb_id = vmovie.resolved_tmdb_id
            content_type: Literal["movie", "tv"] = "tv" if vmovie.is_series else "movie"

            # Check if this tmdb_id has a local playable asset
            if local_asset is None:
                stmt = select(VideoAsset).where(
                    VideoAsset.tmdb_id == tmdb_id,
                    VideoAsset.is_active.is_(True),
                )
                local_asset = (await self._db.execute(stmt)).scalars().first()

            # Optional TMDB enrichment for high-res images, cast photos, trailers, recommendations
            tmdb_payload = await self._enrich_from_tmdb(
                vmovie.tmdb.numeric_tmdb_id,
                content_type,
                vmovie.origin_name or vmovie.name,
                vmovie.year,
            )

            availability = await self.get_title_availability(
                f"{content_type}:{tmdb_id}",
                region=region,
                tmdb_watch_providers_payload=tmdb_payload.get("watch/providers") if tmdb_payload else None,
                vsmov_servers=vsmov_detail.episodes,
                slug=vmovie.slug,
            )

            poster_url = (
                (self._tmdb.poster_url(tmdb_payload.get("poster_path")) if tmdb_payload else None)
                or self._vsmov.normalize_image_url(vmovie.poster_url)
            )
            backdrop_url = (
                (self._tmdb.backdrop_url(tmdb_payload.get("backdrop_path")) if tmdb_payload else None)
                or self._vsmov.normalize_image_url(vmovie.thumb_url)
                or poster_url
            )

            # Cast: prefer TMDB cast with photos when available, else VSMOV actor list
            cast: list[CastMember] = []
            if tmdb_payload and tmdb_payload.get("credits", {}).get("cast"):
                cast = [
                    CastMember(
                        id=int(c["id"]),
                        name=c.get("name", ""),
                        character=c.get("character"),
                        profile_url=self._tmdb.poster_url(c.get("profile_path"), size="w185"),
                    )
                    for c in tmdb_payload["credits"]["cast"][:15]
                ]
            else:
                cast = [
                    CastMember(id=idx, name=actor_name, character="Diễn viên")
                    for idx, actor_name in enumerate(vmovie.actor[:15], start=1)
                    if actor_name.strip()
                ]

            director = ", ".join([d for d in vmovie.director if d.strip()]) or None
            if not director and tmdb_payload:
                for crew_member in tmdb_payload.get("credits", {}).get("crew", []):
                    if crew_member.get("job") == "Director":
                        director = crew_member.get("name")
                        break

            trailers: list[VideoTrailer] = []
            yt_key = _parse_youtube_key(vmovie.trailer_url)
            if yt_key:
                trailers.append(
                    VideoTrailer(
                        id=yt_key,
                        key=yt_key,
                        name="Trailer Chính Thức",
                        site="YouTube",
                        type="Trailer",
                        youtube_url=f"https://www.youtube.com/watch?v={yt_key}",
                    )
                )
            if tmdb_payload:
                for v in tmdb_payload.get("videos", {}).get("results", []):
                    if v.get("site") == "YouTube" and v.get("key"):
                        trailers.append(
                            VideoTrailer(
                                id=str(v.get("id", v["key"])),
                                key=v["key"],
                                name=v.get("name", "Trailer"),
                                site="YouTube",
                                type=v.get("type", "Trailer"),
                                youtube_url=f"https://www.youtube.com/watch?v={v['key']}",
                            )
                        )

            recommendations: list[MediaSummary] = []
            if vmovie.category:
                try:
                    cat_rel = await self._vsmov.get_movies_by_category(
                        vmovie.category[0].slug,
                        page=1,
                        limit=12,
                    )
                    mapped_rel = await self.map_vsmov_list_response(cat_rel)
                    recommendations = [m for m in mapped_rel.results if m.slug != vmovie.slug][:10]
                except Exception:
                    pass

            return MovieDetailResponse(
                tmdb_id=tmdb_id,
                slug=vmovie.slug,
                content_type=content_type,
                title=vmovie.name,
                original_title=vmovie.origin_name or vmovie.name,
                overview=vmovie.content or (tmdb_payload.get("overview") if tmdb_payload else ""),
                poster_url=poster_url,
                backdrop_url=backdrop_url,
                release_date=str(vmovie.year) if vmovie.year else None,
                runtime_minutes=_parse_minutes(vmovie.time) or (tmdb_payload.get("runtime") if tmdb_payload else None),
                duration_label=vmovie.time,
                quality=vmovie.quality,
                lang=vmovie.lang,
                episode_current=vmovie.episode_current,
                episode_total=vmovie.episode_total,
                vote_average=vmovie.tmdb.vote_average or (round(float(tmdb_payload.get("vote_average", 0.0)), 1) if tmdb_payload else 0.0),
                vote_count=vmovie.tmdb.vote_count or (int(tmdb_payload.get("vote_count", 0)) if tmdb_payload else 0),
                genres=[
                    GenreItem(id=c.id, name=c.name, slug=c.slug)
                    for c in vmovie.category
                ],
                countries=[
                    CountryItem(id=c.id, name=c.name, slug=c.slug)
                    for c in vmovie.country
                ],
                director=director,
                cast=cast,
                trailers=trailers,
                recommendations=recommendations,
                similar=recommendations[:6],
                availability=availability,
            )

        # 3. Fallback to TMDB or local playable asset if numeric ID
        if identifier.isdigit():
            return await self.get_movie_detail(int(identifier), region=region)

        raise ResourceNotFoundError(f"Movie '{identifier}' was not found.")

    async def get_movie_detail(self, tmdb_id: int, region: str = "VN") -> MovieDetailResponse:
        stmt = select(VideoAsset).where(
            VideoAsset.tmdb_id == tmdb_id,
            VideoAsset.content_type == "movie",
            VideoAsset.is_active.is_(True),
        )
        local_res = await self._db.execute(stmt)
        local_asset = local_res.scalars().first()

        if not self._tmdb.is_configured and local_asset is not None:
            availability = await self.get_title_availability(f"movie:{tmdb_id}", region=region)
            return MovieDetailResponse(
                tmdb_id=tmdb_id,
                slug=f"playable-{tmdb_id}",
                title=local_asset.title,
                original_title=local_asset.title,
                overview=local_asset.synopsis or "",
                poster_url=local_asset.poster_url,
                backdrop_url=local_asset.backdrop_url,
                release_date="2012-09-26",
                runtime_minutes=max(1, local_asset.duration_seconds // 60),
                quality="FHD",
                lang="Vietsub",
                vote_average=8.4,
                vote_count=1420,
                genres=[
                    GenreItem(id=878, name="Khoa Học Viễn Tưởng", slug="khoa-hoc-vien-tuong"),
                    GenreItem(id=16, name="Hoạt Hình", slug="hoat-hinh"),
                ],
                director="Blender Open Movie Studio",
                cast=[],
                trailers=[],
                recommendations=[],
                similar=[],
                availability=availability,
            )

        payload = await self._tmdb.get(
            f"/movie/{tmdb_id}",
            {"append_to_response": "credits,videos,recommendations,similar,watch/providers"},
        )

        availability = await self.get_title_availability(
            f"movie:{tmdb_id}",
            region=region,
            tmdb_watch_providers_payload=payload.get("watch/providers"),
        )

        director = None
        for crew_member in payload.get("credits", {}).get("crew", []):
            if crew_member.get("job") == "Director":
                director = crew_member.get("name")
                break

        cast = [
            CastMember(
                id=int(c["id"]),
                name=c.get("name", ""),
                character=c.get("character"),
                profile_url=self._tmdb.poster_url(c.get("profile_path"), size="w185"),
            )
            for c in payload.get("credits", {}).get("cast", [])[:15]
        ]

        trailers = [
            VideoTrailer(
                id=str(v.get("id", v.get("key", ""))),
                key=v.get("key", ""),
                name=v.get("name", "Trailer"),
                site=v.get("site", "YouTube"),
                type=v.get("type", "Trailer"),
                youtube_url=f"https://www.youtube.com/watch?v={v.get('key')}"
                if v.get("site") == "YouTube" and v.get("key")
                else None,
            )
            for v in payload.get("videos", {}).get("results", [])
            if v.get("site") == "YouTube"
        ]

        recommendations = (
            await self.map_paginated_response(payload.get("recommendations", {"results": []}), "movie")
        ).results[:12]
        similar = (
            await self.map_paginated_response(payload.get("similar", {"results": []}), "movie")
        ).results[:12]

        return MovieDetailResponse(
            tmdb_id=int(payload["id"]),
            title=payload.get("title") or "Untitled",
            original_title=payload.get("original_title") or payload.get("title") or "Untitled",
            overview=payload.get("overview") or (local_asset.synopsis if local_asset else ""),
            poster_url=self._tmdb.poster_url(payload.get("poster_path")) or (local_asset.poster_url if local_asset else None),
            backdrop_url=self._tmdb.backdrop_url(payload.get("backdrop_path")) or (local_asset.backdrop_url if local_asset else None),
            release_date=payload.get("release_date"),
            runtime_minutes=payload.get("runtime"),
            vote_average=round(float(payload.get("vote_average") or 0.0), 1),
            vote_count=int(payload.get("vote_count") or 0),
            genres=[GenreItem(id=int(g["id"]), name=g["name"]) for g in payload.get("genres", [])],
            director=director,
            cast=cast,
            trailers=trailers,
            recommendations=recommendations,
            similar=similar,
            availability=availability,
        )

    async def get_tv_detail_by_identifier(
        self,
        identifier: str,
        region: str = "VN",
    ) -> TvDetailResponse:
        if identifier.startswith("playable-"):
            identifier = identifier.removeprefix("playable-")
        vsmov_detail = await self._resolve_vsmov_detail_by_id_or_slug(identifier)
        if vsmov_detail is not None and vsmov_detail.movie is not None:
            vmovie = vsmov_detail.movie
            tmdb_id = vmovie.resolved_tmdb_id
            tmdb_payload = await self._enrich_from_tmdb(
                vmovie.tmdb.numeric_tmdb_id,
                "tv",
                vmovie.origin_name or vmovie.name,
                vmovie.year,
            )

            availability = await self.get_title_availability(
                f"tv:{tmdb_id}",
                region=region,
                tmdb_watch_providers_payload=tmdb_payload.get("watch/providers") if tmdb_payload else None,
                vsmov_servers=vsmov_detail.episodes,
                slug=vmovie.slug,
            )

            poster_url = (
                (self._tmdb.poster_url(tmdb_payload.get("poster_path")) if tmdb_payload else None)
                or self._vsmov.normalize_image_url(vmovie.poster_url)
            )
            backdrop_url = (
                (self._tmdb.backdrop_url(tmdb_payload.get("backdrop_path")) if tmdb_payload else None)
                or self._vsmov.normalize_image_url(vmovie.thumb_url)
                or poster_url
            )

            total_eps = 0
            if vsmov_detail.episodes:
                total_eps = max(len(g.server_data) for g in vsmov_detail.episodes)

            season_num = vmovie.tmdb.season or 1
            seasons = [
                SeasonSummary(
                    id=season_num,
                    season_number=season_num,
                    name=f"Phần {season_num}",
                    episode_count=total_eps,
                    overview=vmovie.content,
                    poster_url=poster_url,
                    air_date=str(vmovie.year) if vmovie.year else None,
                )
            ]

            cast: list[CastMember] = []
            if tmdb_payload and tmdb_payload.get("credits", {}).get("cast"):
                cast = [
                    CastMember(
                        id=int(c["id"]),
                        name=c.get("name", ""),
                        character=c.get("character"),
                        profile_url=self._tmdb.poster_url(c.get("profile_path"), size="w185"),
                    )
                    for c in tmdb_payload["credits"]["cast"][:15]
                ]
            else:
                cast = [
                    CastMember(id=idx, name=a, character="Diễn viên")
                    for idx, a in enumerate(vmovie.actor[:15], start=1)
                    if a.strip()
                ]

            recommendations: list[MediaSummary] = []
            if vmovie.category:
                try:
                    cat_rel = await self._vsmov.get_movies_by_category(
                        vmovie.category[0].slug,
                        page=1,
                        limit=12,
                    )
                    mapped_rel = await self.map_vsmov_list_response(cat_rel)
                    recommendations = [m for m in mapped_rel.results if m.slug != vmovie.slug][:10]
                except Exception:
                    pass

            return TvDetailResponse(
                tmdb_id=tmdb_id,
                slug=vmovie.slug,
                title=vmovie.name,
                original_title=vmovie.origin_name or vmovie.name,
                overview=vmovie.content or (tmdb_payload.get("overview") if tmdb_payload else ""),
                poster_url=poster_url,
                backdrop_url=backdrop_url,
                first_air_date=str(vmovie.year) if vmovie.year else None,
                quality=vmovie.quality,
                lang=vmovie.lang,
                episode_current=vmovie.episode_current,
                episode_total=vmovie.episode_total,
                number_of_seasons=len(seasons),
                number_of_episodes=total_eps,
                vote_average=vmovie.tmdb.vote_average,
                vote_count=vmovie.tmdb.vote_count,
                genres=[GenreItem(id=c.id, name=c.name, slug=c.slug) for c in vmovie.category],
                countries=[CountryItem(id=c.id, name=c.name, slug=c.slug) for c in vmovie.country],
                cast=cast,
                trailers=[],
                seasons=seasons,
                recommendations=recommendations,
                similar=recommendations[:6],
                availability=availability,
            )

        if identifier.isdigit():
            return await self.get_tv_detail(int(identifier), region=region)

        raise ResourceNotFoundError(f"TV Series '{identifier}' was not found.")

    async def get_tv_detail(self, tmdb_id: int, region: str = "VN") -> TvDetailResponse:
        stmt = select(VideoAsset).where(
            VideoAsset.tmdb_id == tmdb_id,
            VideoAsset.content_type == "tv",
            VideoAsset.is_active.is_(True),
        )
        local_res = await self._db.execute(stmt)
        local_asset = local_res.scalars().first()

        if not self._tmdb.is_configured and local_asset is not None:
            availability = await self.get_title_availability(f"tv:{tmdb_id}", region=region)
            return TvDetailResponse(
                tmdb_id=tmdb_id,
                slug=f"playable-tv-{tmdb_id}",
                title=local_asset.title,
                original_title=local_asset.title,
                overview=local_asset.synopsis or "",
                poster_url=local_asset.poster_url,
                backdrop_url=local_asset.backdrop_url,
                first_air_date="2024-01-01",
                number_of_seasons=1,
                number_of_episodes=1,
                vote_average=8.7,
                vote_count=840,
                genres=[GenreItem(id=10765, name="Sci-Fi & Fantasy", slug="vien-tuong")],
                cast=[],
                trailers=[],
                seasons=[
                    SeasonSummary(
                        id=1,
                        season_number=1,
                        name="Mùa 1",
                        episode_count=1,
                        overview=local_asset.synopsis or "",
                        poster_url=local_asset.poster_url,
                        air_date="2024-01-01",
                    )
                ],
                recommendations=[],
                similar=[],
                availability=availability,
            )

        payload = await self._tmdb.get(
            f"/tv/{tmdb_id}",
            {"append_to_response": "credits,videos,recommendations,similar,watch/providers"},
        )

        availability = await self.get_title_availability(
            f"tv:{tmdb_id}",
            region=region,
            tmdb_watch_providers_payload=payload.get("watch/providers"),
        )

        cast = [
            CastMember(
                id=int(c["id"]),
                name=c.get("name", ""),
                character=c.get("character"),
                profile_url=self._tmdb.poster_url(c.get("profile_path"), size="w185"),
            )
            for c in payload.get("credits", {}).get("cast", [])[:15]
        ]

        trailers = [
            VideoTrailer(
                id=str(v.get("id", v.get("key", ""))),
                key=v.get("key", ""),
                name=v.get("name", "Trailer"),
                site=v.get("site", "YouTube"),
                type=v.get("type", "Trailer"),
                youtube_url=f"https://www.youtube.com/watch?v={v.get('key')}"
                if v.get("site") == "YouTube" and v.get("key")
                else None,
            )
            for v in payload.get("videos", {}).get("results", [])
            if v.get("site") == "YouTube"
        ]

        seasons = [
            SeasonSummary(
                id=int(s.get("id", s.get("season_number", 0))),
                season_number=int(s.get("season_number", 1)),
                name=s.get("name") or f"Season {s.get('season_number', 1)}",
                episode_count=int(s.get("episode_count") or 0),
                overview=s.get("overview") or "",
                poster_url=self._tmdb.poster_url(s.get("poster_path")),
                air_date=s.get("air_date"),
            )
            for s in payload.get("seasons", [])
            if int(s.get("season_number", 0)) >= 1
        ]

        recommendations = (
            await self.map_paginated_response(payload.get("recommendations", {"results": []}), "tv")
        ).results[:12]
        similar = (
            await self.map_paginated_response(payload.get("similar", {"results": []}), "tv")
        ).results[:12]

        return TvDetailResponse(
            tmdb_id=int(payload["id"]),
            title=payload.get("name") or "Untitled",
            original_title=payload.get("original_name") or payload.get("name") or "Untitled",
            overview=payload.get("overview") or "",
            poster_url=self._tmdb.poster_url(payload.get("poster_path")),
            backdrop_url=self._tmdb.backdrop_url(payload.get("backdrop_path")),
            first_air_date=payload.get("first_air_date"),
            number_of_seasons=int(payload.get("number_of_seasons") or len(seasons)),
            number_of_episodes=int(payload.get("number_of_episodes") or 0),
            vote_average=round(float(payload.get("vote_average") or 0.0), 1),
            vote_count=int(payload.get("vote_count") or 0),
            genres=[GenreItem(id=int(g["id"]), name=g["name"]) for g in payload.get("genres", [])],
            cast=cast,
            trailers=trailers,
            seasons=seasons,
            recommendations=recommendations,
            similar=similar,
            availability=availability,
        )

    async def get_tv_season_by_identifier(
        self,
        identifier: str,
        season_number: int,
    ) -> SeasonDetailResponse:
        vsmov_detail = await self._resolve_vsmov_detail_by_id_or_slug(identifier)
        if vsmov_detail is not None and vsmov_detail.movie is not None:
            vmovie = vsmov_detail.movie
            tmdb_id = vmovie.resolved_tmdb_id

            stmt = select(VideoAsset).where(
                VideoAsset.tmdb_id == tmdb_id,
                VideoAsset.content_type == "tv",
                VideoAsset.season_number == season_number,
                VideoAsset.is_active.is_(True),
            )
            asset_res = await self._db.execute(stmt)
            episode_assets = {
                a.episode_number: a
                for a in asset_res.scalars().all()
                if a.episode_number is not None
            }

            episodes: list[EpisodeItem] = []
            if vsmov_detail.episodes:
                primary_server = vsmov_detail.episodes[0]
                for idx, ep in enumerate(primary_server.server_data, start=1):
                    ep_num = int(ep.name) if ep.name.isdigit() else idx
                    matched_asset = episode_assets.get(ep_num)
                    episodes.append(
                        EpisodeItem(
                            id=ep_num,
                            episode_number=ep_num,
                            season_number=season_number,
                            name=f"Tập {ep.name}" if ep.name.isdigit() else ep.name,
                            slug=ep.slug,
                            server_name=primary_server.server_name,
                            overview=f"{vmovie.name} — Tập {ep.name} ({primary_server.server_name})",
                            still_url=self._vsmov.normalize_image_url(vmovie.thumb_url),
                            air_date=str(vmovie.year) if vmovie.year else None,
                            runtime_minutes=_parse_minutes(vmovie.time),
                            vote_average=vmovie.tmdb.vote_average,
                            is_playable=matched_asset is not None,
                            playable_asset_id=matched_asset.id if matched_asset else None,
                            embed_reference_url=ep.link_embed,
                        )
                    )

            return SeasonDetailResponse(
                tmdb_id=tmdb_id,
                slug=vmovie.slug,
                season_number=season_number,
                name=f"Phần {season_number}",
                overview=vmovie.content,
                poster_url=self._vsmov.normalize_image_url(vmovie.poster_url),
                episodes=episodes,
            )

        if identifier.isdigit():
            return await self.get_tv_season(int(identifier), season_number)

        raise ResourceNotFoundError(f"Season {season_number} for '{identifier}' was not found.")

    async def get_tv_season(self, tmdb_id: int, season_number: int) -> SeasonDetailResponse:
        stmt = select(VideoAsset).where(
            VideoAsset.tmdb_id == tmdb_id,
            VideoAsset.content_type == "tv",
            VideoAsset.season_number == season_number,
            VideoAsset.is_active.is_(True),
        )
        asset_res = await self._db.execute(stmt)
        episode_assets = {a.episode_number: a for a in asset_res.scalars().all() if a.episode_number is not None}

        if not self._tmdb.is_configured and episode_assets:
            ep_items = [
                EpisodeItem(
                    id=ep_num,
                    episode_number=ep_num,
                    season_number=season_number,
                    name=asset.title,
                    overview=asset.synopsis or "",
                    still_url=asset.backdrop_url,
                    air_date="2024-01-01",
                    runtime_minutes=max(1, asset.duration_seconds // 60),
                    vote_average=8.7,
                    is_playable=True,
                    playable_asset_id=asset.id,
                )
                for ep_num, asset in sorted(episode_assets.items())
            ]
            return SeasonDetailResponse(
                tmdb_id=tmdb_id,
                season_number=season_number,
                name=f"Mùa {season_number}",
                overview="Các tập phim được cấp phép phát trực tuyến trên Nam Cinema.",
                episodes=ep_items,
            )

        payload = await self._tmdb.get(f"/tv/{tmdb_id}/season/{season_number}")
        episodes: list[EpisodeItem] = []
        for ep in payload.get("episodes", []):
            ep_num = int(ep.get("episode_number", 1))
            matched_asset = episode_assets.get(ep_num)
            episodes.append(
                EpisodeItem(
                    id=int(ep.get("id", ep_num)),
                    episode_number=ep_num,
                    season_number=season_number,
                    name=ep.get("name") or f"Episode {ep_num}",
                    overview=ep.get("overview") or "",
                    still_url=self._tmdb.backdrop_url(ep.get("still_path"), size="w500"),
                    air_date=ep.get("air_date"),
                    runtime_minutes=ep.get("runtime"),
                    vote_average=round(float(ep.get("vote_average") or 0.0), 1),
                    is_playable=matched_asset is not None,
                    playable_asset_id=matched_asset.id if matched_asset else None,
                )
            )

        return SeasonDetailResponse(
            tmdb_id=tmdb_id,
            season_number=season_number,
            name=payload.get("name") or f"Season {season_number}",
            overview=payload.get("overview") or "",
            poster_url=self._tmdb.poster_url(payload.get("poster_path")),
            episodes=episodes,
        )
