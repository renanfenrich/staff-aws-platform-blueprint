import assert from "node:assert/strict";
import type { AddressInfo } from "node:net";
import test from "node:test";
import type { AppConfig } from "../src/config.js";
import type { Database } from "../src/database.js";
import type { Logger } from "../src/logger.js";
import { createApp } from "../src/server.js";

const config: AppConfig = {
  databaseUrl: "postgresql://unused",
  environment: "test",
  host: "127.0.0.1",
  logLevel: "error",
  port: 8080,
  sessionTtlHours: 24,
  shutdownTimeoutMs: 1_000,
};
const silentLogger: Logger = {
  debug: () => undefined,
  error: () => undefined,
  info: () => undefined,
  warn: () => undefined,
};
const unavailableDatabase: Database = {
  close: async () => undefined,
  query: async () => ({ rows: [], rowCount: 0 }),
  ready: async () => false,
};
test("health is database-independent and readiness reports database failure", async (t) => {
  const app = createApp(config, silentLogger, unavailableDatabase);
  app.server.listen(0, "127.0.0.1");
  await new Promise<void>((resolve) => app.server.once("listening", resolve));
  t.after(
    () =>
      new Promise<void>((resolve, reject) =>
        app.server.close((error) => (error ? reject(error) : resolve())),
      ),
  );
  const address = app.server.address() as AddressInfo;
  const baseUrl = `http://127.0.0.1:${address.port}`;
  const health = await fetch(`${baseUrl}/health`);
  assert.equal(health.status, 200);
  assert.deepEqual(await health.json(), { status: "ok" });
  const unavailable = await fetch(`${baseUrl}/ready`);
  assert.equal(unavailable.status, 503);
});
