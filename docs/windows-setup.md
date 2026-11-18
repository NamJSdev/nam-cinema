# Nam Cinema — Windows 11 Development Setup Guide

This guide provides exact **PowerShell** commands for setting up, running, and testing the **Nam Cinema** monorepo on **Windows 11**.

---

## 1. Install Flutter SDK on Windows 11

```powershell
# Install Flutter stable via Winget (or download from https://docs.flutter.dev/get-started/install/windows)
winget install --id Google.Flutter -e

# Or clone Flutter stable directly to C:\src\flutter
git clone https://github.com/flutter/flutter.git -b stable C:\src\flutter
[Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\src\flutter\bin", "User")
```

Restart PowerShell and verify:
```powershell
flutter --version
dart --version
```

---

## 2. Install Android Studio & Android SDK Components

```powershell
winget install --id Google.AndroidStudio -e
```

1. Open **Android Studio** -> **More Actions** -> **SDK Manager**.
2. Under **SDK Platforms**, select **Android 14.0 (API 34)** or **Android 15.0 (API 35)**.
3. Under **SDK Tools**, check:
   - **Android SDK Build-Tools**
   - **Android SDK Command-line Tools (latest)**
   - **Android Emulator**
   - **Android SDK Platform-Tools**
4. Click **Apply** to install.

Accept Android SDK licenses and verify with `flutter doctor`:
```powershell
flutter doctor --android-licenses
flutter doctor -v
```

---

## 3. Install Python 3.12 & Docker Desktop

```powershell
winget install --id Python.Python.3.12 -e
winget install --id Docker.DockerDesktop -e
```

---

## 4. Start PostgreSQL & Redis via Docker Compose

From the repository root (`nam_cinema`):

```powershell
cd "c:\Users\Admin\Documents\Vibe Coding\JSFilm4K\nam_cinema"
Copy-Item .env.example .env

# Start PostgreSQL 16 and Redis 7 containers in the background
docker compose -f infrastructure/docker-compose.yml up -d postgres redis
docker compose -f infrastructure/docker-compose.yml ps
```

> **Note (No-Docker Local Fallback):** If Docker Desktop is not running on your Windows machine, you can set `DATABASE_URL="sqlite+aiosqlite:///./nam_cinema_dev.db"` and `REDIS_ENABLED=false` in `backend/.env`. The backend automatically falls back to async SQLite and in-memory TTL caching.

---

## 5. Configure Backend Virtual Environment, Migrations & FastAPI Server

```powershell
cd "c:\Users\Admin\Documents\Vibe Coding\JSFilm4K\nam_cinema\backend"
Copy-Item ..\.env.example .env

# Edit .env and add your TMDB_API_KEY from https://www.themoviedb.org/settings/api
# Create virtual environment and install dependencies
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install -e ".[dev]"

# Run Alembic database migrations
python -m alembic upgrade head

# Run automated backend test suite
python -m pytest -v

# Start FastAPI server on 0.0.0.0:8000
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Verify the backend in a second PowerShell window:
```powershell
Invoke-RestMethod http://localhost:8000/health/ready
```

---

## 6. Create a Local Development User Account

With the FastAPI server running, run this PowerShell command to register a local test account:

```powershell
$body = @{
    email = "dev@namcinema.vn"
    full_name = "Nam Cinema Developer"
    password = "DevPassword!2026"
    preferred_language = "vi-VN"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:8000/api/v1/auth/register" -Method Post -ContentType "application/json" -Body $body
```

---

## 7. Install Flutter Dependencies & Run Mobile App

```powershell
cd "c:\Users\Admin\Documents\Vibe Coding\JSFilm4K\nam_cinema\apps\mobile"

# Fetch packages
flutter pub get

# (Optional) Run code generation if modifying Freezed/Drift annotations
dart run build_runner build --delete-conflicting-outputs

# Run Flutter unit & widget tests
flutter test
```

### Networking for Android Emulator vs. Physical Android Phone

- **Android Emulator (`10.0.2.2`)**: Inside an Android emulator, `localhost` points to the emulated phone itself. Nam Cinema automatically defaults to `http://10.0.2.2:8000` on Android, which routes directly to `127.0.0.1:8000` on your Windows 11 host.
  ```powershell
  # List and launch an Android emulator
  flutter emulators
  flutter emulators --launch <emulator_id>

  # Run Nam Cinema on the emulator
  flutter run
  ```

- **Physical Android Phone (LAN IP)**: Ensure your Windows PC and Android phone are on the same Wi-Fi network, allow port `8000` through Windows Defender Firewall, and pass your PC's LAN IP via `--dart-define`:
  ```powershell
  # Find your Windows LAN IPv4 address (e.g., 192.168.1.50)
  ipconfig

  # Open port 8000 on Private Wi-Fi profile (Run PowerShell as Administrator)
  New-NetFirewallRule -DisplayName "Nam Cinema FastAPI 8000" -Direction Inbound -LocalPort 8000 -Protocol TCP -Action Allow

  # Run on connected physical Android device
  flutter run --dart-define=API_BASE_URL=http://192.168.1.50:8000
  ```
