# Solo Levelling API

Express 5 REST API using TypeScript and Mongoose. MongoDB-backed readiness is reported separately from API liveness.

## Setup

Requirements: Node.js 22+, npm, and MongoDB.

```powershell
Copy-Item .env.example .env
npm install
npm run dev
```

Set `MONGODB_URI` and a unique `JWT_SECRET` of at least 32 bytes in `.env`. `CORS_ORIGINS` accepts a comma-separated allowlist; in development, HTTP origins on `localhost`, `127.0.0.1`, and `[::1]` are also allowed so local web clients can use dynamic ports. Do not commit `.env`.

For production, set `NODE_ENV=production`, provide at least one HTTPS `CORS_ORIGINS` entry, and run the Flutter client with an HTTPS `API_BASE_URL`. The default rate limiter uses process memory and is suitable for a single instance; use a shared rate-limit store before running multiple API instances behind a load balancer.

Generate a local signing key with `node -e "console.log(require('node:crypto').randomBytes(48).toString('base64url'))"` and place the output in `.env`.

## Authentication

- `POST /api/auth/register` — create an account with an email and password.
- `POST /api/auth/login` — authenticate and issue an access token and refresh token.
- `POST /api/auth/refresh` — rotate a refresh token and issue a new access token.
- `POST /api/auth/logout` — revoke a refresh token.
- `GET /api/auth/me` — return the signed-in user; requires a Bearer access token.
- `GET /api/characters/options` — return the authenticated character-creation catalog and server-assigned initial progression.
- `POST /api/characters` — create the signed-in user's one character and its starting skill.
- `GET /api/dashboard` — return the authenticated player's character, skill, statistics, and available progression data.

The character and starting skill are stored together on the user record so creation is atomic. The client submits only the name, avatar ID, and starting skill ID; the API assigns initial progression and returns `hasCharacter` in authenticated user responses.
Character titles are resolved by the backend progression engine from the configurable level thresholds in `src/core/progression/config.ts`; the dashboard returns the current title alongside the character's rank and level.
Quest, goal, reward-history, and activity models are not implemented yet, so the dashboard returns empty lists and an unavailable progression-history state for those sections.

Passwords are hashed with bcrypt. Access tokens expire after 15 minutes; refresh tokens rotate and expire after 30 days. Refresh tokens are stored hashed in MongoDB. Email verification and password reset are not configured.

## Commands

- `npm run dev` — run the API with watch mode.
- `npm run build` — compile TypeScript into `dist/`.
- `npm start` — run the compiled API.
- `npm test` — compile and run the HTTP tests.
- `npm run typecheck` — type-check without emitting files.

## Health endpoints

- `GET /api/health/live` — confirms the API process is serving requests.
- `GET /api/health/ready` — returns `503` until MongoDB is connected.
