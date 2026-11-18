import json
import logging
import time
from typing import Any, Optional

import redis.asyncio as redis

from app.core.config import get_settings

logger = logging.getLogger(__name__)


class CacheBackend:
    """Async Redis metadata cache with graceful local fallback when Redis is unreachable.
    Never caches private tokens or signed playback URLs in public keys.
    """

    def __init__(self) -> None:
        self._settings = get_settings()
        self._redis: Optional[redis.Redis] = None
        self._local_store: dict[str, tuple[float, str]] = {}
        self._rate_buckets: dict[str, list[float]] = {}

    async def connect(self) -> None:
        if not self._settings.REDIS_ENABLED:
            return
        try:
            client = redis.from_url(
                self._settings.REDIS_URL,
                encoding="utf-8",
                decode_responses=True,
                socket_connect_timeout=1.5,
            )
            await client.ping()
            self._redis = client
            logger.info("Connected to Redis cache backend.")
        except Exception as exc:
            logger.warning(
                "Redis unavailable (%s); falling back to process-local TTL cache.",
                str(exc),
            )
            self._redis = None

    async def close(self) -> None:
        if self._redis is not None:
            await self._redis.aclose()
            self._redis = None

    async def is_healthy(self) -> dict[str, Any]:
        if self._redis is not None:
            try:
                pong = await self._redis.ping()
                return {"mode": "redis", "connected": bool(pong)}
            except Exception:
                return {"mode": "redis", "connected": False}
        return {"mode": "memory_fallback", "connected": True}

    async def get_json(self, key: str) -> Optional[Any]:
        if self._redis is not None:
            try:
                raw = await self._redis.get(key)
                return json.loads(raw) if raw else None
            except Exception as exc:
                logger.warning("Redis GET error for key %s: %s", key, str(exc))

        entry = self._local_store.get(key)
        if not entry:
            return None
        expires_at, payload = entry
        if time.monotonic() > expires_at:
            self._local_store.pop(key, None)
            return None
        return json.loads(payload)

    async def set_json(self, key: str, value: Any, ttl_seconds: Optional[int] = None) -> None:
        ttl = ttl_seconds or self._settings.METADATA_CACHE_TTL_SECONDS
        serialized = json.dumps(value, ensure_ascii=False)
        if self._redis is not None:
            try:
                await self._redis.set(key, serialized, ex=ttl)
                return
            except Exception as exc:
                logger.warning("Redis SET error for key %s: %s", key, str(exc))

        self._local_store[key] = (time.monotonic() + ttl, serialized)

    async def check_rate_limit(self, key: str, max_requests: int, window_seconds: int) -> bool:
        """Returns True if allowed, False if rate limit exceeded."""
        now = time.time()
        if self._redis is not None:
            try:
                redis_key = f"ratelimit:{key}"
                count = await self._redis.incr(redis_key)
                if count == 1:
                    await self._redis.expire(redis_key, window_seconds)
                return count <= max_requests
            except Exception as exc:
                logger.warning("Redis rate limit fallback for %s: %s", key, str(exc))

        bucket = self._rate_buckets.get(key, [])
        cutoff = now - window_seconds
        bucket = [ts for ts in bucket if ts > cutoff]
        if len(bucket) >= max_requests:
            self._rate_buckets[key] = bucket
            return False
        bucket.append(now)
        self._rate_buckets[key] = bucket
        return True


cache_backend = CacheBackend()
