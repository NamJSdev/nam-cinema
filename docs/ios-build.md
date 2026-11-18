# Nam Cinema — iOS Build & TestFlight Guide

## Platform Requirement Notice (Windows 11)

Compiling, linking, and code-signing an iOS application (`.app` / `.ipa`) requires Apple's **Xcode** toolchain and **CocoaPods**, which only run on **macOS**. Standard Flutter tooling on Windows 11 **cannot** directly compile or sign an iOS IPA binary locally.

You have two supported production paths to build and distribute **Nam Cinema** for iPhone and iPad:

---

## Option A — Build on a Mac (macOS + Xcode)

1. **Install Prerequisites on macOS**:
   ```bash
   brew install --cask flutter
   sudo gem install cocoapods
   xcode-select --install
   sudo xcodebuild -license accept
   ```
2. **Fetch Dependencies & Pods**:
   ```bash
   cd nam_cinema/apps/mobile
   flutter pub get
   cd ios && pod install && cd ..
   ```
3. **Configure Signing in Xcode**:
   - Open `apps/mobile/ios/Runner.xcworkspace` in Xcode.
   - Select the **Runner** target -> **Signing & Capabilities**.
   - Check **Automatically manage signing**.
   - Select your **Apple Developer Team** (requires active Apple Developer Program membership for physical iPhone/iPad & TestFlight distribution).
   - Set Bundle Identifier to `vn.namcinema.app` (or your registered App ID).
4. **Run on iOS Simulator or Physical iPhone/iPad**:
   ```bash
   open -a Simulator
   flutter run --dart-define=API_BASE_URL=http://localhost:8000
   ```
5. **Build Signed IPA for TestFlight / App Store**:
   ```bash
   flutter build ipa --release --dart-define=API_BASE_URL=https://api.namcinema.vn
   ```
   Upload the generated `build/ios/ipa/*.ipa` via **Xcode Organizer** or Apple's **Transporter** app to App Store Connect / TestFlight.

---

## Option B — Cloud macOS CI (GitHub Actions from Windows)

A ready-to-use GitHub Actions workflow is included at `.github/workflows/ios-build.yml` that runs on `macos-14` runners whenever you push from Windows.

1. Push the repository to GitHub.
2. Under **Settings -> Secrets and variables -> Actions**, configure:
   - `PRODUCTION_API_URL` (Variable): e.g., `https://api.namcinema.vn`
   - `BUILD_CERTIFICATE_BASE64` (Secret): Base64-encoded Apple Distribution `.p12` certificate
   - `P12_PASSWORD` (Secret): Password for the `.p12` certificate
   - `BUILD_PROVISION_PROFILE_BASE64` (Secret): Base64-encoded `.mobileprovision` profile
   - `KEYCHAIN_PASSWORD` (Secret): Temporary CI keychain password
3. Trigger **Nam Cinema — iOS & Android CI** in the GitHub Actions tab.
   - Even before Apple signing secrets are added, the workflow runs `flutter analyze`, `flutter test`, and `flutter build ios --release --no-codesign` to verify iOS compilation on macOS.
   - Once signing secrets are configured, it runs `flutter build ipa --release` and uploads the signed `.ipa` artifact.
