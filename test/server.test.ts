import assert from "node:assert/strict";
import type { AddressInfo } from "node:net";
import test from "node:test";
import type { AppConfig } from "../src/config.js";
import type { Logger } from "../src/logger.js";
import { createApp } from "../src/server.js";

const config: AppConfig = {
  environment: "test",
  host: "127.0.0.1",
  logLevel: "error",
  port: 8080,
  shutdownTimeoutMs: 1_000,
};

const silentLogger: Logger = {
  debug: () => undefined,
  error: () => undefined,
  info: () => undefined,
  warn: () => undefined,
};

test("HTTP API exposes health, readiness, and greeting behavior", async (t) => {
  const app = createApp(config, silentLogger);
  app.server.listen(0, "127.0.0.1");
  await new Promise<void>((resolve) => app.server.once("listening", resolve));

  t.after(
    () =>
      new Promise<void>((resolve, reject) => {
        app.server.close((error) => (error ? reject(error) : resolve()));
      }),
  );

  const address = app.server.address() as AddressInfo;
  const baseUrl = `http://127.0.0.1:${address.port}`;

  const health = await fetch(`${baseUrl}/health`);
  assert.equal(health.status, 200);
  assert.deepEqual(await health.json(), { status: "ok" });

  const unavailable = await fetch(`${baseUrl}/ready`);
  assert.equal(unavailable.status, 503);

  app.setReady(true);
  const ready = await fetch(`${baseUrl}/ready`);
  assert.equal(ready.status, 200);
  assert.deepEqual(await ready.json(), { status: "ready" });

  const greeting = await fetch(`${baseUrl}/api/v1/greeting?name=Ada`);
  assert.equal(greeting.status, 200);
  assert.deepEqual(await greeting.json(), {
    message: "Hello, Ada!",
    environment: "test",
  });

  const invalid = await fetch(`${baseUrl}/api/v1/greeting?name=`);
  assert.equal(invalid.status, 400);

  const missing = await fetch(`${baseUrl}/missing`);
  assert.equal(missing.status, 404);
});
