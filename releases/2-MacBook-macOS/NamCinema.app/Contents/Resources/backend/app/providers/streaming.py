from datetime import datetime, timedelta, timezone
from typing import Any, Protocol
import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.config import get_settings
from app.core.exceptions import AuthorizationError, ResourceNotFoundError
from app.models.entities import (
    AudioTrack,
    PlaybackSession,
    ProviderMapping,
    SubtitleTrack,
    VideoAsset,
    VideoSource,
    WatchHistory,
)
from app.security.auth import hash_token, sign_manifest_url


class StreamingProvider(Protocol):
    async def get_availability(
        self,
        title_id: str,
        region: str,
    ) -> list[dict]:
        ...

    async def create_playback_session(
        self,
        asset_id: str,
        user_id: str,
    ) -> dict:
        ...


def parse_title_identifier(title_id: str) -> tuple[str, int, int | None, int | None]:
    """Parses title identifiers like '10378', 'movie:10378', or 'tv:1399:1:1'."""
    parts = [p.strip() for p in title_id.split(":") if p.strip()]
    if len(parts) == 1:
        return ("movie", int(parts[0]), None, None)
    if len(parts) == 2:
        return (parts[0].lower(), int(parts[1]), None, None)
    if len(parts) >= 4:
        return (parts[0].lower(), int(parts[1]), int(parts[2]), int(parts[3]))
    raise ValueError(f"Invalid title_id format: {title_id}")


class BaseDatabaseAssetProvider:
    """Base implementation shared by Provider A (Licensed HLS), Provider B (Self-Hosted),
    and Provider C (Publicly Licensed Demo Content).
    """

    provider_category: str = "public_demo"

    def __init__(self, db: AsyncSession) -> None:
        self._db = db
        self._settings = get_settings()

    async def get_availability(
        self,
        title_id: str,
        region: str,
    ) -> list[dict]:
        content_type, tmdb_id, season_number, episode_number = parse_title_identifier(title_id)
        stmt = (
            select(VideoAsset)
            .where(
                VideoAsset.tmdb_id == tmdb_id,
                VideoAsset.content_type == content_type,
                VideoAsset.provider_category == self.provider_category,
                VideoAsset.is_active.is_(True),
            )
            .order_by(VideoAsset.season_number.asc().nullsfirst(), VideoAsset.episode_number.asc().nullsfirst())
        )
        if season_number is not None:
            stmt = stmt.where(VideoAsset.season_number == season_number)
        if episode_number is not None:
            stmt = stmt.where(VideoAsset.episode_number == episode_number)

        result = await self._db.execute(stmt)
        assets = result.scalars().all()
        items: list[dict[str, Any]] = []
        for asset in assets:
            items.append(
                {
                    "asset_id": str(asset.id),
                    "tmdb_id": asset.tmdb_id,
                    "content_type": asset.content_type,
                    "season_number": asset.season_number,
                    "episode_number": asset.episode_number,
                    "provider_category": asset.provider_category,
                    "duration_seconds": asset.duration_seconds,
                    "license_name": asset.license_name,
                    "license_url": asset.license_url,
                    "attribution": asset.attribution,
                    "region": region.upper(),
                    "is_directly_playable": True,
                }
            )
        return items

    async def create_playback_session(
        self,
        asset_id: str,
        user_id: str,
    ) -> dict:
        asset_uuid = uuid.UUID(asset_id)
        user_uuid = uuid.UUID(user_id)

        stmt = (
            select(VideoAsset)
            .options(
                selectinload(VideoAsset.sources),
                selectinload(VideoAsset.subtitles),
                selectinload(VideoAsset.audio_tracks),
            )
            .where(
                VideoAsset.id == asset_uuid,
                VideoAsset.provider_category == self.provider_category,
                VideoAsset.is_active.is_(True),
            )
        )
        result = await self._db.execute(stmt)
        asset = result.scalar_one_or_none()
        if asset is None:
            raise ResourceNotFoundError(
                f"Active playable asset {asset_id} not found for provider {self.provider_category}."
            )

        if not asset.sources:
            raise AuthorizationError("No authorized HLS stream source is configured for this asset.")

        now = datetime.now(timezone.utc)
        expires_at = now + timedelta(minutes=self._settings.PLAYBACK_SESSION_TTL_MINUTES)
        session_id = uuid.uuid4()
        raw_session_token = f"{session_id}:{user_uuid}:{int(expires_at.timestamp())}"

        # Check saved watch history for resume position
        history_stmt = select(WatchHistory).where(
            WatchHistory.user_id == user_uuid,
            WatchHistory.tmdb_id == asset.tmdb_id,
            WatchHistory.content_type == asset.content_type,
            WatchHistory.season_key == (asset.season_number or 0),
            WatchHistory.episode_key == (asset.episode_number or 0),
        )
        history_res = await self._db.execute(history_stmt)
        history_item = history_res.scalar_one_or_none()
        resume_position = 0
        if history_item and not history_item.is_completed:
            resume_position = history_item.current_position_seconds

        session_record = PlaybackSession(
            id=session_id,
            user_id=user_uuid,
            asset_id=asset.id,
            session_token_hash=hash_token(raw_session_token),
            expires_at=expires_at,
            last_heartbeat_at=now,
            current_position_seconds=resume_position,
            is_active=True,
        )
        self._db.add(session_record)
        await self._db.commit()

        signed_sources = []
        for src in asset.sources:
            manifest_url = (
                sign_manifest_url(src.manifest_url, session_id, user_uuid, expires_at)
                if src.requires_signing
                else src.manifest_url
            )
            signed_sources.append(
                {
                    "stream_type": src.stream_type,
                    "manifest_url": manifest_url,
                    "quality_label": src.quality_label,
                    "bandwidth_kbps": src.bandwidth_kbps,
                }
            )

        subtitles = []
        for sub in asset.subtitles:
            sub_url = (
                f"{self._settings.PUBLIC_BASE_URL.rstrip('/')}{sub.url}"
                if sub.url.startswith("/")
                else sub.url
            )
            subtitles.append(
                {
                    "id": sub.id,
                    "language_code": sub.language_code,
                    "label": sub.label,
                    "format": sub.format,
                    "url": sub_url,
                    "is_default": sub.is_default,
                }
            )

        audio_tracks = [
            {
                "id": track.id,
                "language_code": track.language_code,
                "label": track.label,
                "channels": track.channels,
                "is_default": track.is_default,
            }
            for track in asset.audio_tracks
        ]

        return {
            "session_id": session_id,
            "asset_id": asset.id,
            "tmdb_id": asset.tmdb_id,
            "content_type": asset.content_type,
            "season_number": asset.season_number,
            "episode_number": asset.episode_number,
            "title": asset.title,
            "duration_seconds": asset.duration_seconds,
            "resume_position_seconds": resume_position,
            "expires_at": expires_at,
            "license_name": asset.license_name,
            "license_url": asset.license_url,
            "attribution": asset.attribution,
            "sources": signed_sources,
            "subtitles": subtitles,
            "audio_tracks": audio_tracks,
        }


class LicensedHlsProvider(BaseDatabaseAssetProvider):
    """Provider A — Licensed HLS Content with expiring signed URLs and multi-track support."""

    provider_category = "licensed_hls"


class SelfHostedLibraryProvider(BaseDatabaseAssetProvider):
    """Provider B — Developer-owned or self-hosted licensed video library."""

    provider_category = "self_hosted"


class PublicDemoContentProvider(BaseDatabaseAssetProvider):
    """Provider C — Verified Creative Commons / openly licensed HLS demo streams."""

    provider_category = "public_demo"


class ExternalWatchProvider:
    """Provider D — External Watch Providers (TMDB watch-provider metadata).
    Never presents an external streaming service as an internally playable asset.
    """

    def __init__(self, db: AsyncSession, tmdb_watch_providers: list[dict] | None = None) -> None:
        self._db = db
        self._tmdb_watch_providers = tmdb_watch_providers or []

    async def get_availability(
        self,
        title_id: str,
        region: str,
    ) -> list[dict]:
        content_type, tmdb_id, _, _ = parse_title_identifier(title_id)
        stmt = select(ProviderMapping).where(
            ProviderMapping.tmdb_id == tmdb_id,
            ProviderMapping.content_type == content_type,
            ProviderMapping.region == region.upper(),
            ProviderMapping.provider_type == "external_watch_provider",
        )
        result = await self._db.execute(stmt)
        db_mappings = result.scalars().all()

        items: list[dict] = []
        seen_names: set[str] = set()
        for mapping in db_mappings:
            seen_names.add(mapping.provider_name.lower())
            items.append(
                {
                    "provider_name": mapping.provider_name,
                    "monetization_type": mapping.monetization_type,
                    "logo_url": mapping.logo_path,
                    "external_watch_url": mapping.external_watch_url,
                    "region": mapping.region,
                    "is_directly_playable": False,
                }
            )

        for ext in self._tmdb_watch_providers:
            name = ext.get("provider_name", "")
            if name and name.lower() not in seen_names:
                seen_names.add(name.lower())
                items.append(
                    {
                        "provider_name": name,
                        "monetization_type": ext.get("monetization_type", "flatrate"),
                        "logo_url": ext.get("logo_url"),
                        "external_watch_url": ext.get("external_watch_url"),
                        "region": region.upper(),
                        "is_directly_playable": False,
                    }
                )
        return items

    async def create_playback_session(
        self,
        asset_id: str,
        user_id: str,
    ) -> dict:
        raise AuthorizationError(
            "External watch providers do not grant internal playback rights inside Nam Cinema."
        )
