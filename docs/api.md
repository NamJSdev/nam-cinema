# Nam Cinema — REST API Reference (`/api/v1`)

Base URL (Local Host): `http://localhost:8000`
Base URL (Android Emulator): `http://10.0.2.2:8000`
Interactive OpenAPI Docs: `http://localhost:8000/docs`

---

## 1. Standard Error Format

All validation, authentication, rate-limit, and upstream errors return a consistent JSON envelope:

```json
{
  "error": {
    "code": "AUTHENTICATION_ERROR",
    "message": "Invalid email or password.",
    "details": {}
  }
}
```

---

## 2. Authentication Endpoints

| Method | Path | Auth | Description |
| :--- | :--- | :--- | :--- |
| `POST` | `/api/v1/auth/register` | Public | Register a new user account (Argon2id hashed password) and issue JWT access + refresh tokens. |
| `POST` | `/api/v1/auth/login` | Public | Authenticate by email & password (rate-limited per IP + email). |
| `POST` | `/api/v1/auth/refresh` | Public | Rotate refresh token and issue a new access + refresh token pair. |
| `POST` | `/api/v1/auth/logout` | Bearer | Revoke current or all active refresh tokens for the user. |
| `GET` | `/api/v1/auth/me` | Bearer | Return the currently authenticated user's profile. |

---

## 3. Catalog & Metadata Endpoints (VSMOV Primary + TMDB Enrichment)

| Method | Path | Auth | Description |
| :--- | :--- | :--- | :--- |
| `GET` | `/api/v1/home` | Optional | Aggregated 12-section home feed powered by VSMOV (`/danh-sach/phim-moi-cap-nhat`, `/danh-sach?type=single`, `/danh-sach?type=series`, `/quoc-gia/han-quoc`, `/quoc-gia/trung-quoc`, `/quoc-gia/au-my`, `/the-loai/hoat-hinh`) + Continue Watching & Verified Playable HLS Assets. |
| `GET` | `/api/v1/catalog` | Public | Paginated VSMOV catalog listing supporting `page`, `limit`, `type` (`newly_updated`, `single`, `series`), `category` (genre slug), `country` (country slug), and `year`. |
| `GET` | `/api/v1/movies/trending` | Public | Paginated newly updated movies from VSMOV (`/danh-sach/phim-moi-cap-nhat?page=1`). |
| `GET` | `/api/v1/movies/popular` | Public | Paginated single movies from VSMOV (`/danh-sach?type=single`). |
| `GET` | `/api/v1/movies/top-rated` | Public | Paginated top-rated movies. |
| `GET` | `/api/v1/movies/{identifier}` | Public | Full movie details by VSMOV `slug` (`/phim/{slug}`) or `tmdb_id`, enriched with TMDB cast/trailers/watch-providers when configured. |
| `GET` | `/api/v1/tv/popular` | Public | Paginated TV series from VSMOV (`/danh-sach?type=series`). |
| `GET` | `/api/v1/tv/{identifier}` | Public | Full TV series metadata by VSMOV `slug` (`/phim/{slug}`) or `tmdb_id`, including season list and server metadata. |
| `GET` | `/api/v1/tv/{identifier}/seasons/{season_number}` | Public | Episode list for a season with per-episode `is_playable`, `playable_asset_id`, and VSMOV `server_name`. |
| `GET` | `/api/v1/search` | Public | Search or filter VSMOV (`/tim-kiem?keyword={keyword}&page=1&limit=24`) by `q`, `type`, `genre_slug`, `country_slug`, `year`, and `page`. |
| `GET` | `/api/v1/genres` | Public | VSMOV categories (`/the-loai`) with `id`, `name`, and `slug`. |
| `GET` | `/api/v1/genres/{slug}` | Public | Paginated movies by VSMOV category slug (`/the-loai/{slug}`). |
| `GET` | `/api/v1/countries` | Public | VSMOV countries (`/quoc-gia`) with `id`, `name`, and `slug`. |
| `GET` | `/api/v1/countries/{slug}` | Public | Paginated movies by VSMOV country slug (`/quoc-gia/{slug}`). |

---

## 4. Playback Session Endpoints

| Method | Path | Auth | Description |
| :--- | :--- | :--- | :--- |
| `GET` | `/api/v1/titles/{id}/availability` | Public | Check whether a title (`movie:10378`, `tv:60625:1:1`, or `10378`) has internal playable HLS assets or external watch providers in `region`. |
| `POST` | `/api/v1/playback/sessions` | Bearer | Authorize a playback session for `asset_id`, returning signed HLS `.m3u8` URLs, Vietnamese & English WebVTT subtitle tracks, audio tracks, license attribution, and `resume_position_seconds`. |
| `POST` | `/api/v1/playback/sessions/{id}/heartbeat` | Bearer | Persist playback progress (`position_seconds`, `duration_seconds`) and extend session TTL. |
| `DELETE` | `/api/v1/playback/sessions/{id}` | Bearer | Safely close an active playback session. |

---

## 5. User Library (Watchlist & Watch History)

| Method | Path | Auth | Description |
| :--- | :--- | :--- | :--- |
| `GET` | `/api/v1/me/watchlist` | Bearer | List all saved movies and TV series for the user. |
| `POST` | `/api/v1/me/watchlist` | Bearer | Add or update a movie/TV series in the user's watchlist (idempotent on `user_id + tmdb_id + content_type`). |
| `DELETE` | `/api/v1/me/watchlist/{id}` | Bearer | Remove a watchlist item by UUID or `tmdb_id`. |
| `GET` | `/api/v1/me/history` | Bearer | List watch history ordered by `last_watched_at DESC`. |
| `PUT` | `/api/v1/me/progress` | Bearer | Upsert playback progress and completion status (`>= 92%` marks completed). |
| `DELETE` | `/api/v1/me/history/{id}` | Bearer | Remove an entry from watch history. |

---

## 6. Health Checks

| Method | Path | Description |
| :--- | :--- | :--- |
| `GET` | `/health/live` | Liveness probe (`{"status": "alive"}`). |
| `GET` | `/health/ready` | Readiness probe checking database connectivity, Redis/memory cache status, and TMDB credential status. |
