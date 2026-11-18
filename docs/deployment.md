# Nam Cinema — Production Deployment Guide

## 1. Infrastructure Stack (`infrastructure/docker-compose.yml`)

The production stack consists of four services orchestrated via Docker Compose:
- **`postgres`** (`postgres:16-alpine`): Primary relational store for users, refresh tokens, watchlists, watch history, playable assets, and playback sessions.
- **`redis`** (`redis:7-alpine`): Metadata caching for TMDB responses and authentication rate limiting.
- **`backend`** (`nam_cinema/backend/Dockerfile`): FastAPI application running Alembic migrations (`alembic upgrade head`) on startup before serving via Uvicorn.
- **`nginx`** (`nginx:1.27-alpine`): Reverse proxy with security headers (`X-Frame-Options`, `X-Content-Type-Options`, `Referrer-Policy`).

---

## 2. Production Security Checklist

1. Copy `.env.example` to `.env` on the server and set `APP_ENV="production"` and `DEBUG=false`.
2. Generate strong 64-byte secrets for `JWT_SECRET_KEY` and `PLAYBACK_SIGNING_SECRET`:
   ```bash
   python3 -c "import secrets; print(secrets.token_urlsafe(64))"
   ```
3. Set strong `POSTGRES_PASSWORD` and update `DATABASE_URL`.
4. Set `TMDB_API_KEY` or `TMDB_READ_ACCESS_TOKEN` on the backend server only (never in the mobile client).
5. Restrict `CORS_ORIGINS` to your authorized web/admin domains.
6. Terminate TLS/HTTPS (Let's Encrypt / Cloudflare / AWS ALB) in front of Nginx and set `PUBLIC_BASE_URL="https://api.namcinema.vn"`.

---

## 3. Deploy Command

```bash
cd nam_cinema
docker compose -f infrastructure/docker-compose.yml up -d --build
```

Verify health probes:
```bash
curl -f http://localhost:8080/health/live
curl -f http://localhost:8080/health/ready
```
