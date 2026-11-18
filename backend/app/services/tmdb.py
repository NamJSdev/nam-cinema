import asyncio
import hashlib
import json
import logging
from typing import Any, Optional

import httpx
from fastapi import status

from app.core.cache import cache_backend
from app.core.config import get_settings
from app.core.exceptions import ExternalServiceError, ResourceNotFoundError

logger = logging.getLogger(__name__)


class TmdbClient:
    """Async TMDB v3 API client with Redis/memory caching, timeouts, and exponential backoff."""

    def __init__(self, http_client: Optional[httpx.AsyncClient] = None) -> None:
        self._settings = get_settings()
        self._external_client = http_client

    @property
    def is_configured(self) -> bool:
        return self._settings.has_tmdb_credentials

    def poster_url(self, path: Optional[str], size: str = "w500") -> Optional[str]:
        if not path:
            return None
        if path.startswith("http://") or path.startswith("https://"):
            return path
        return f"{self._settings.TMDB_IMAGE_BASE_URL.rstrip('/')}/{size}/{path.lstrip('/')}"

    def backdrop_url(self, path: Optional[str], size: str = "w1280") -> Optional[str]:
        return self.poster_url(path, size=size)

    def _build_headers_and_params(self, params: Optional[dict[str, Any]] = None) -> tuple[dict[str, str], dict[str, Any]]:
        headers = {"Accept": "application/json"}
        query = dict(params or {})
        if "language" not in query:
            query["language"] = self._settings.DEFAULT_LANGUAGE

        if self._settings.TMDB_READ_ACCESS_TOKEN.strip():
            headers["Authorization"] = f"Bearer {self._settings.TMDB_READ_ACCESS_TOKEN.strip()}"
        elif self._settings.TMDB_API_KEY.strip():
            query["api_key"] = self._settings.TMDB_API_KEY.strip()
        else:
            raise ExternalServiceError(
                service="TMDB",
                message=(
                    "TMDB API credentials are not configured on the backend. "
                    "Set TMDB_API_KEY or TMDB_READ_ACCESS_TOKEN in your .env file."
                ),
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            )
        return headers, query

    async def get(
        self,
        endpoint: str,
        params: Optional[dict[str, Any]] = None,
        cache_ttl: Optional[int] = None,
    ) -> dict[str, Any]:
        headers, query = self._build_headers_and_params(params)

        # Build deterministic cache key without leaking the API key
        safe_params = {k: v for k, v in sorted(query.items()) if k != "api_key"}
        key_digest = hashlib.sha256(
            f"{endpoint}:{json.dumps(safe_params, sort_keys=True)}".encode("utf-8")
        ).hexdigest()[:24]
        cache_key = f"tmdb:{endpoint.strip('/')}:{key_digest}"

        cached = await cache_backend.get_json(cache_key)
        if cached is not None:
            return cached

        url = f"{self._settings.TMDB_BASE_URL.rstrip('/')}/{endpoint.lstrip('/')}"
        max_attempts = 3

        for attempt in range(1, max_attempts + 1):
            try:
                if self._external_client is not None:
                    response = await self._external_client.get(url, headers=headers, params=query, timeout=10.0)
                else:
                    async with httpx.AsyncClient(timeout=10.0) as client:
                        response = await client.get(url, headers=headers, params=query)

                if response.status_code == status.HTTP_404_NOT_FOUND:
                    raise ResourceNotFoundError(f"TMDB resource not found for {endpoint}.")

                if response.status_code == status.HTTP_429_TOO_MANY_REQUESTS:
                    if attempt < max_attempts:
                        await asyncio.sleep(0.5 * (2 ** (attempt - 1)))
                        continue
                    raise ExternalServiceError(
                        service="TMDB",
                        message="TMDB rate limit reached. Please retry shortly.",
                        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                    )

                if response.status_code in (401, 403):
                    raise ExternalServiceError(
                        service="TMDB",
                        message="TMDB rejected the configured API credentials.",
                        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                    )

                if response.status_code >= 500 and attempt < max_attempts:
                    await asyncio.sleep(0.4 * (2 ** (attempt - 1)))
                    continue

                response.raise_for_status()
                payload = response.json()
                await cache_backend.set_json(cache_key, payload, ttl_seconds=cache_ttl)
                return payload

            except (ResourceNotFoundError, ExternalServiceError):
                raise
            except httpx.HTTPError as exc:
                if attempt == max_attempts:
                    logger.error("TMDB upstream HTTP failure on %s: %s", endpoint, str(exc))
                    raise ExternalServiceError(
                        service="TMDB",
                        message="Unable to reach TMDB metadata service.",
                        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                    ) from exc
                await asyncio.sleep(0.4 * (2 ** (attempt - 1)))

        raise ExternalServiceError(service="TMDB", message="TMDB request failed after retries.")


tmdb_client = TmdbClient()
