import assert from "node:assert/strict";
import test from "node:test";
import { loadConfig } from "../src/config.js";

test("loadConfig applies safe defaults around required database configuration", () => {
  assert.deepEqual(loadConfig({ DATABASE_URL: "postgresql://example" }), {
    databaseUrl: "postgresql://example",
    environment: "development",
    host: "0.0.0.0",
    logLevel: "info",
    port: 8080,
    shutdownTimeoutMs: 10_000,
    sessionTtlHours: 24,
  });
});

test("loadConfig rejects invalid boundary values", () => {
  assert.throws(() => loadConfig({}), /DATABASE_URL is required/);
  assert.throws(
    () => loadConfig({ DATABASE_URL: "postgresql://example", PORT: "0" }),
    /PORT must be between/,
  );
  assert.throws(
    () => loadConfig({ DATABASE_URL: "postgresql://example", LOG_LEVEL: "verbose" }),
    /LOG_LEVEL must be one of/,
  );
  assert.throws(
    () =>
      loadConfig({ DATABASE_URL: "postgresql://example", SHUTDOWN_TIMEOUT_MS: "fast" }),
    /SHUTDOWN_TIMEOUT_MS must be an integer/,
  );
});
