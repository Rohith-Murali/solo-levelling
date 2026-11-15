import assert from "node:assert/strict";
import test from "node:test";
import request from "supertest";
import { createApp } from "../dist/app.js";

const app = createApp({
  NODE_ENV: "development",
  corsOrigins: [],
  JWT_SECRET: "a".repeat(32),
});

test("liveness endpoint reports a running API", async () => {
  const response = await request(app).get("/api/health/live");

  assert.equal(response.status, 200);
  assert.deepEqual(response.body, { data: { status: "ok" } });
});

test("readiness endpoint reports an unavailable database", async () => {
  const response = await request(app).get("/api/health/ready");

  assert.equal(response.status, 503);
  assert.deepEqual(response.body, {
    data: { status: "not_ready", database: "disconnected" },
  });
});

test("unknown routes return the standard not-found error", async () => {
  const response = await request(app).get("/api/missing");

  assert.equal(response.status, 404);
  assert.deepEqual(response.body, {
    error: { code: "NOT_FOUND", message: "Route not found." },
  });
});

test("malformed JSON returns a client error", async () => {
  const response = await request(app)
    .post("/api/unknown")
    .set("content-type", "application/json")
    .send("{");

  assert.equal(response.status, 400);
  assert.deepEqual(response.body, {
    error: { code: "INVALID_JSON", message: "Request body contains invalid JSON." },
  });
});

test("CORS preflight allows a localhost development server on a dynamic port", async () => {
  const response = await request(app)
    .options("/api/auth/register")
    .set("origin", "http://localhost:53568")
    .set("access-control-request-method", "POST")
    .set("access-control-request-headers", "content-type");

  assert.equal(response.status, 204);
  assert.equal(response.headers["access-control-allow-origin"], "http://localhost:53568");
});

test("CORS does not allow non-loopback origins or loopback origins in production", async () => {
  const productionApp = createApp({
    NODE_ENV: "production",
    corsOrigins: ["https://app.example"],
    JWT_SECRET: "a".repeat(32),
  });

  const remoteOrigin = await request(app)
    .options("/api/auth/register")
    .set("origin", "http://attacker.example")
    .set("access-control-request-method", "POST");
  const productionLoopbackOrigin = await request(productionApp)
    .options("/api/auth/register")
    .set("origin", "http://localhost:53568")
    .set("access-control-request-method", "POST");
  const configuredProductionOrigin = await request(productionApp)
    .options("/api/auth/register")
    .set("origin", "https://app.example")
    .set("access-control-request-method", "POST");

  assert.equal(remoteOrigin.headers["access-control-allow-origin"], undefined);
  assert.equal(productionLoopbackOrigin.headers["access-control-allow-origin"], undefined);
  assert.equal(configuredProductionOrigin.headers["access-control-allow-origin"], "https://app.example");
});
