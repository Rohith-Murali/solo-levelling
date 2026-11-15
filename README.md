# Solo Levelling

A personal-growth RPG with a Flutter client and a Node.js/TypeScript REST API backed by MongoDB.

## Project layout

- `solo_levelling/` — Flutter application and reusable dark HUD theme.
- `backend/` — Express API, MongoDB connection, health checks, and backend tests.

The initial foundation does not include user accounts or RPG features. Authentication and domain models are deferred until their product requirements are defined.

## Prerequisites

- Flutter and Dart SDKs compatible with `solo_levelling/pubspec.yaml`.
- Node.js 22 or later and npm.
- MongoDB, local or hosted.

## Run locally

1. Configure the backend:

   ```powershell
   Copy-Item backend\.env.example backend\.env
   ```

   Update `MONGODB_URI` in `backend\.env` for your MongoDB instance.

2. Start the API:

   ```powershell
   cd backend
   npm install
   npm run dev
   ```

3. Start the Flutter app in another terminal:

   ```powershell
   cd solo_levelling
   flutter pub get
   flutter run --dart-define=API_BASE_URL=http://localhost:3000/api/
   ```

   Android emulators generally need the host address `http://10.0.2.2:3000/api/` instead of `localhost`.

## Verify

- Backend: `cd backend; npm test`
- Flutter: `cd solo_levelling; flutter analyze; flutter test`

The API exposes `/api/health/live` for liveness and `/api/health/ready` for MongoDB readiness.
