from datetime import datetime, timezone
import uuid
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.entities import WatchHistory, WatchlistItem


class LibraryRepository:
    def __init__(self, db: AsyncSession) -> None:
        self._db = db

    async def list_watchlist(self, user_id: uuid.UUID) -> list[WatchlistItem]:
        stmt = (
            select(WatchlistItem)
            .where(WatchlistItem.user_id == user_id)
            .order_by(WatchlistItem.created_at.desc())
        )
        result = await self._db.execute(stmt)
        return list(result.scalars().all())

    async def get_watchlist_item_by_title(
        self,
        user_id: uuid.UUID,
        tmdb_id: int,
        content_type: str,
    ) -> WatchlistItem | None:
        stmt = select(WatchlistItem).where(
            WatchlistItem.user_id == user_id,
            WatchlistItem.tmdb_id == tmdb_id,
            WatchlistItem.content_type == content_type,
        )
        result = await self._db.execute(stmt)
        return result.scalar_one_or_none()

    async def list_history(self, user_id: uuid.UUID) -> list[WatchHistory]:
        stmt = (
            select(WatchHistory)
            .where(WatchHistory.user_id == user_id)
            .order_by(WatchHistory.last_watched_at.desc())
        )
        result = await self._db.execute(stmt)
        return list(result.scalars().all())

    async def upsert_progress(
        self,
        *,
        user_id: uuid.UUID,
        tmdb_id: int,
        content_type: str,
        season_number: int | None,
        episode_number: int | None,
        asset_id: uuid.UUID | None,
        title: str,
        poster_path: str | None,
        backdrop_path: str | None,
        current_position_seconds: int,
        duration_seconds: int,
        is_completed: bool | None = None,
    ) -> WatchHistory:
        season_key = season_number or 0
        episode_key = episode_number or 0
        stmt = select(WatchHistory).where(
            WatchHistory.user_id == user_id,
            WatchHistory.tmdb_id == tmdb_id,
            WatchHistory.content_type == content_type,
            WatchHistory.season_key == season_key,
            WatchHistory.episode_key == episode_key,
        )
        result = await self._db.execute(stmt)
        item = result.scalar_one_or_none()

        safe_duration = max(1, duration_seconds)
        safe_position = min(max(0, current_position_seconds), safe_duration)
        completed = (
            is_completed
            if is_completed is not None
            else (safe_position / safe_duration >= 0.92)
        )
        now = datetime.now(timezone.utc)

        if item is None:
            item = WatchHistory(
                user_id=user_id,
                tmdb_id=tmdb_id,
                content_type=content_type,
                season_number=season_number,
                episode_number=episode_number,
                season_key=season_key,
                episode_key=episode_key,
                asset_id=asset_id,
                title=title,
                poster_path=poster_path,
                backdrop_path=backdrop_path,
                current_position_seconds=safe_position,
                duration_seconds=safe_duration,
                is_completed=completed,
                last_watched_at=now,
            )
            self._db.add(item)
        else:
            item.title = title
            if poster_path is not None:
                item.poster_path = poster_path
            if backdrop_path is not None:
                item.backdrop_path = backdrop_path
            if asset_id is not None:
                item.asset_id = asset_id
            item.current_position_seconds = safe_position
            item.duration_seconds = safe_duration
            item.is_completed = completed
            item.last_watched_at = now

        await self._db.commit()
        await self._db.refresh(item)
        return item
