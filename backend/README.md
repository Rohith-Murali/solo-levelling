# Solo Levelling API

Express 5 REST API using TypeScript and Mongoose. MongoDB-backed readiness is reported separately from API liveness. Authentication and product models are intentionally deferred.

## Setup

Requirements: Node.js 22+, npm, and MongoDB.

```powershell
Copy-Item .env.example .env
npm install
npm run dev
```

Set `MONGODB_URI` in `.env` to the database connection string. `CORS_ORIGINS` accepts a comma-separated allowlist; it defaults to no cross-origin browser access. Do not commit `.env`.

## Commands

- `npm run dev` — run the API with watch mode.
- `npm run build` — compile TypeScript into `dist/`.
- `npm start` — run the compiled API.
- `npm test` — compile and run the HTTP tests.
- `npm run typecheck` — type-check without emitting files.

## Health endpoints

- `GET /api/health/live` — confirms the API process is serving requests.
- `GET /api/health/ready` — returns `503` until MongoDB is connected.
