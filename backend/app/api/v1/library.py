import uuid
from fastapi import APIRouter, Depends, status
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ResourceNotFoundError
from app.db.session import get_db_session
from app.models.entities import PlaybackSession, User, WatchHistory, WatchlistItem
from app.repositories.library import LibraryRepository
from app.schemas.api import (
    ProgressUpdateRequest,
    WatchHistoryItemResponse,
    WatchlistCreateRequest,
    WatchlistItemResponse,
)
from app.security.auth import get_current_user

router = APIRouter(prefix="/me", tags=["User Library"])


@router.get("/watchlist", response_model=list[WatchlistItemResponse])
async def list_watchlist(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> list[WatchlistItemResponse]:
    repo = LibraryRepository(db)
    items = await repo.list_watchlist(current_user.id)
    return [WatchlistItemResponse.model_validate(item) for item in items]


@router.post(
    "/watchlist",
    response_model=WatchlistItemResponse,
    status_code=status.HTTP_201_CREATED,
)
async def add_to_watchlist(
    payload: WatchlistCreateRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> WatchlistItemResponse:
    repo = LibraryRepository(db)
    existing = await repo.get_watchlist_item_by_title(
        user_id=current_user.id,
        tmdb_id=payload.tmdb_id,
        content_type=payload.content_type,
    )
    if existing is not None:
        existing.title = payload.title
        existing.poster_path = payload.poster_path
        existing.backdrop_path = payload.backdrop_path
        existing.vote_average = payload.vote_average
        existing.release_year = payload.release_year
        await db.commit()
        await db.refresh(existing)
        return WatchlistItemResponse.model_validate(existing)

    item = WatchlistItem(
        user_id=current_user.id,
        tmdb_id=payload.tmdb_id,
        content_type=payload.content_type,
        title=payload.title,
        poster_path=payload.poster_path,
        backdrop_path=payload.backdrop_path,
        vote_average=payload.vote_average,
        release_year=payload.release_year,
    )
    db.add(item)
    await db.commit()
    await db.refresh(item)
    return WatchlistItemResponse.model_validate(item)


@router.delete("/watchlist/{id}", status_code=status.HTTP_200_OK)
async def remove_from_watchlist(
    id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> dict[str, str]:
    stmt = None
    try:
        item_uuid = uuid.UUID(id)
        stmt = select(WatchlistItem).where(
            WatchlistItem.id == item_uuid,
            WatchlistItem.user_id == current_user.id,
        )
    except ValueError:
        # Also support deleting by tmdb_id string for convenience
        if id.isdigit():
            stmt = select(WatchlistItem).where(
                WatchlistItem.tmdb_id == int(id),
                WatchlistItem.user_id == current_user.id,
            )

    if stmt is None:
        raise ResourceNotFoundError("Watchlist item not found.")

    item = (await db.execute(stmt)).scalars().first()
    if item is None:
        raise ResourceNotFoundError("Watchlist item not found.")

    await db.delete(item)
    await db.commit()
    return {"status": "deleted"}


@router.get("/history", response_model=list[WatchHistoryItemResponse])
async def list_watch_history(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> list[WatchHistoryItemResponse]:
    repo = LibraryRepository(db)
    rows = await repo.list_history(current_user.id)
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


@router.delete("/watchlist", status_code=status.HTTP_200_OK)
async def clear_all_watchlist(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> dict[str, int | str]:
    stmt = delete(WatchlistItem).where(WatchlistItem.user_id == current_user.id)
    res = await db.execute(stmt)
    await db.commit()
    return {"status": "cleared", "deleted_count": int(res.rowcount or 0)}


@router.put("/progress", response_model=WatchHistoryItemResponse)
@router.put("/history/progress", response_model=WatchHistoryItemResponse)
async def update_watch_progress(
    payload: ProgressUpdateRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> WatchHistoryItemResponse:
    repo = LibraryRepository(db)
    row = await repo.upsert_progress(
        user_id=current_user.id,
        tmdb_id=payload.tmdb_id,
        content_type=payload.content_type,
        season_number=payload.season_number,
        episode_number=payload.episode_number,
        asset_id=payload.asset_id,
        title=payload.title,
        poster_path=payload.poster_path,
        backdrop_path=payload.backdrop_path,
        current_position_seconds=payload.current_position_seconds,
        duration_seconds=payload.duration_seconds,
        is_completed=payload.is_completed,
    )
    return WatchHistoryItemResponse(
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


@router.delete("/history", status_code=status.HTTP_200_OK)
async def clear_all_watch_history(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> dict[str, int | str]:
    stmt = delete(WatchHistory).where(WatchHistory.user_id == current_user.id)
    res = await db.execute(stmt)
    await db.commit()
    return {"status": "cleared", "deleted_count": int(res.rowcount or 0)}


@router.delete("/history/{id}", status_code=status.HTTP_200_OK)
async def delete_watch_history(
    id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> dict[str, str]:
    stmt = None
    try:
        item_uuid = uuid.UUID(id)
        stmt = select(WatchHistory).where(
            WatchHistory.id == item_uuid,
            WatchHistory.user_id == current_user.id,
        )
    except ValueError:
        if id.lstrip("-").isdigit():
            stmt = select(WatchHistory).where(
                WatchHistory.tmdb_id == int(id),
                WatchHistory.user_id == current_user.id,
            )

    if stmt is None:
        raise ResourceNotFoundError("Watch history entry not found.")

    rows = list((await db.execute(stmt)).scalars().all())
    if not rows:
        raise ResourceNotFoundError("Watch history entry not found.")

    for row in rows:
        await db.delete(row)
    await db.commit()
    return {"status": "deleted"}


@router.post("/reset-all", status_code=status.HTTP_200_OK)
async def reset_all_personal_data(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> dict[str, int | str]:
    h_res = await db.execute(delete(WatchHistory).where(WatchHistory.user_id == current_user.id))
    w_res = await db.execute(delete(WatchlistItem).where(WatchlistItem.user_id == current_user.id))
    s_res = await db.execute(delete(PlaybackSession).where(PlaybackSession.user_id == current_user.id))
    await db.commit()
    return {
        "status": "reset_complete",
        "deleted_history": int(h_res.rowcount or 0),
        "deleted_watchlist": int(w_res.rowcount or 0),
        "deleted_sessions": int(s_res.rowcount or 0),
    }
