import assert from "node:assert/strict";
import test from "node:test";
import { loadConfig } from "../src/config.js";

test("loadConfig applies safe defaults around required database configuration", () => {
  assert.deepEqual(loadConfig({ DATABASE_URL: "postgresql://example" }), {
    database: { mode: "url", connectionString: "postgresql://example" },
    environment: "development",
    host: "0.0.0.0",
    logLevel: "info",
    port: 8080,
    shutdownTimeoutMs: 10_000,
    sessionTtlHours: 24,
  });
});

test("loadConfig requires unambiguous AWS credentials in production", () => {
  assert.throws(
    () => loadConfig({ NODE_ENV: "production", DATABASE_URL: "postgresql://example" }),
    /AWS database configuration/,
  );
  assert.throws(
    () => loadConfig({ DATABASE_URL: "postgresql://example", DATABASE_HOST: "db" }),
    /cannot be combined/,
  );
  assert.deepEqual(
    loadConfig({
      NODE_ENV: "production",
      DATABASE_HOST: "db",
      DATABASE_PORT: "5432",
      DATABASE_NAME: "tracker",
      DATABASE_USER: "tracker_admin",
      DATABASE_SECRET_ARN: "arn:aws:secretsmanager:us-east-1:1:secret:x",
      AWS_REGION: "us-east-1",
      DATABASE_SSL_CA_PATH: "/app/rds-ca.pem",
    }).database,
    {
      mode: "aws",
      host: "db",
      port: 5432,
      database: "tracker",
      user: "tracker_admin",
      secretArn: "arn:aws:secretsmanager:us-east-1:1:secret:x",
      region: "us-east-1",
      sslCaPath: "/app/rds-ca.pem",
    },
  );
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
