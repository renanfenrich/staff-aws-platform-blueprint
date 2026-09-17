import { Pool, type QueryResultRow } from "pg";

export interface Database {
  close(): Promise<void>;
  query<T extends QueryResultRow>(
    text: string,
    values?: readonly unknown[],
  ): Promise<{ rows: T[]; rowCount: number | null }>;
  ready(): Promise<boolean>;
}

export function createDatabase(connectionString: string): Database {
  const pool = new Pool({ connectionString, connectionTimeoutMillis: 1_500, max: 10 });
  return {
    async close() {
      await pool.end();
    },
    async query<T extends QueryResultRow>(
      text: string,
      values: readonly unknown[] = [],
    ) {
      return pool.query<T>(text, [...values]);
    },
    async ready() {
      let timeout: NodeJS.Timeout | undefined;
      try {
        await Promise.race([
          pool.query("SELECT 1"),
          new Promise<never>((_, reject) => {
            timeout = setTimeout(() => reject(new Error("readiness timeout")), 1_500);
          }),
        ]);
        return true;
      } catch {
        return false;
      } finally {
        if (timeout) clearTimeout(timeout);
      }
    },
  };
}
