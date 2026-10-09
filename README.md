# Project Bobst

Live busyness of each floor of NYU's Bobst Library.

```
backend/   FastAPI (Python). Turns Wi-Fi access-point counts into per-floor busyness.
app/       Flutter app. One codebase for iOS, Android, macOS and Windows.
```

The backend owns all the logic and serves JSON at `/api/floors`; the app just
displays it. Occupancy currently comes from `DummySource`
(`backend/app/sources/dummy.py`). The real NYU feed will be another
`OccupancySource` implementation, swapped in at `backend/app/services.py`.

## Backend

```sh
cd backend
python3 -m venv .venv
.venv/bin/pip install -r requirements-dev.txt
.venv/bin/uvicorn app.main:app --reload    # http://localhost:8000/api/floors
.venv/bin/python -m pytest
```

## App

Requires Flutter (`brew install --cask flutter`) and Xcode. Start the backend first.

```sh
cd app
flutter run                  # pick a device: iOS Simulator, macOS, ...
flutter test
```

The app calls `http://localhost:8000` by default. Override with
`--dart-define=API_BASE_URL=...` (Android emulator: `http://10.0.2.2:8000`).

Android needs Android Studio; Windows builds must be made on a Windows machine.

### iCloud Drive gotcha

If the repo lives in an iCloud-synced folder (e.g. `~/Documents`), iCloud tags
build output with Finder metadata and iOS/macOS code signing fails with
"resource fork, Finder information, or similar detritus not allowed". Fix:
point `app/build` outside iCloud:

```sh
cd app
rm -rf build
mkdir -p ~/Library/Caches/ProjectBobst/app-build
ln -s ~/Library/Caches/ProjectBobst/app-build build
```
