export const logLevels = ["debug", "info", "warn", "error"] as const;
export type LogLevel = (typeof logLevels)[number];

const environments = ["development", "test", "production"] as const;
type Environment = (typeof environments)[number];

export interface AppConfig {
  database: DatabaseConfig;
  environment: Environment;
  host: string;
  logLevel: LogLevel;
  port: number;
  shutdownTimeoutMs: number;
  sessionTtlHours: number;
}

export type DatabaseConfig =
  | { mode: "url"; connectionString: string }
  | {
      mode: "aws";
      host: string;
      port: number;
      database: string;
      user: string;
      secretArn: string;
      region: string;
      sslCaPath: string;
    };

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

  const environment = parseEnum("NODE_ENV", env.NODE_ENV, "development", environments);
  const awsFields = [
    "DATABASE_HOST",
    "DATABASE_PORT",
    "DATABASE_NAME",
    "DATABASE_USER",
    "DATABASE_SECRET_ARN",
    "AWS_REGION",
    "DATABASE_SSL_CA_PATH",
  ] as const;
  const hasAwsFields = awsFields.some((name) => env[name] !== undefined);
  if (env.DATABASE_URL && hasAwsFields) {
    throw new Error("DATABASE_URL cannot be combined with AWS database configuration");
  }
  if (environment === "production" && env.DATABASE_URL) {
    throw new Error("AWS database configuration is required in production");
  }
  if (!env.DATABASE_URL && !hasAwsFields && environment !== "production") {
    throw new Error("DATABASE_URL is required");
  }
  const database: DatabaseConfig = env.DATABASE_URL
    ? { mode: "url", connectionString: env.DATABASE_URL }
    : (() => {
        if (environment === "production" && !hasAwsFields) {
          throw new Error("AWS database configuration is required in production");
        }
        const required = (name: (typeof awsFields)[number]) => {
          const value = env[name];
          if (!value?.trim())
            throw new Error(`${name} is required for AWS database configuration`);
          return value;
        };
        return {
          mode: "aws" as const,
          host: required("DATABASE_HOST"),
          port: parseInteger(
            "DATABASE_PORT",
            required("DATABASE_PORT"),
            5432,
            1,
            65_535,
          ),
          database: required("DATABASE_NAME"),
          user: required("DATABASE_USER"),
          secretArn: required("DATABASE_SECRET_ARN"),
          region: required("AWS_REGION"),
          sslCaPath: required("DATABASE_SSL_CA_PATH"),
        };
      })();

  return {
    database,
    environment,
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
    sessionTtlHours: parseInteger(
      "SESSION_TTL_HOURS",
      env.SESSION_TTL_HOURS,
      24,
      1,
      720,
    ),
  };
}
