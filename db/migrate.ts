import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { readdir, readFile } from "node:fs/promises";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { Client } from "pg";
import { type DatabaseConfig, loadConfig } from "../src/config.js";
import { createSecretsPasswordProvider } from "../src/database-credentials.js";

const migrationsDirectory = join(process.cwd(), "db", "migrations");

export async function migrate(config: DatabaseConfig): Promise<void> {
  const client = new Client(
    config.mode === "url"
      ? { connectionString: config.connectionString }
      : {
          host: config.host,
          port: config.port,
          database: config.database,
          user: config.user,
          password: createSecretsPasswordProvider(
            config.secretArn,
            config.region,
            config.user,
          ),
          ssl: { ca: readFileSync(config.sslCaPath, "utf8"), rejectUnauthorized: true },
        },
  );
  await client.connect();
  try {
    await client.query(`CREATE TABLE IF NOT EXISTS schema_migrations (
      id TEXT PRIMARY KEY,
      checksum TEXT NOT NULL,
      applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )`);
    const files = (await readdir(migrationsDirectory))
      .filter((file) => file.endsWith(".sql"))
      .sort();
    for (const file of files) {
      const sql = await readFile(join(migrationsDirectory, file), "utf8");
      const checksum = createHash("sha256").update(sql).digest("hex");
      await client.query("BEGIN");
      try {
        const result = await client.query<{ checksum: string }>(
          "SELECT checksum FROM schema_migrations WHERE id = $1 FOR UPDATE",
          [file],
        );
        if (result.rowCount === 0) {
          await client.query(sql);
          await client.query(
            "INSERT INTO schema_migrations (id, checksum) VALUES ($1, $2)",
            [file, checksum],
          );
        } else if (result.rows[0]?.checksum !== checksum) {
          throw new Error(`Migration checksum mismatch for ${file}`);
        }
        await client.query("COMMIT");
      } catch (error) {
        await client.query("ROLLBACK");
        throw error;
      }
    }
  } finally {
    await client.end();
  }
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  await migrate(loadConfig().database);
}
