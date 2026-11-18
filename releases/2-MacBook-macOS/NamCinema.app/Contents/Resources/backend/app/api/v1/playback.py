from datetime import datetime, timedelta, timezone
import json
import re
from urllib.parse import quote, urljoin, urlparse
import uuid

from fastapi import APIRouter, Depends, Query, Response, status
import httpx
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.exceptions import AuthorizationError, ResourceNotFoundError
from app.db.session import get_db_session
from app.models.entities import PlaybackSession, User, VideoAsset
from app.providers.streaming import (
    LicensedHlsProvider,
    PublicDemoContentProvider,
    SelfHostedLibraryProvider,
)
from app.repositories.library import LibraryRepository
from app.schemas.api import (
    AvailabilityResponse,
    CreatePlaybackSessionRequest,
    PlaybackHeartbeatRequest,
    PlaybackHeartbeatResponse,
    PlaybackSessionResponse,
)
from app.security.auth import get_current_user
from app.services.catalog import CatalogService

router = APIRouter(tags=["Playback"])

_VSMOV_STREAM_CLIENT: httpx.AsyncClient | None = None


def _get_vsmov_stream_client() -> httpx.AsyncClient:
    global _VSMOV_STREAM_CLIENT
    if _VSMOV_STREAM_CLIENT is None or _VSMOV_STREAM_CLIENT.is_closed:
        _VSMOV_STREAM_CLIENT = httpx.AsyncClient(
            timeout=httpx.Timeout(25.0, connect=10.0),
            follow_redirects=True,
            limits=httpx.Limits(max_keepalive_connections=25, max_connections=50),
            headers={
                "User-Agent": (
                    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                    "AppleWebKit/537.36 (KHTML, like Gecko) "
                    "Chrome/131.0.0.0 Safari/537.36"
                ),
            },
        )
    return _VSMOV_STREAM_CLIENT


def _validate_vsmov_url(raw_url: str) -> str:
    url = (raw_url or "").strip()
    parsed = urlparse(url)
    host = (parsed.hostname or "").lower()
    if parsed.scheme not in {"http", "https"} or not (
        host == "vsmov.com"
        or host.endswith(".vsmov.com")
        or host == "streamvsmov.com"
        or host.endswith(".streamvsmov.com")
    ):
        raise AuthorizationError("URL does not belong to an allowed VSMOV streaming host.")
    return url


def _find_mpegts_offset(data: bytes) -> int:
    limit = min(16384, len(data) - 376)
    if limit <= 0:
        return 0
    for i in range(limit):
        if data[i] == 0x47 and data[i + 188] == 0x47 and data[i + 376] == 0x47:
            return i
    return 0


@router.get("/playback/vsmov-resolve")
async def resolve_vsmov_embed(
    embed_url: str = Query(..., min_length=10),
) -> dict:
    safe_embed_url = _validate_vsmov_url(embed_url)
    parsed_embed = urlparse(safe_embed_url)
    default_origin = f"{parsed_embed.scheme}://{parsed_embed.netloc}"

    client = _get_vsmov_stream_client()
    resp = await client.get(safe_embed_url, headers={"Referer": "https://vsmov.com/"})
    if resp.status_code >= 400:
        raise ResourceNotFoundError(f"Upstream stream server returned HTTP {resp.status_code}.")

    html = resp.text

    m_base = re.search(r'const\s+baseUrl\s*=\s*"([^"]+)"', html)
    base_url = (m_base.group(1).strip().rstrip("/") if m_base else default_origin)

    m_hash = re.search(r'const\s+videoHash\s*=\s*"([^"]+)"', html) or re.search(
        r'data-hash="([^"]+)"', html
    )
    if m_hash:
        video_hash = m_hash.group(1).strip()
    else:
        video_hash = parsed_embed.path.rstrip("/").split("/")[-1]

    m_signed = re.search(r'signedMasterUrl\s*:\s*"([^"]*)"', html)
    signed_url = m_signed.group(1).strip() if m_signed else ""

    master_url = signed_url if signed_url else f"{base_url}/stream/{video_hash}/master.m3u8"
    _validate_vsmov_url(master_url)

    subtitles: list[dict[str, str | bool]] = []
    m_subs = re.search(r"subtitles\s*:\s*(\[.*?\])\s*,\s*audios", html, re.S)
    if not m_subs:
        m_subs = re.search(r"subtitles\s*:\s*(\[[^\]]*\])", html)
    if m_subs:
        try:
            raw_subs = json.loads(m_subs.group(1))
            if isinstance(raw_subs, list):
                for idx, sub in enumerate(raw_subs):
                    if not isinstance(sub, dict):
                        continue
                    sub_path = str(sub.get("url") or "").strip()
                    if not sub_path:
                        continue
                    full_sub_url = (
                        sub_path
                        if sub_path.startswith(("http://", "https://"))
                        else f"{base_url}/{sub_path.lstrip('/')}"
                    )
                    code = str(sub.get("code") or sub.get("name") or "vie").lower()
                    if code.startswith("vie") or "vi" in code:
                        label = "Tiếng Việt"
                        srclang = "vi"
                    elif code.startswith("eng") or "en" in code:
                        label = "English"
                        srclang = "en"
                    else:
                        label = str(sub.get("name") or code.upper())
                        srclang = code[:2] or "vi"

                    subtitles.append(
                        {
                            "label": label,
                            "srclang": srclang,
                            "default": srclang == "vi" or idx == 0,
                            "url": (
                                f"/api/v1/playback/vsmov-vtt?url={quote(full_sub_url, safe='')}"
                                f"&origin={quote(base_url, safe='')}"
                            ),
                        }
                    )
        except Exception:
            pass

    subtitles.sort(key=lambda s: 0 if s.get("srclang") == "vi" else 1)
    for i, s in enumerate(subtitles):
        s["default"] = i == 0

    manifest_proxy_url = (
        f"/api/v1/playback/vsmov-m3u8?url={quote(master_url, safe='')}"
        f"&origin={quote(base_url, safe='')}"
    )

    return {
        "embed_url": safe_embed_url,
        "origin": base_url,
        "video_hash": video_hash,
        "manifest_url": manifest_proxy_url,
        "subtitles": subtitles,
    }


@router.get("/playback/vsmov-m3u8")
async def proxy_vsmov_m3u8(
    url: str = Query(..., min_length=10),
    origin: str = Query(default=""),
) -> Response:
    safe_url = _validate_vsmov_url(url)
    parsed = urlparse(safe_url)
    base_origin = _validate_vsmov_url(origin) if origin else f"{parsed.scheme}://{parsed.netloc}"

    client = _get_vsmov_stream_client()
    resp = await client.get(
        safe_url,
        headers={
            "Origin": base_origin,
            "Referer": base_origin + "/",
        },
    )
    if resp.status_code >= 400:
        raise ResourceNotFoundError(f"Playlist fetch failed with HTTP {resp.status_code}.")

    out_lines: list[str] = []
    for raw_line in resp.text.splitlines():
        line = raw_line.strip()
        if not line:
            out_lines.append("")
            continue
        if line.startswith("#"):
            out_lines.append(line)
            continue

        target_url = urljoin(safe_url, line)
        target_path = urlparse(target_url).path.lower()
        if target_path.endswith(".m3u8"):
            rewritten = (
                f"/api/v1/playback/vsmov-m3u8?url={quote(target_url, safe='')}"
                f"&origin={quote(base_origin, safe='')}"
            )
        else:
            rewritten = (
                f"/api/v1/playback/vsmov-seg?url={quote(target_url, safe='')}"
                f"&origin={quote(base_origin, safe='')}"
            )
        out_lines.append(rewritten)

    content = "\n".join(out_lines) + "\n"
    return Response(
        content=content,
        media_type="application/vnd.apple.mpegurl",
        headers={
            "Cache-Control": "no-cache",
            "Access-Control-Allow-Origin": "*",
        },
    )


@router.get("/playback/vsmov-seg")
async def proxy_vsmov_segment(
    url: str = Query(..., min_length=10),
    origin: str = Query(default=""),
) -> Response:
    safe_url = _validate_vsmov_url(url)
    headers: dict[str, str] = {}
    if origin:
        safe_origin = _validate_vsmov_url(origin)
        headers["Origin"] = safe_origin
        headers["Referer"] = safe_origin + "/"

    client = _get_vsmov_stream_client()
    resp = await client.get(safe_url, headers=headers)
    if resp.status_code >= 400:
        raise ResourceNotFoundError(f"Segment fetch failed with HTTP {resp.status_code}.")

    data = resp.content
    ts_offset = _find_mpegts_offset(data)
    clean_data = data[ts_offset:] if ts_offset > 0 else data

    return Response(
        content=clean_data,
        media_type="video/mp2t",
        headers={
            "Cache-Control": "public, max-age=3600",
            "Access-Control-Allow-Origin": "*",
        },
    )


@router.get("/playback/vsmov-vtt")
async def proxy_vsmov_subtitle(
    url: str = Query(..., min_length=10),
    origin: str = Query(default=""),
) -> Response:
    safe_url = _validate_vsmov_url(url)
    headers: dict[str, str] = {}
    if origin:
        safe_origin = _validate_vsmov_url(origin)
        headers["Origin"] = safe_origin
        headers["Referer"] = safe_origin + "/"

    client = _get_vsmov_stream_client()
    resp = await client.get(safe_url, headers=headers)
    if resp.status_code >= 400:
        raise ResourceNotFoundError(f"Subtitle fetch failed with HTTP {resp.status_code}.")

    return Response(
        content=resp.content,
        media_type="text/vtt; charset=utf-8",
        headers={
            "Cache-Control": "public, max-age=3600",
            "Access-Control-Allow-Origin": "*",
        },
    )



@router.get("/titles/{id}/availability", response_model=AvailabilityResponse)
async def get_title_availability(
    id: str,
    region: str = Query(default="VN", max_length=4),
    db: AsyncSession = Depends(get_db_session),
) -> AvailabilityResponse:
    service = CatalogService(db)
    return await service.get_title_availability(title_id=id, region=region)


@router.post(
    "/playback/sessions",
    response_model=PlaybackSessionResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_playback_session(
    payload: CreatePlaybackSessionRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> PlaybackSessionResponse:
    stmt = select(VideoAsset).where(
        VideoAsset.id == payload.asset_id,
        VideoAsset.is_active.is_(True),
    )
    asset = (await db.execute(stmt)).scalar_one_or_none()
    if asset is None:
        raise ResourceNotFoundError("Playable video asset was not found or is inactive.")

    provider_map = {
        "licensed_hls": LicensedHlsProvider(db),
        "self_hosted": SelfHostedLibraryProvider(db),
        "public_demo": PublicDemoContentProvider(db),
    }
    provider = provider_map.get(asset.provider_category)
    if provider is None:
        raise AuthorizationError("Unsupported streaming provider category for this asset.")

    session_data = await provider.create_playback_session(
        asset_id=str(asset.id),
        user_id=str(current_user.id),
    )
    if not payload.resume_from_history:
        session_data["resume_position_seconds"] = 0

    return PlaybackSessionResponse(**session_data)


@router.post("/playback/sessions/{id}/heartbeat", response_model=PlaybackHeartbeatResponse)
async def heartbeat_playback_session(
    id: uuid.UUID,
    payload: PlaybackHeartbeatRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> PlaybackHeartbeatResponse:
    stmt = select(PlaybackSession).where(
        PlaybackSession.id == id,
        PlaybackSession.user_id == current_user.id,
    )
    session_row = (await db.execute(stmt)).scalar_one_or_none()
    if session_row is None:
        raise ResourceNotFoundError("Playback session not found.")

    now = datetime.now(timezone.utc)
    expires_at = session_row.expires_at
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)

    if not session_row.is_active or expires_at <= now:
        raise AuthorizationError("Playback session has expired. Please request a new playback session.")

    asset_stmt = select(VideoAsset).where(VideoAsset.id == session_row.asset_id)
    asset = (await db.execute(asset_stmt)).scalar_one_or_none()
    if asset is None:
        raise ResourceNotFoundError("Associated video asset not found.")

    settings = get_settings()
    new_expires_at = now + timedelta(minutes=settings.PLAYBACK_SESSION_TTL_MINUTES)
    session_row.last_heartbeat_at = now
    session_row.expires_at = new_expires_at
    session_row.current_position_seconds = payload.position_seconds

    repo = LibraryRepository(db)
    history = await repo.upsert_progress(
        user_id=current_user.id,
        tmdb_id=asset.tmdb_id,
        content_type=asset.content_type,
        season_number=asset.season_number,
        episode_number=asset.episode_number,
        asset_id=asset.id,
        title=asset.title,
        poster_path=asset.poster_url,
        backdrop_path=asset.backdrop_url,
        current_position_seconds=payload.position_seconds,
        duration_seconds=payload.duration_seconds or asset.duration_seconds,
    )

    return PlaybackHeartbeatResponse(
        session_id=session_row.id,
        expires_at=new_expires_at,
        position_seconds=history.current_position_seconds,
        is_completed=history.is_completed,
    )


@router.delete("/playback/sessions/{id}", status_code=status.HTTP_200_OK)
async def end_playback_session(
    id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> dict[str, str]:
    stmt = select(PlaybackSession).where(
        PlaybackSession.id == id,
        PlaybackSession.user_id == current_user.id,
    )
    session_row = (await db.execute(stmt)).scalar_one_or_none()
    if session_row is None:
        raise ResourceNotFoundError("Playback session not found.")

    session_row.is_active = False
    await db.commit()
    return {"status": "ended"}
