import assert from "node:assert/strict";
import test from "node:test";
import { loadConfig } from "../src/config.js";

test("loadConfig applies safe defaults", () => {
  assert.deepEqual(loadConfig({}), {
    environment: "development",
    host: "0.0.0.0",
    logLevel: "info",
    port: 8080,
    shutdownTimeoutMs: 10_000,
  });
});

test("loadConfig rejects invalid boundary values", () => {
  assert.throws(() => loadConfig({ PORT: "0" }), /PORT must be between/);
  assert.throws(() => loadConfig({ LOG_LEVEL: "verbose" }), /LOG_LEVEL must be one of/);
  assert.throws(
    () => loadConfig({ SHUTDOWN_TIMEOUT_MS: "fast" }),
    /SHUTDOWN_TIMEOUT_MS must be an integer/,
  );
});
