# Solo Levelling Flutter app

Flutter client for the Solo Levelling personal-growth RPG. The initial app shell uses the shared dark HUD theme in `lib/app/theme/` and keeps API communication in `lib/core/network/`.

The app includes email/password sign-in and registration. Refresh tokens are stored with `flutter_secure_storage`; web builds require HTTPS or localhost. Android builds require API 23 or later.

## Setup

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:3000/api/
```

Override `API_BASE_URL` with the backend address reachable from the target device. For Android emulators, use `http://10.0.2.2:3000/api/`.

Release builds require an HTTPS `API_BASE_URL`; the HTTP examples above are for local development only.

## Checks

```powershell
flutter analyze
flutter test
```
