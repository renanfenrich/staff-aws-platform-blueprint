import type { LogLevel } from "./config.js";

export type LogFields = Record<string, unknown>;

export interface Logger {
  debug(message: string, fields?: LogFields): void;
  error(message: string, fields?: LogFields): void;
  info(message: string, fields?: LogFields): void;
  warn(message: string, fields?: LogFields): void;
}

const priorities: Record<LogLevel, number> = {
  debug: 10,
  info: 20,
  warn: 30,
  error: 40,
};

export function createLogger(minimumLevel: LogLevel): Logger {
  function write(level: LogLevel, message: string, fields: LogFields = {}): void {
    if (priorities[level] < priorities[minimumLevel]) {
      return;
    }

    const line = JSON.stringify({
      timestamp: new Date().toISOString(),
      level,
      message,
      ...fields,
    });

    const stream = level === "error" ? process.stderr : process.stdout;
    stream.write(`${line}\n`);
  }

  return {
    debug: (message, fields) => write("debug", message, fields),
    error: (message, fields) => write("error", message, fields),
    info: (message, fields) => write("info", message, fields),
    warn: (message, fields) => write("warn", message, fields),
  };
}
