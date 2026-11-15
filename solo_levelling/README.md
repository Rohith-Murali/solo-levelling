# Solo Levelling Flutter app

Flutter client for the Solo Levelling personal-growth RPG. The initial app shell uses the shared dark HUD theme in `lib/app/theme/` and keeps API communication in `lib/core/network/`.

## Setup

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:3000/api/
```

Override `API_BASE_URL` with the backend address reachable from the target device. For Android emulators, use `http://10.0.2.2:3000/api/`.

## Checks

```powershell
flutter analyze
flutter test
```
