@echo off
chcp 65001 >nul
echo ========================================================
echo   DONG GOI FILE .APK NATIVE CHO ANDROID (FLUTTER)
echo ========================================================
cd /d "%~dp0..\..\apps\mobile"
where flutter >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [!] May tinh hien chua cai Flutter SDK trong PATH.
    echo [+] Ban co the cai dat truc tiep phien ban Android WebAPK qua dia chi:
    echo     http://192.168.2.173:8000/install
    pause
    exit /b 0
)
flutter pub get
flutter build apk --release --dart-define=API_BASE_URL=http://192.168.2.173:8000/api/v1
copy /Y "build\app\outputs\flutter-apk\app-release.apk" "%~dp0NamCinema-Android-Release.apk"
echo [OK] Da xuat file NamCinema-Android-Release.apk thanh cong!
pause
