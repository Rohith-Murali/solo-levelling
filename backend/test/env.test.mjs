import assert from "node:assert/strict";
import test from "node:test";
import { loadConfig } from "../dist/config/env.js";

test("loads validated settings and splits the CORS allowlist", () => {
  const config = loadConfig({
    MONGODB_URI: "mongodb://127.0.0.1:27017/solo_levelling",
    PORT: "3100",
    CORS_ORIGINS: "https://app.example, https://admin.example",
  });

  assert.equal(config.PORT, 3100);
  assert.deepEqual(config.corsOrigins, ["https://app.example", "https://admin.example"]);
});

test("rejects invalid environment configuration without exposing values", () => {
  assert.throws(
    () => loadConfig({ PORT: "not-a-port" }),
    (error) => {
      assert.match(error.message, /Invalid environment configuration: .*PORT.*MONGODB_URI/);
      assert.doesNotMatch(error.message, /not-a-port/);
      return true;
    },
  );
});
