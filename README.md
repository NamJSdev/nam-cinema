# NAM CINEMA
> **Your Cinema. Anywhere.** — Production-Ready Cross-Platform Movie Streaming Application (Flutter + FastAPI)

---

## 1. Overview

**Nam Cinema** is a full-stack cross-platform movie and TV streaming platform built with a shared **Flutter (Material 3, Riverpod, GoRouter, Dio, VideoPlayer)** mobile codebase for Android and iOS, powered by an asynchronous **Python FastAPI + SQLAlchemy 2.x + Alembic + PostgreSQL + Redis** backend.

### Key Capabilities
- **12-Section Cinematic Home Screen**: Featured Hero Carousel, Trending Today, Popular Movies, Popular TV Series, Top-Rated Movies, Korean Movies, Chinese Movies, Hollywood Movies, Animation, Continue Watching, Recommended Titles, and Recently Added Playable Content.
- **Legal Video Source Architecture (`StreamingProvider` Protocol)**:
  - **Provider A (`LicensedHlsProvider`)**: Adaptive HLS `.m3u8` with expiring HMAC-SHA256 signed URLs (`nc_sid`, `nc_exp`, `nc_sig`), Vietnamese & English WebVTT subtitles, and audio track metadata.
  - **Provider B (`SelfHostedLibraryProvider`)**: Self-hosted / developer-owned licensed HLS assets with zero arbitrary URL proxying.
  - **Provider C (`PublicDemoContentProvider`)**: Pre-seeded with verified Creative Commons Attribution 3.0 (`CC-BY 3.0`) open movies (*Big Buck Bunny*, *Tears of Steel*) and Apple Developer HLS sample streams so first-run playback works out of the box.
  - **Provider D (`ExternalWatchProvider`)**: Regional TMDB watch-provider badges and legal external viewing links. Never misrepresents external subscriptions as internal streams.
- **Cross-Platform HLS Video Player**: Play/pause, +/-10s seek, scrubbing bar, buffering state, landscape fullscreen with wakelock, playback speed (`0.75x`–`2.0x`), Vietnamese Unicode WebVTT subtitle rendering with adjustable font size, periodic heartbeat progress saving, and automatic resume from last watched position.
- **Real Authentication & Security**: Argon2id password hashing, JWT access + rotating refresh tokens, token revocation on logout, IP/email login rate limiting, and encrypted mobile token storage (`flutter_secure_storage`).
- **Persistent Watchlist & Watch History**: Synchronized across devices via PostgreSQL with offline local caching on mobile.

---

## 2. Monorepo Structure

```text
nam_cinema/
├── apps/
│   └── mobile/                  # Flutter Cross-Platform App (Android & iOS)
│       ├── android/             # Android Manifest & Kotlin MainActivity (PiP enabled)
│       ├── ios/                 # iOS Runner & Info.plist
│       ├── lib/
│       │   ├── main.dart
│       │   ├── app/             # App widget, GoRouter configuration, bootstrap
│       │   ├── core/            # EnvConfig, Theme, Dio ApiClient, SecureStorage, WebVTT parser, Widgets
│       │   └── features/        # Clean Architecture features (auth, home, search, movie_details, tv_series, player, watchlist, history, profile, settings)
│       ├── test/                # Unit & Widget tests
│       └── integration_test/    # End-to-end integration test
├── backend/                     # Python 3.12 FastAPI Backend
│   ├── app/
│   │   ├── main.py              # FastAPI app factory, CORS, static WebVTT server, health probes
│   │   ├── api/v1/              # Versioned REST routers (auth, catalog, playback, library)
│   │   ├── core/                # Pydantic Settings, Redis/Memory cache, structured JSON logging, exceptions
│   │   ├── db/                  # Async SQLAlchemy 2.x engine & session management
│   │   ├── models/              # 10 normalized database entities
│   │   ├── providers/           # StreamingProvider protocol, Providers A/B/C/D, legal CC-BY 3.0 seed
│   │   ├── repositories/        # Watchlist & WatchHistory persistence repositories
│   │   ├── schemas/             # Pydantic v2 request/response schemas
│   │   ├── security/            # Argon2id hashing, JWT rotation, HMAC-SHA256 manifest signing
│   │   └── services/            # Async TmdbClient & CatalogService
│   ├── alembic/                 # Alembic migration environment & initial schema revision
│   └── tests/                   # Automated Pytest integration & contract suite
├── infrastructure/
│   ├── docker-compose.yml       # PostgreSQL 16, Redis 7, FastAPI Backend, Nginx
│   └── nginx/nginx.conf
└── docs/
    ├── architecture.md
    ├── api.md
    ├── windows-setup.md
    ├── android-build.md
    ├── ios-build.md
    └── deployment.md
```

---

## 3. Quick Start

See detailed step-by-step instructions in:
- [Windows 11 Development Setup](docs/windows-setup.md)
- [REST API Reference](docs/api.md)
- [Software & Streaming Architecture](docs/architecture.md)
- [Android APK & App Bundle Build Guide](docs/android-build.md)
- [iOS Build & Cloud macOS CI Guide](docs/ios-build.md)
- [Production Deployment Guide](docs/deployment.md)

---

## 4. Attribution & Licensing Notice

- **Metadata**: This product uses the TMDB API but is not endorsed or certified by TMDB.
- **Included Sample Streams**:
  - *Big Buck Bunny* — © 2008, Blender Foundation (`CC-BY 3.0`, `https://creativecommons.org/licenses/by/3.0/`).
  - *Tears of Steel* — © 2012, Blender Foundation (`CC-BY 3.0`, `https://creativecommons.org/licenses/by/3.0/`).
  - *Apple Developer HLS BipBop Sample* — Apple Inc. HLS Authoring Specification Sample Stream.
