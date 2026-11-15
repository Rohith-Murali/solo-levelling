import assert from "node:assert/strict";
import test from "node:test";
import request from "supertest";
import { createApp } from "../dist/app.js";
import { verifyAccessToken, createAccessToken } from "../dist/services/token.service.js";
import { registerBodySchema } from "../dist/validators/auth.validators.js";

const jwtSecret = "a".repeat(32);
const app = createApp({ NODE_ENV: "development", corsOrigins: [], JWT_SECRET: jwtSecret });

test("registration validation normalizes email and limits password bytes", () => {
  const valid = registerBodySchema.safeParse({
    email: "  Hunter@Example.com ",
    password: "password123",
  });
  assert.equal(valid.success, true);
  if (valid.success) {
    assert.equal(valid.data.email, "hunter@example.com");
  }

  const oversizedPassword = registerBodySchema.safeParse({
    email: "hunter@example.com",
    password: "é".repeat(37),
  });
  assert.equal(oversizedPassword.success, false);
});

test("register rejects malformed account details before database access", async () => {
  const response = await request(app)
    .post("/api/auth/register")
    .send({ email: "not-an-email", password: "short" });

  assert.equal(response.status, 400);
  assert.deepEqual(response.body, {
    error: { code: "VALIDATION_ERROR", message: "Request body is invalid." },
    details: [
      { path: "email", message: "Invalid email address" },
      { path: "password", message: "Too small: expected string to have >=8 characters" },
    ],
  });
});

test("current-user endpoint rejects missing and invalid access tokens", async () => {
  const missingToken = await request(app).get("/api/auth/me");
  assert.equal(missingToken.status, 401);

  const invalidToken = await request(app)
    .get("/api/auth/me")
    .set("authorization", "Bearer invalid-token");
  assert.equal(invalidToken.status, 401);
});

test("access tokens are bound to their user and signed for the app", async () => {
  const token = await createAccessToken(
    { id: "507f1f77bcf86cd799439011", email: "hunter@example.com" },
    jwtSecret,
  );

  assert.deepEqual(await verifyAccessToken(token, jwtSecret), {
    userId: "507f1f77bcf86cd799439011",
    email: "hunter@example.com",
  });
  await assert.rejects(verifyAccessToken(token, "a-different-test-secret"));
});
