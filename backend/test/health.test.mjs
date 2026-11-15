import assert from "node:assert/strict";
import test from "node:test";
import request from "supertest";
import { createApp } from "../dist/app.js";

const app = createApp();

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
