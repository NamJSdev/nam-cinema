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
from app.schemas.vsmov import (
    VsmovDetailResponse,
    VsmovListResponse,
    VsmovTaxonomyListResponse,
    VsmovTaxonomyRef,
)

logger = logging.getLogger(__name__)


class VsmovProvider:
    """Dedicated async VSMOV catalog provider with HTTPX, Redis caching,
    exponential backoff retry, Pydantic validation, and URL normalization.
    """

    def __init__(
        self,
        http_client: Optional[httpx.AsyncClient] = None,
        use_cache: bool = True,
    ) -> None:
        self._settings = get_settings()
        self._external_client = http_client
        self._use_cache = use_cache

    @property
    def base_url(self) -> str:
        return self._settings.VSMOV_BASE_URL.rstrip("/")

    @staticmethod
    def normalize_image_url(url: Optional[str], path_image: Optional[str] = None) -> Optional[str]:
        if not url:
            return None
        cleaned = url.strip()
        if not cleaned:
            return None
        if cleaned.startswith("http://") or cleaned.startswith("https://"):
            if "nguon.vsphim.com" in cleaned:
                cleaned = cleaned.replace("https://nguon.vsphim.com", "https://vsmov.com").replace(
                    "http://nguon.vsphim.com", "https://vsmov.com"
                )
            return cleaned
        safe_prefix = "https://vsmov.com/storage/images"
        if path_image and "nguon.vsphim.com" not in path_image:
            safe_prefix = path_image.rstrip("/")
        return f"{safe_prefix}/{cleaned.lstrip('/')}"

    async def _request_json(
        self,
        endpoint: str,
        params: Optional[dict[str, Any]] = None,
        cache_ttl: Optional[int] = None,
    ) -> dict[str, Any]:
        query = {k: v for k, v in (params or {}).items() if v is not None and v != ""}
        key_digest = hashlib.sha256(
            f"{endpoint}:{json.dumps(query, sort_keys=True)}".encode("utf-8")
        ).hexdigest()[:24]
        cache_key = f"vsmov:{endpoint.strip('/')}:{key_digest}"

        if self._use_cache:
            cached = await cache_backend.get_json(cache_key)
            if cached is not None:
                return cached

        url = f"{self.base_url}/{endpoint.lstrip('/')}"
        headers = {
            "Accept": "application/json",
            "User-Agent": "NamCinema/1.0 (+https://namcinema.vn)",
        }
        timeout = self._settings.VSMOV_TIMEOUT_SECONDS
        ttl = cache_ttl or self._settings.VSMOV_CACHE_TTL_SECONDS
        max_attempts = 3

        for attempt in range(1, max_attempts + 1):
            try:
                if self._external_client is not None:
                    response = await self._external_client.get(
                        url,
                        headers=headers,
                        params=query,
                        timeout=timeout,
                    )
                else:
                    async with httpx.AsyncClient(
                        timeout=timeout,
                        follow_redirects=True,
                    ) as client:
                        response = await client.get(url, headers=headers, params=query)

                if response.status_code == status.HTTP_404_NOT_FOUND:
                    raise ResourceNotFoundError(f"VSMOV resource not found for {endpoint}.")

                if response.status_code in (429, 500, 502, 503, 504):
                    if attempt < max_attempts:
                        await asyncio.sleep(0.4 * (2 ** (attempt - 1)))
                        continue
                    raise ExternalServiceError(
                        service="VSMOV",
                        message=f"VSMOV upstream returned HTTP {response.status_code}.",
                        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                    )

                response.raise_for_status()
                payload = response.json()
                if not isinstance(payload, dict):
                    raise ExternalServiceError(
                        service="VSMOV",
                        message="Unexpected non-object JSON payload from VSMOV.",
                    )

                await cache_backend.set_json(cache_key, payload, ttl_seconds=ttl)
                return payload

            except (ResourceNotFoundError, ExternalServiceError):
                raise
            except (httpx.HTTPError, ValueError) as exc:
                if attempt == max_attempts:
                    logger.warning("VSMOV request failed for %s: %s", endpoint, str(exc))
                    raise ExternalServiceError(
                        service="VSMOV",
                        message="Unable to reach VSMOV catalog service.",
                        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                    ) from exc
                await asyncio.sleep(0.4 * (2 ** (attempt - 1)))

        raise ExternalServiceError(service="VSMOV", message="VSMOV request failed after retries.")

    # ==========================================================================
    # 10 Required VSMOV Endpoints
    # ==========================================================================

    async def get_newly_updated(self, page: int = 1) -> VsmovListResponse:
        """GET /danh-sach/phim-moi-cap-nhat?page={page}"""
        raw = await self._request_json("/danh-sach/phim-moi-cap-nhat", {"page": page})
        return VsmovListResponse.model_validate(raw)

    async def get_catalog_list(
        self,
        page: int = 1,
        limit: int = 24,
        movie_type: Optional[str] = None,
        category: Optional[str] = None,
        country: Optional[str] = None,
        year: Optional[int] = None,
    ) -> VsmovListResponse:
        """Covers:
        - GET /danh-sach?page=1&limit=24
        - GET /danh-sach?type=single
        - GET /danh-sach?type=series
        """
        params: dict[str, Any] = {"page": page, "limit": limit}
        if movie_type:
            params["type"] = movie_type
        if category:
            params["category"] = category
        if country:
            params["country"] = country
        if year:
            params["year"] = year
        raw = await self._request_json("/danh-sach", params)
        return VsmovListResponse.model_validate(raw)

    async def get_single_movies(self, page: int = 1, limit: int = 24) -> VsmovListResponse:
        """GET /danh-sach?type=single"""
        return await self.get_catalog_list(page=page, limit=limit, movie_type="single")

    async def get_series_movies(self, page: int = 1, limit: int = 24) -> VsmovListResponse:
        """GET /danh-sach?type=series"""
        return await self.get_catalog_list(page=page, limit=limit, movie_type="series")

    async def search_movies(
        self,
        keyword: str,
        page: int = 1,
        limit: int = 24,
    ) -> VsmovListResponse:
        """GET /tim-kiem?keyword={keyword}&page=1&limit=24"""
        raw = await self._request_json(
            "/tim-kiem",
            {"keyword": keyword.strip(), "page": page, "limit": limit},
        )
        return VsmovListResponse.model_validate(raw)

    async def get_movie_detail(self, slug: str) -> VsmovDetailResponse:
        """GET /phim/{slug}"""
        raw = await self._request_json(f"/phim/{slug.strip()}")
        parsed = VsmovDetailResponse.model_validate(raw)
        if not parsed.status or parsed.movie is None:
            raise ResourceNotFoundError(f"Movie slug '{slug}' was not found on VSMOV.")
        return parsed

    async def get_categories(self) -> list[VsmovTaxonomyRef]:
        """GET /the-loai"""
        raw = await self._request_json("/the-loai", cache_ttl=3600)
        parsed = VsmovTaxonomyListResponse.model_validate(raw)
        return parsed.data.items

    async def get_countries(self) -> list[VsmovTaxonomyRef]:
        """GET /quoc-gia"""
        raw = await self._request_json("/quoc-gia", cache_ttl=3600)
        parsed = VsmovTaxonomyListResponse.model_validate(raw)
        return parsed.data.items

    async def get_movies_by_category(
        self,
        slug: str,
        page: int = 1,
        limit: int = 24,
    ) -> VsmovListResponse:
        """GET /the-loai/{slug}"""
        raw = await self._request_json(
            f"/the-loai/{slug.strip()}",
            {"page": page, "limit": limit},
        )
        return VsmovListResponse.model_validate(raw)

    async def get_movies_by_country(
        self,
        slug: str,
        page: int = 1,
        limit: int = 24,
    ) -> VsmovListResponse:
        """GET /quoc-gia/{slug}"""
        raw = await self._request_json(
            f"/quoc-gia/{slug.strip()}",
            {"page": page, "limit": limit},
        )
        return VsmovListResponse.model_validate(raw)


vsmov_provider = VsmovProvider()
