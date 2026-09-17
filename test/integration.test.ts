import assert from "node:assert/strict";
import type { AddressInfo } from "node:net";
import test from "node:test";
import { loadConfig } from "../src/config.js";
import { createDatabase } from "../src/database.js";
import { createLogger } from "../src/logger.js";
import { createApp } from "../src/server.js";

const databaseUrl =
  process.env.DATABASE_URL ?? "postgresql://app:app@127.0.0.1:5432/tracker";
const database = createDatabase(databaseUrl);
const app = createApp(
  loadConfig({ NODE_ENV: "test", DATABASE_URL: databaseUrl, LOG_LEVEL: "error" }),
  createLogger("error"),
  database,
);
let baseUrl = "";

async function request(
  path: string,
  init: RequestInit = {},
  cookie?: string,
): Promise<Response> {
  return fetch(`${baseUrl}${path}`, {
    ...init,
    headers: { "content-type": "application/json", ...(cookie ? { cookie } : {}) },
  });
}
function session(response: Response): string {
  const cookie = response.headers.get("set-cookie");
  assert.ok(cookie);
  return cookie.split(";")[0] ?? "";
}

test.before(async () => {
  assert.equal(await database.ready(), true);
  await database.query("TRUNCATE tasks, projects, sessions, users CASCADE");
  app.server.listen(0, "127.0.0.1");
  await new Promise<void>((resolve) => app.server.once("listening", resolve));
  baseUrl = `http://127.0.0.1:${(app.server.address() as AddressInfo).port}`;
});
test.after(async () => {
  await new Promise<void>((resolve, reject) =>
    app.server.close((error) => (error ? reject(error) : resolve())),
  );
  await app.close();
});

test("registration, sessions, projects, and tasks enforce ownership", async () => {
  assert.equal((await request("/health")).status, 200);
  assert.equal((await request("/ready")).status, 200);
  const aRegistration = await request("/api/auth/register", {
    method: "POST",
    body: JSON.stringify({ email: "A@Example.com", password: "password-long-A" }),
  });
  assert.equal(aRegistration.status, 201);
  const a = session(aRegistration);
  const hash = await database.query<{ password_hash: string }>(
    "SELECT password_hash FROM users WHERE email = $1",
    ["a@example.com"],
  );
  assert.notEqual(hash.rows[0]?.password_hash, "password-long-A");
  assert.equal(
    (
      await request("/api/auth/register", {
        method: "POST",
        body: JSON.stringify({ email: "a@example.com", password: "password-long-A" }),
      })
    ).status,
    409,
  );
  assert.equal(
    (
      await request("/api/auth/register", {
        method: "POST",
        body: JSON.stringify({ email: "not-email", password: "short" }),
      })
    ).status,
    400,
  );
  const projectResponse = await request(
    "/api/projects",
    { method: "POST", body: JSON.stringify({ name: "A project" }) },
    a,
  );
  assert.equal(projectResponse.status, 201);
  const project = ((await projectResponse.json()) as { project: { id: string } })
    .project;
  const taskResponse = await request(
    `/api/projects/${project.id}/tasks`,
    { method: "POST", body: JSON.stringify({ title: "A task" }) },
    a,
  );
  assert.equal(taskResponse.status, 201);
  const task = ((await taskResponse.json()) as { task: { id: string } }).task;
  const bRegistration = await request("/api/auth/register", {
    method: "POST",
    body: JSON.stringify({ email: "b@example.com", password: "password-long-B" }),
  });
  const b = session(bRegistration);
  for (const [path, init] of [
    [`/api/projects/${project.id}`, {}],
    [`/api/projects/${project.id}/tasks`, {}],
    [
      `/api/projects/${project.id}/tasks`,
      { method: "POST", body: JSON.stringify({ title: "intrusion" }) },
    ],
    [
      `/api/projects/${project.id}/tasks/${task.id}`,
      { method: "PATCH", body: JSON.stringify({ status: "done" }) },
    ],
  ] as const)
    assert.equal((await request(path, init, b)).status, 404);
  assert.equal((await request("/api/projects")).status, 401);
  assert.equal(
    (
      await request(
        `/api/projects/${project.id}/tasks/${task.id}`,
        { method: "PATCH", body: JSON.stringify({ status: "bad" }) },
        a,
      )
    ).status,
    400,
  );
  assert.equal(
    (
      await request(
        `/api/projects/${project.id}/tasks/${task.id}`,
        { method: "PATCH", body: JSON.stringify({ status: "done" }) },
        a,
      )
    ).status,
    200,
  );
  assert.equal((await request("/api/auth/logout", { method: "POST" }, a)).status, 204);
  assert.equal((await request("/api/projects", {}, a)).status, 401);
});

test("migrations are recorded and structural database constraints apply", async () => {
  const migrations = await database.query<{ id: string }>(
    "SELECT id FROM schema_migrations ORDER BY id",
  );
  assert.deepEqual(
    migrations.rows.map((row) => row.id),
    ["001_initial.sql"],
  );
  await assert.rejects(() =>
    database.query(
      "INSERT INTO users (id, email, password_hash) VALUES ('00000000-0000-4000-8000-000000000001', 'UPPER@example.com', 'x')",
    ),
  );
});
