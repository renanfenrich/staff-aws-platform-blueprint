import assert from "node:assert/strict";
import { once } from "node:events";
import { readdir } from "node:fs/promises";
import { dirname, join } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";
import { createFrontendServer } from "./server.mjs";

const root = join(dirname(fileURLToPath(import.meta.url)), "dist");
const server = createFrontendServer(root);
server.listen(0, "127.0.0.1");
await once(server, "listening");
const address = server.address();
const origin = `http://127.0.0.1:${address.port}`;

test.after(() => server.close());

test("serves health, SPA routes, and built static assets", async () => {
  const health = await fetch(`${origin}/health`);
  assert.equal(health.status, 200);
  assert.equal(await health.text(), "ok");
  const home = await fetch(`${origin}/`);
  assert.equal(home.status, 200);
  assert.match(await home.text(), /<div id="root"><\/div>/);
  const spa = await fetch(`${origin}/projects/123`);
  assert.equal(spa.status, 200);
  assert.match(await spa.text(), /<div id="root"><\/div>/);
  const asset = (await readdir(join(root, "assets"))).find((name) =>
    name.endsWith(".js"),
  );
  assert.ok(asset);
  assert.equal((await fetch(`${origin}/assets/${asset}`)).status, 200);
});

test("rejects missing assets, API paths, traversal, and unsupported methods", async () => {
  assert.equal((await fetch(`${origin}/missing.js`)).status, 404);
  assert.equal((await fetch(`${origin}/api`)).status, 404);
  assert.equal((await fetch(`${origin}/api/example`)).status, 404);
  assert.equal((await fetch(`${origin}/%2e%2e/server.mjs`)).status, 404);
  assert.equal((await fetch(`${origin}/%`)).status, 400);
  assert.equal((await fetch(`${origin}/`, { method: "POST" })).status, 405);
});

test("supports HEAD without a response body", async () => {
  const response = await fetch(`${origin}/health`, { method: "HEAD" });
  assert.equal(response.status, 200);
  assert.equal(await response.text(), "");
});
