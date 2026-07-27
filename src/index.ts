import { once } from "node:events";
import { loadConfig } from "./config.js";
import { createLogger } from "./logger.js";
import { createApp } from "./server.js";

async function main(): Promise<void> {
  const config = loadConfig();
  const logger = createLogger(config.logLevel);
  const app = createApp(config, logger);
  let shuttingDown = false;

  async function shutdown(signal: NodeJS.Signals): Promise<void> {
    if (shuttingDown) {
      return;
    }

    shuttingDown = true;
    app.setReady(false);
    logger.info("server.shutdown_started", { signal });

    const closed = once(app.server, "close");
    app.server.close();

    const timeout = setTimeout(() => {
      logger.error("server.shutdown_timeout", {
        timeoutMs: config.shutdownTimeoutMs,
      });
      process.exitCode = 1;
      app.server.closeAllConnections();
    }, config.shutdownTimeoutMs);
    timeout.unref();

    await closed;
    clearTimeout(timeout);
    logger.info("server.shutdown_complete");
  }

  for (const signal of ["SIGINT", "SIGTERM"] as const) {
    process.once(signal, () => {
      void shutdown(signal);
    });
  }

  app.server.listen(config.port, config.host);
  await once(app.server, "listening");
  app.setReady(true);
  logger.info("server.started", {
    environment: config.environment,
    host: config.host,
    port: config.port,
  });
}

main().catch((error: unknown) => {
  process.stderr.write(
    `${JSON.stringify({
      timestamp: new Date().toISOString(),
      level: "error",
      message: "server.start_failed",
      error: error instanceof Error ? error.message : "unknown error",
    })}\n`,
  );
  process.exitCode = 1;
});
