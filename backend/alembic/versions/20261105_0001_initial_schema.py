"""Initial Nam Cinema schema

Revision ID: 20261105_0001
Revises: None
Create Date: 2026-11-05 14:30:00

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "20261105_0001"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", sa.Uuid(as_uuid=True), primary_key=True, nullable=False),
        sa.Column("email", sa.String(length=255), nullable=False),
        sa.Column("full_name", sa.String(length=120), nullable=False),
        sa.Column("password_hash", sa.String(length=512), nullable=False),
        sa.Column("avatar_url", sa.String(length=512), nullable=True),
        sa.Column("preferred_language", sa.String(length=16), nullable=False, server_default="vi-VN"),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_users_email", "users", ["email"], unique=True)

    op.create_table(
        "refresh_tokens",
        sa.Column("id", sa.Uuid(as_uuid=True), primary_key=True, nullable=False),
        sa.Column("user_id", sa.Uuid(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("token_hash", sa.String(length=128), nullable=False),
        sa.Column("jti", sa.String(length=64), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("revoked_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("device_info", sa.String(length=255), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_refresh_tokens_user_id", "refresh_tokens", ["user_id"], unique=False)
    op.create_index("ix_refresh_tokens_token_hash", "refresh_tokens", ["token_hash"], unique=True)
    op.create_index("ix_refresh_tokens_jti", "refresh_tokens", ["jti"], unique=True)

    op.create_table(
        "watchlist_items",
        sa.Column("id", sa.Uuid(as_uuid=True), primary_key=True, nullable=False),
        sa.Column("user_id", sa.Uuid(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("tmdb_id", sa.Integer(), nullable=False),
        sa.Column("content_type", sa.String(length=16), nullable=False),
        sa.Column("title", sa.String(length=255), nullable=False),
        sa.Column("poster_path", sa.String(length=512), nullable=True),
        sa.Column("backdrop_path", sa.String(length=512), nullable=True),
        sa.Column("vote_average", sa.Float(), nullable=False, server_default="0.0"),
        sa.Column("release_year", sa.String(length=16), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("user_id", "tmdb_id", "content_type", name="uq_watchlist_user_title"),
    )
    op.create_index("ix_watchlist_items_user_id", "watchlist_items", ["user_id"], unique=False)
    op.create_index("ix_watchlist_items_tmdb_id", "watchlist_items", ["tmdb_id"], unique=False)
    op.create_index("ix_watchlist_user_created", "watchlist_items", ["user_id", "created_at"], unique=False)

    op.create_table(
        "video_assets",
        sa.Column("id", sa.Uuid(as_uuid=True), primary_key=True, nullable=False),
        sa.Column("tmdb_id", sa.Integer(), nullable=False),
        sa.Column("content_type", sa.String(length=16), nullable=False),
        sa.Column("season_number", sa.Integer(), nullable=True),
        sa.Column("episode_number", sa.Integer(), nullable=True),
        sa.Column("title", sa.String(length=255), nullable=False),
        sa.Column("synopsis", sa.Text(), nullable=True),
        sa.Column("poster_url", sa.String(length=512), nullable=True),
        sa.Column("backdrop_url", sa.String(length=512), nullable=True),
        sa.Column("duration_seconds", sa.Integer(), nullable=False),
        sa.Column("provider_category", sa.String(length=32), nullable=False),
        sa.Column("license_name", sa.String(length=255), nullable=False),
        sa.Column("license_url", sa.String(length=512), nullable=False),
        sa.Column("attribution", sa.Text(), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_video_assets_tmdb_id", "video_assets", ["tmdb_id"], unique=False)
    op.create_index(
        "ix_video_assets_tmdb_lookup",
        "video_assets",
        ["tmdb_id", "content_type", "season_number", "episode_number"],
        unique=False,
    )

    op.create_table(
        "video_sources",
        sa.Column("id", sa.Uuid(as_uuid=True), primary_key=True, nullable=False),
        sa.Column("asset_id", sa.Uuid(as_uuid=True), sa.ForeignKey("video_assets.id", ondelete="CASCADE"), nullable=False),
        sa.Column("stream_type", sa.String(length=16), nullable=False, server_default="hls"),
        sa.Column("manifest_url", sa.String(length=1024), nullable=False),
        sa.Column("quality_label", sa.String(length=32), nullable=False, server_default="Auto (ABR)"),
        sa.Column("bandwidth_kbps", sa.Integer(), nullable=True),
        sa.Column("requires_signing", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_video_sources_asset_id", "video_sources", ["asset_id"], unique=False)

    op.create_table(
        "subtitle_tracks",
        sa.Column("id", sa.Uuid(as_uuid=True), primary_key=True, nullable=False),
        sa.Column("asset_id", sa.Uuid(as_uuid=True), sa.ForeignKey("video_assets.id", ondelete="CASCADE"), nullable=False),
        sa.Column("language_code", sa.String(length=16), nullable=False),
        sa.Column("label", sa.String(length=64), nullable=False),
        sa.Column("format", sa.String(length=16), nullable=False, server_default="vtt"),
        sa.Column("url", sa.String(length=1024), nullable=False),
        sa.Column("is_default", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_subtitle_tracks_asset_id", "subtitle_tracks", ["asset_id"], unique=False)

    op.create_table(
        "audio_tracks",
        sa.Column("id", sa.Uuid(as_uuid=True), primary_key=True, nullable=False),
        sa.Column("asset_id", sa.Uuid(as_uuid=True), sa.ForeignKey("video_assets.id", ondelete="CASCADE"), nullable=False),
        sa.Column("language_code", sa.String(length=16), nullable=False),
        sa.Column("label", sa.String(length=64), nullable=False),
        sa.Column("channels", sa.String(length=16), nullable=False, server_default="2.0"),
        sa.Column("is_default", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_audio_tracks_asset_id", "audio_tracks", ["asset_id"], unique=False)

    op.create_table(
        "playback_sessions",
        sa.Column("id", sa.Uuid(as_uuid=True), primary_key=True, nullable=False),
        sa.Column("user_id", sa.Uuid(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("asset_id", sa.Uuid(as_uuid=True), sa.ForeignKey("video_assets.id", ondelete="CASCADE"), nullable=False),
        sa.Column("session_token_hash", sa.String(length=128), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("last_heartbeat_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("current_position_seconds", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_playback_sessions_user_id", "playback_sessions", ["user_id"], unique=False)
    op.create_index("ix_playback_sessions_asset_id", "playback_sessions", ["asset_id"], unique=False)
    op.create_index(
        "ix_playback_sessions_session_token_hash",
        "playback_sessions",
        ["session_token_hash"],
        unique=True,
    )

    op.create_table(
        "watch_history",
        sa.Column("id", sa.Uuid(as_uuid=True), primary_key=True, nullable=False),
        sa.Column("user_id", sa.Uuid(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("tmdb_id", sa.Integer(), nullable=False),
        sa.Column("content_type", sa.String(length=16), nullable=False),
        sa.Column("season_number", sa.Integer(), nullable=True),
        sa.Column("episode_number", sa.Integer(), nullable=True),
        sa.Column("season_key", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("episode_key", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("asset_id", sa.Uuid(as_uuid=True), sa.ForeignKey("video_assets.id", ondelete="SET NULL"), nullable=True),
        sa.Column("title", sa.String(length=255), nullable=False),
        sa.Column("poster_path", sa.String(length=512), nullable=True),
        sa.Column("backdrop_path", sa.String(length=512), nullable=True),
        sa.Column("current_position_seconds", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("duration_seconds", sa.Integer(), nullable=False, server_default="1"),
        sa.Column("is_completed", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("last_watched_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint(
            "user_id",
            "tmdb_id",
            "content_type",
            "season_key",
            "episode_key",
            name="uq_watch_history_user_item",
        ),
    )
    op.create_index("ix_watch_history_user_id", "watch_history", ["user_id"], unique=False)
    op.create_index("ix_watch_history_tmdb_id", "watch_history", ["tmdb_id"], unique=False)
    op.create_index(
        "ix_watch_history_user_last_watched",
        "watch_history",
        ["user_id", "last_watched_at"],
        unique=False,
    )

    op.create_table(
        "provider_mappings",
        sa.Column("id", sa.Uuid(as_uuid=True), primary_key=True, nullable=False),
        sa.Column("tmdb_id", sa.Integer(), nullable=False),
        sa.Column("content_type", sa.String(length=16), nullable=False),
        sa.Column("region", sa.String(length=8), nullable=False, server_default="VN"),
        sa.Column("provider_type", sa.String(length=32), nullable=False),
        sa.Column("provider_name", sa.String(length=120), nullable=False),
        sa.Column("monetization_type", sa.String(length=32), nullable=False, server_default="flatrate"),
        sa.Column("logo_path", sa.String(length=512), nullable=True),
        sa.Column("external_watch_url", sa.String(length=1024), nullable=True),
        sa.Column("asset_id", sa.Uuid(as_uuid=True), sa.ForeignKey("video_assets.id", ondelete="SET NULL"), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint(
            "tmdb_id",
            "content_type",
            "region",
            "provider_name",
            name="uq_provider_mapping_title_region",
        ),
    )
    op.create_index("ix_provider_mappings_tmdb_id", "provider_mappings", ["tmdb_id"], unique=False)


def downgrade() -> None:
    op.drop_table("provider_mappings")
    op.drop_table("watch_history")
    op.drop_table("playback_sessions")
    op.drop_table("audio_tracks")
    op.drop_table("subtitle_tracks")
    op.drop_table("video_sources")
    op.drop_table("video_assets")
    op.drop_table("watchlist_items")
    op.drop_table("refresh_tokens")
    op.drop_table("users")
