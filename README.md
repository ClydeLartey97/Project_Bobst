# Project Bobst

Live busyness of each floor of NYU's Bobst Library.

```
backend/   FastAPI (Python). Turns Wi-Fi access-point counts into per-floor busyness.
app/       Flutter app. One codebase for iOS, Android, macOS and Windows.
```

The backend owns all the logic and serves JSON at `/api/status`; the app just
displays it. Occupancy currently comes from `DummySource`
(`backend/app/sources/dummy.py`). The real NYU feed will be another
`OccupancySource` implementation, swapped in at `backend/app/services.py`.

Floors and their areas (e.g. "5th Floor East") live in `backend/app/floors.py`.
Busyness uses one six-step scale everywhere (Empty → Quite empty → Not too
busy → Busy → Very busy → Full); thresholds are `BUSYNESS_SCALE` in
`services.py`.

### Study rooms

`backend/app/rooms/` ingests live room availability from NYU's LibCal booking
site (nyu.libcal.com), using the same public endpoints its booking page calls:
room lists every 6 hours, availability every 5 minutes, with 10 seconds between
requests (LibCal's robots.txt crawl delay). Served at `/api/rooms`; the app
links each room to its LibCal page for booking (needs an NYU login). Turn off
with `ROOMS_INGEST=false`.

### Developer overrides

`/api/dev/settings` lets the app's Developer tab override time of day, day,
finals week, crowd size and per-floor fullness. Global to the server; disable
with `DEV_MODE=false`.

## Backend

```sh
cd backend
python3 -m venv .venv
.venv/bin/pip install -r requirements-dev.txt
.venv/bin/uvicorn app.main:app --reload    # http://localhost:8000/api/status
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
