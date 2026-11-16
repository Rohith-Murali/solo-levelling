# Solo Levelling

A personal-growth RPG with a Flutter client and a Node.js/TypeScript REST API backed by MongoDB.

## Project layout

- `solo_levelling/` — Flutter application and reusable dark HUD theme.
- `backend/` — Express API, MongoDB connection, health checks, and backend tests.

The app includes email/password authentication, first-login character creation, and a player dashboard for accounts that have a character.

## Prerequisites

- Flutter and Dart SDKs compatible with `solo_levelling/pubspec.yaml`.
- Node.js 22 or later and npm.
- MongoDB, local or hosted.

## Run locally

1. Configure the backend:

   ```powershell
   Copy-Item backend\.env.example backend\.env
   ```

   Set `MONGODB_URI` and a unique `JWT_SECRET` of at least 32 bytes in `backend\.env`. Generate a local key with:

   ```powershell
   node -e "console.log(require('node:crypto').randomBytes(48).toString('base64url'))"
   ```

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

Authenticated character endpoints expose the available avatar and starting-skill catalog at `GET /api/characters/options` and create the account's one character at `POST /api/characters`. The API assigns all initial progression values. After creation, the app opens the player dashboard.

The authenticated `GET /api/dashboard` endpoint supplies persisted character and starting-skill progression. Quest, goal, reward-history, and activity tracking are not implemented yet, so those dashboard sections show empty states rather than sample data.
