from datetime import datetime
from typing import Literal, Optional
import uuid

from pydantic import BaseModel, ConfigDict, EmailStr, Field


# ==============================================================================
# Authentication Schemas
# ==============================================================================


class RegisterRequest(BaseModel):
    email: EmailStr
    full_name: str = Field(..., min_length=2, max_length=120)
    password: str = Field(..., min_length=8, max_length=128)
    preferred_language: str = Field(default="vi-VN", max_length=16)


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=1, max_length=128)
    device_info: Optional[str] = Field(default=None, max_length=255)


class RefreshTokenRequest(BaseModel):
    refresh_token: str = Field(..., min_length=16)


class LogoutRequest(BaseModel):
    refresh_token: Optional[str] = None


class UserResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    email: EmailStr
    full_name: str
    avatar_url: Optional[str] = None
    preferred_language: str
    created_at: datetime


class AuthTokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "Bearer"
    expires_in: int
    user: UserResponse


# ==============================================================================
# Catalog & Metadata Schemas (Normalized VSMOV + TMDB Enrichment)
# ==============================================================================


class GenreItem(BaseModel):
    id: int
    name: str
    slug: Optional[str] = None


class CountryItem(BaseModel):
    id: int
    name: str
    slug: str


class MediaSummary(BaseModel):
    tmdb_id: int
    slug: Optional[str] = None
    content_type: Literal["movie", "tv"]
    title: str
    original_title: Optional[str] = None
    overview: str = ""
    poster_url: Optional[str] = None
    backdrop_url: Optional[str] = None
    release_date: Optional[str] = None
    vote_average: float = 0.0
    vote_count: int = 0
    quality: Optional[str] = None
    lang: Optional[str] = None
    episode_current: Optional[str] = None
    genre_ids: list[int] = Field(default_factory=list)
    category_slugs: list[str] = Field(default_factory=list)
    country_slugs: list[str] = Field(default_factory=list)
    availability_badge: Literal["playable", "external", "metadata_only"] = "metadata_only"
    playable_asset_id: Optional[uuid.UUID] = None


class PaginatedMediaResponse(BaseModel):
    page: int
    total_pages: int
    total_results: int
    results: list[MediaSummary]


class CastMember(BaseModel):
    id: int
    name: str
    character: Optional[str] = None
    profile_url: Optional[str] = None


class VideoTrailer(BaseModel):
    id: str
    key: str
    name: str
    site: str
    type: str
    youtube_url: Optional[str] = None


class ExternalProviderBadge(BaseModel):
    provider_name: str
    monetization_type: str
    logo_url: Optional[str] = None
    external_watch_url: Optional[str] = None
    region: str = "VN"


class PlayableAssetSummary(BaseModel):
    asset_id: uuid.UUID
    provider_category: str
    duration_seconds: int
    license_name: str
    license_url: str
    attribution: str
    season_number: Optional[int] = None
    episode_number: Optional[int] = None


class ParsedEpisodeSource(BaseModel):
    """Separate playback-source model parsed from VSMOV server/episode metadata.
    Does NOT automatically grant internal playback unless is_authorized_direct_stream is True.
    """

    server_name: str
    episode_name: str
    episode_slug: str
    filename: Optional[str] = None
    embed_url: Optional[str] = None
    direct_stream_url: Optional[str] = None
    is_authorized_direct_stream: bool = False
    playable_asset_id: Optional[uuid.UUID] = None


class ParsedServerGroup(BaseModel):
    server_name: str
    episodes: list[ParsedEpisodeSource] = Field(default_factory=list)


class AvailabilityResponse(BaseModel):
    tmdb_id: int
    slug: Optional[str] = None
    content_type: Literal["movie", "tv"]
    region: str
    is_directly_playable: bool
    availability_type: Literal["playable", "external", "metadata_only"]
    playable_assets: list[PlayableAssetSummary] = Field(default_factory=list)
    external_providers: list[ExternalProviderBadge] = Field(default_factory=list)
    catalog_servers: list[ParsedServerGroup] = Field(default_factory=list)


class MovieDetailResponse(BaseModel):
    tmdb_id: int
    slug: Optional[str] = None
    content_type: Literal["movie", "tv"] = "movie"
    title: str
    original_title: str
    overview: str
    poster_url: Optional[str] = None
    backdrop_url: Optional[str] = None
    release_date: Optional[str] = None
    runtime_minutes: Optional[int] = None
    duration_label: Optional[str] = None
    quality: Optional[str] = None
    lang: Optional[str] = None
    episode_current: Optional[str] = None
    episode_total: Optional[str] = None
    vote_average: float = 0.0
    vote_count: int = 0
    genres: list[GenreItem] = Field(default_factory=list)
    countries: list[CountryItem] = Field(default_factory=list)
    director: Optional[str] = None
    cast: list[CastMember] = Field(default_factory=list)
    trailers: list[VideoTrailer] = Field(default_factory=list)
    recommendations: list[MediaSummary] = Field(default_factory=list)
    similar: list[MediaSummary] = Field(default_factory=list)
    availability: AvailabilityResponse


class SeasonSummary(BaseModel):
    id: int
    season_number: int
    name: str
    episode_count: int
    overview: str = ""
    poster_url: Optional[str] = None
    air_date: Optional[str] = None


class EpisodeItem(BaseModel):
    id: int
    episode_number: int
    season_number: int
    name: str
    slug: Optional[str] = None
    server_name: Optional[str] = None
    overview: str = ""
    still_url: Optional[str] = None
    air_date: Optional[str] = None
    runtime_minutes: Optional[int] = None
    vote_average: float = 0.0
    is_playable: bool = False
    playable_asset_id: Optional[uuid.UUID] = None
    embed_reference_url: Optional[str] = None


class SeasonDetailResponse(BaseModel):
    tmdb_id: int
    slug: Optional[str] = None
    season_number: int
    name: str
    overview: str = ""
    poster_url: Optional[str] = None
    episodes: list[EpisodeItem] = Field(default_factory=list)


class TvDetailResponse(BaseModel):
    tmdb_id: int
    slug: Optional[str] = None
    content_type: Literal["tv"] = "tv"
    title: str
    original_title: str
    overview: str
    poster_url: Optional[str] = None
    backdrop_url: Optional[str] = None
    first_air_date: Optional[str] = None
    quality: Optional[str] = None
    lang: Optional[str] = None
    episode_current: Optional[str] = None
    episode_total: Optional[str] = None
    number_of_seasons: int = 0
    number_of_episodes: int = 0
    vote_average: float = 0.0
    vote_count: int = 0
    genres: list[GenreItem] = Field(default_factory=list)
    countries: list[CountryItem] = Field(default_factory=list)
    cast: list[CastMember] = Field(default_factory=list)
    trailers: list[VideoTrailer] = Field(default_factory=list)
    seasons: list[SeasonSummary] = Field(default_factory=list)
    recommendations: list[MediaSummary] = Field(default_factory=list)
    similar: list[MediaSummary] = Field(default_factory=list)
    availability: AvailabilityResponse


class HomeFeedResponse(BaseModel):
    featured_hero: list[MediaSummary] = Field(default_factory=list)
    trending_today: list[MediaSummary] = Field(default_factory=list)
    popular_movies: list[MediaSummary] = Field(default_factory=list)
    popular_tv_series: list[MediaSummary] = Field(default_factory=list)
    top_rated_movies: list[MediaSummary] = Field(default_factory=list)
    korean_movies: list[MediaSummary] = Field(default_factory=list)
    chinese_movies: list[MediaSummary] = Field(default_factory=list)
    hollywood_movies: list[MediaSummary] = Field(default_factory=list)
    animation_movies: list[MediaSummary] = Field(default_factory=list)
    continue_watching: list["WatchHistoryItemResponse"] = Field(default_factory=list)
    recommended_titles: list[MediaSummary] = Field(default_factory=list)
    recently_added_playable: list[MediaSummary] = Field(default_factory=list)
    tmdb_configured: bool = True
    primary_provider: str = "vsmov"
    upstream_notice: Optional[str] = None


# ==============================================================================
# Playback Schemas
# ==============================================================================


class CreatePlaybackSessionRequest(BaseModel):
    asset_id: uuid.UUID
    resume_from_history: bool = True


class SubtitleTrackSchema(BaseModel):
    id: uuid.UUID
    language_code: str
    label: str
    format: str
    url: str
    is_default: bool


class AudioTrackSchema(BaseModel):
    id: uuid.UUID
    language_code: str
    label: str
    channels: str
    is_default: bool


class StreamSourceSchema(BaseModel):
    stream_type: str
    manifest_url: str
    quality_label: str
    bandwidth_kbps: Optional[int] = None


class PlaybackSessionResponse(BaseModel):
    session_id: uuid.UUID
    asset_id: uuid.UUID
    tmdb_id: int
    content_type: str
    season_number: Optional[int] = None
    episode_number: Optional[int] = None
    title: str
    duration_seconds: int
    resume_position_seconds: int = 0
    expires_at: datetime
    license_name: str
    license_url: str
    attribution: str
    sources: list[StreamSourceSchema]
    subtitles: list[SubtitleTrackSchema]
    audio_tracks: list[AudioTrackSchema]


class PlaybackHeartbeatRequest(BaseModel):
    position_seconds: int = Field(..., ge=0)
    duration_seconds: Optional[int] = Field(default=None, ge=1)
    is_paused: bool = False


class PlaybackHeartbeatResponse(BaseModel):
    session_id: uuid.UUID
    expires_at: datetime
    position_seconds: int
    is_completed: bool


# ==============================================================================
# Watchlist & Watch History Schemas
# ==============================================================================


class WatchlistCreateRequest(BaseModel):
    tmdb_id: int = Field(..., ge=1)
    slug: Optional[str] = Field(default=None, max_length=255)
    content_type: Literal["movie", "tv"]
    title: str = Field(..., min_length=1, max_length=255)
    poster_path: Optional[str] = Field(default=None, max_length=512)
    backdrop_path: Optional[str] = Field(default=None, max_length=512)
    vote_average: float = Field(default=0.0, ge=0.0, le=10.0)
    release_year: Optional[str] = Field(default=None, max_length=16)


class WatchlistItemResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    tmdb_id: int
    content_type: str
    title: str
    poster_path: Optional[str] = None
    backdrop_path: Optional[str] = None
    vote_average: float
    release_year: Optional[str] = None
    created_at: datetime


class ProgressUpdateRequest(BaseModel):
    tmdb_id: int = Field(..., ge=1)
    content_type: Literal["movie", "tv"]
    season_number: Optional[int] = Field(default=None, ge=1)
    episode_number: Optional[int] = Field(default=None, ge=1)
    asset_id: Optional[uuid.UUID] = None
    title: str = Field(..., min_length=1, max_length=255)
    poster_path: Optional[str] = Field(default=None, max_length=512)
    backdrop_path: Optional[str] = Field(default=None, max_length=512)
    current_position_seconds: int = Field(..., ge=0)
    duration_seconds: int = Field(..., ge=1)
    is_completed: Optional[bool] = None


class WatchHistoryItemResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    tmdb_id: int
    content_type: str
    season_number: Optional[int] = None
    episode_number: Optional[int] = None
    asset_id: Optional[uuid.UUID] = None
    title: str
    poster_path: Optional[str] = None
    backdrop_path: Optional[str] = None
    current_position_seconds: int
    duration_seconds: int
    progress_ratio: float
    is_completed: bool
    last_watched_at: datetime


HomeFeedResponse.model_rebuild()
