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

test("registration only classifies PostgreSQL unique violations as duplicate emails", async (t) => {
  const database: Database = {
    ...unavailableDatabase,
    query: async (query) => {
      if (query.startsWith("INSERT INTO users"))
        throw new Error("database unavailable");
      return { rows: [], rowCount: 0 };
    },
  };
  const app = createApp(config, silentLogger, database);
  app.server.listen(0, "127.0.0.1");
  await new Promise<void>((resolve) => app.server.once("listening", resolve));
  t.after(() => new Promise<void>((resolve) => app.server.close(() => resolve())));
  const address = app.server.address() as AddressInfo;
  const response = await fetch(`http://127.0.0.1:${address.port}/api/auth/register`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ email: "a@example.com", password: "password-long-A" }),
  });
  assert.equal(response.status, 503);
  assert.deepEqual(await response.json(), {
    error: "service_unavailable",
    requestId: response.headers.get("x-request-id"),
  });
});

test("registration maps SQLSTATE 23505 to a duplicate-email response", async (t) => {
  const database: Database = {
    ...unavailableDatabase,
    query: async (query) => {
      if (query.startsWith("INSERT INTO users")) throw { code: "23505" };
      return { rows: [], rowCount: 0 };
    },
  };
  const app = createApp(config, silentLogger, database);
  app.server.listen(0, "127.0.0.1");
  await new Promise<void>((resolve) => app.server.once("listening", resolve));
  t.after(() => new Promise<void>((resolve) => app.server.close(() => resolve())));
  const address = app.server.address() as AddressInfo;
  const response = await fetch(`http://127.0.0.1:${address.port}/api/auth/register`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ email: "A@Example.com", password: "password-long-A" }),
  });
  assert.equal(response.status, 409);
  assert.deepEqual(await response.json(), {
    error: "email_exists",
    requestId: response.headers.get("x-request-id"),
  });
});
