import uuid
from datetime import datetime
from typing import Optional

from sqlalchemy import (
    Boolean,
    DateTime,
    Float,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
    Uuid,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TimestampMixin


class User(Base, TimestampMixin):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True, nullable=False)
    full_name: Mapped[str] = mapped_column(String(120), nullable=False)
    password_hash: Mapped[str] = mapped_column(String(512), nullable=False)
    avatar_url: Mapped[Optional[str]] = mapped_column(String(512), nullable=True)
    preferred_language: Mapped[str] = mapped_column(String(16), default="vi-VN", nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    refresh_tokens: Mapped[list["RefreshToken"]] = relationship(
        back_populates="user", cascade="all, delete-orphan"
    )
    watchlist_items: Mapped[list["WatchlistItem"]] = relationship(
        back_populates="user", cascade="all, delete-orphan"
    )
    watch_history: Mapped[list["WatchHistory"]] = relationship(
        back_populates="user", cascade="all, delete-orphan"
    )
    playback_sessions: Mapped[list["PlaybackSession"]] = relationship(
        back_populates="user", cascade="all, delete-orphan"
    )


class RefreshToken(Base, TimestampMixin):
    __tablename__ = "refresh_tokens"

    id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    token_hash: Mapped[str] = mapped_column(String(128), unique=True, index=True, nullable=False)
    jti: Mapped[str] = mapped_column(String(64), unique=True, index=True, nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    revoked_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    device_info: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)

    user: Mapped["User"] = relationship(back_populates="refresh_tokens")


class WatchlistItem(Base, TimestampMixin):
    __tablename__ = "watchlist_items"
    __table_args__ = (
        UniqueConstraint("user_id", "tmdb_id", "content_type", name="uq_watchlist_user_title"),
        Index("ix_watchlist_user_created", "user_id", "created_at"),
    )

    id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    tmdb_id: Mapped[int] = mapped_column(Integer, index=True, nullable=False)
    content_type: Mapped[str] = mapped_column(String(16), nullable=False)  # "movie" | "tv"
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    poster_path: Mapped[Optional[str]] = mapped_column(String(512), nullable=True)
    backdrop_path: Mapped[Optional[str]] = mapped_column(String(512), nullable=True)
    vote_average: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)
    release_year: Mapped[Optional[str]] = mapped_column(String(16), nullable=True)

    user: Mapped["User"] = relationship(back_populates="watchlist_items")


class VideoAsset(Base, TimestampMixin):
    __tablename__ = "video_assets"
    __table_args__ = (
        Index("ix_video_assets_tmdb_lookup", "tmdb_id", "content_type", "season_number", "episode_number"),
    )

    id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    tmdb_id: Mapped[int] = mapped_column(Integer, index=True, nullable=False)
    content_type: Mapped[str] = mapped_column(String(16), nullable=False)  # "movie" | "tv"
    season_number: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    episode_number: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    synopsis: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    poster_url: Mapped[Optional[str]] = mapped_column(String(512), nullable=True)
    backdrop_url: Mapped[Optional[str]] = mapped_column(String(512), nullable=True)
    duration_seconds: Mapped[int] = mapped_column(Integer, nullable=False)
    provider_category: Mapped[str] = mapped_column(
        String(32), nullable=False
    )  # "licensed_hls" | "self_hosted" | "public_demo"
    license_name: Mapped[str] = mapped_column(String(255), nullable=False)
    license_url: Mapped[str] = mapped_column(String(512), nullable=False)
    attribution: Mapped[str] = mapped_column(Text, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    sources: Mapped[list["VideoSource"]] = relationship(
        back_populates="asset", cascade="all, delete-orphan"
    )
    subtitles: Mapped[list["SubtitleTrack"]] = relationship(
        back_populates="asset", cascade="all, delete-orphan"
    )
    audio_tracks: Mapped[list["AudioTrack"]] = relationship(
        back_populates="asset", cascade="all, delete-orphan"
    )
    playback_sessions: Mapped[list["PlaybackSession"]] = relationship(
        back_populates="asset", cascade="all, delete-orphan"
    )


class VideoSource(Base, TimestampMixin):
    __tablename__ = "video_sources"

    id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    asset_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("video_assets.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    stream_type: Mapped[str] = mapped_column(String(16), default="hls", nullable=False)
    manifest_url: Mapped[str] = mapped_column(String(1024), nullable=False)
    quality_label: Mapped[str] = mapped_column(String(32), default="Auto (ABR)", nullable=False)
    bandwidth_kbps: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    requires_signing: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    asset: Mapped["VideoAsset"] = relationship(back_populates="sources")


class SubtitleTrack(Base, TimestampMixin):
    __tablename__ = "subtitle_tracks"

    id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    asset_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("video_assets.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    language_code: Mapped[str] = mapped_column(String(16), nullable=False)
    label: Mapped[str] = mapped_column(String(64), nullable=False)
    format: Mapped[str] = mapped_column(String(16), default="vtt", nullable=False)
    url: Mapped[str] = mapped_column(String(1024), nullable=False)
    is_default: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    asset: Mapped["VideoAsset"] = relationship(back_populates="subtitles")


class AudioTrack(Base, TimestampMixin):
    __tablename__ = "audio_tracks"

    id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    asset_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("video_assets.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    language_code: Mapped[str] = mapped_column(String(16), nullable=False)
    label: Mapped[str] = mapped_column(String(64), nullable=False)
    channels: Mapped[str] = mapped_column(String(16), default="2.0", nullable=False)
    is_default: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    asset: Mapped["VideoAsset"] = relationship(back_populates="audio_tracks")


class PlaybackSession(Base, TimestampMixin):
    __tablename__ = "playback_sessions"

    id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    asset_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("video_assets.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    session_token_hash: Mapped[str] = mapped_column(String(128), unique=True, index=True, nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    last_heartbeat_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    current_position_seconds: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    user: Mapped["User"] = relationship(back_populates="playback_sessions")
    asset: Mapped["VideoAsset"] = relationship(back_populates="playback_sessions")


class WatchHistory(Base, TimestampMixin):
    __tablename__ = "watch_history"
    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "tmdb_id",
            "content_type",
            "season_key",
            "episode_key",
            name="uq_watch_history_user_item",
        ),
        Index("ix_watch_history_user_last_watched", "user_id", "last_watched_at"),
    )

    id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    tmdb_id: Mapped[int] = mapped_column(Integer, index=True, nullable=False)
    content_type: Mapped[str] = mapped_column(String(16), nullable=False)  # "movie" | "tv"
    season_number: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    episode_number: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    season_key: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    episode_key: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    asset_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("video_assets.id", ondelete="SET NULL"),
        nullable=True,
    )
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    poster_path: Mapped[Optional[str]] = mapped_column(String(512), nullable=True)
    backdrop_path: Mapped[Optional[str]] = mapped_column(String(512), nullable=True)
    current_position_seconds: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    duration_seconds: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    is_completed: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    last_watched_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)

    user: Mapped["User"] = relationship(back_populates="watch_history")


class ProviderMapping(Base, TimestampMixin):
    __tablename__ = "provider_mappings"
    __table_args__ = (
        UniqueConstraint(
            "tmdb_id",
            "content_type",
            "region",
            "provider_name",
            name="uq_provider_mapping_title_region",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    tmdb_id: Mapped[int] = mapped_column(Integer, index=True, nullable=False)
    content_type: Mapped[str] = mapped_column(String(16), nullable=False)
    region: Mapped[str] = mapped_column(String(8), default="VN", nullable=False)
    provider_type: Mapped[str] = mapped_column(
        String(32), nullable=False
    )  # "internal_asset" | "external_watch_provider"
    provider_name: Mapped[str] = mapped_column(String(120), nullable=False)
    monetization_type: Mapped[str] = mapped_column(
        String(32), default="flatrate", nullable=False
    )  # "flatrate" | "rent" | "buy" | "free"
    logo_path: Mapped[Optional[str]] = mapped_column(String(512), nullable=True)
    external_watch_url: Mapped[Optional[str]] = mapped_column(String(1024), nullable=True)
    asset_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("video_assets.id", ondelete="SET NULL"),
        nullable=True,
    )
