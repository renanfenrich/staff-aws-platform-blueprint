export const logLevels = ["debug", "info", "warn", "error"] as const;
export type LogLevel = (typeof logLevels)[number];

const environments = ["development", "test", "production"] as const;
type Environment = (typeof environments)[number];

export interface AppConfig {
  environment: Environment;
  host: string;
  logLevel: LogLevel;
  port: number;
  shutdownTimeoutMs: number;
}

function parseInteger(
  name: string,
  rawValue: string | undefined,
  defaultValue: number,
  minimum: number,
  maximum: number,
): number {
  const value = rawValue ?? String(defaultValue);

  if (!/^\d+$/.test(value)) {
    throw new Error(`${name} must be an integer`);
  }

  const parsed = Number(value);
  if (parsed < minimum || parsed > maximum) {
    throw new Error(`${name} must be between ${minimum} and ${maximum}`);
  }

  return parsed;
}

function parseEnum<T extends string>(
  name: string,
  rawValue: string | undefined,
  defaultValue: T,
  allowed: readonly T[],
): T {
  const value = rawValue ?? defaultValue;
  if (!allowed.includes(value as T)) {
    throw new Error(`${name} must be one of: ${allowed.join(", ")}`);
  }

  return value as T;
}

export function loadConfig(env: NodeJS.ProcessEnv = process.env): AppConfig {
  const host = env.HOST ?? "0.0.0.0";
  if (host.trim().length === 0) {
    throw new Error("HOST must not be empty");
  }

  return {
    environment: parseEnum("NODE_ENV", env.NODE_ENV, "development", environments),
    host,
    logLevel: parseEnum("LOG_LEVEL", env.LOG_LEVEL, "info", logLevels),
    port: parseInteger("PORT", env.PORT, 8080, 1, 65_535),
    shutdownTimeoutMs: parseInteger(
      "SHUTDOWN_TIMEOUT_MS",
      env.SHUTDOWN_TIMEOUT_MS,
      10_000,
      1_000,
      60_000,
    ),
  };
}
