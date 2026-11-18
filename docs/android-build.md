# Nam Cinema — Android Build & Release Guide

## 1. Prerequisites

Ensure `flutter doctor -v` reports no issues with the **Flutter SDK** and **Android toolchain** (`Android Studio`, `Android SDK Command-line Tools`, and accepted licenses).

---

## 2. Configure Release Signing Keystore

Never commit `.jks` or `key.properties` files to Git (`.gitignore` already excludes them).

```powershell
cd "c:\Users\Admin\Documents\Vibe Coding\JSFilm4K\nam_cinema\apps\mobile\android"

# Generate an upload keystore
keytool -genkey -v -keystore upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Create `apps/mobile/android/key.properties`:
```properties
storePassword=<your-store-password>
keyPassword=<your-key-password>
keyAlias=upload
storeFile=upload-keystore.jks
```

---

## 3. Build Release APK (Phones & Tablets)

```powershell
cd "c:\Users\Admin\Documents\Vibe Coding\JSFilm4K\nam_cinema\apps\mobile"

# Build fat release APK pointing to your production HTTPS backend
flutter build apk --release --dart-define=API_BASE_URL=https://api.namcinema.vn

# Or build split-per-abi APKs (smaller downloads for arm64-v8a, armeabi-v7a, x86_64)
flutter build apk --split-per-abi --release --dart-define=API_BASE_URL=https://api.namcinema.vn
```

Output location:
`apps/mobile/build/app/outputs/flutter-apk/app-release.apk`

---

## 4. Build Android App Bundle (`.aab`) for Google Play Store

```powershell
cd "c:\Users\Admin\Documents\Vibe Coding\JSFilm4K\nam_cinema\apps\mobile"

flutter build appbundle --release --dart-define=API_BASE_URL=https://api.namcinema.vn
```

Output location:
`apps/mobile/build/app/outputs/bundle/release/app-release.aab`
