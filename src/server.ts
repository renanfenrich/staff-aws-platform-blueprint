import { randomUUID } from "node:crypto";
import { createServer, type Server, type ServerResponse } from "node:http";
import type { AppConfig } from "./config.js";
import type { Logger } from "./logger.js";

export interface App {
  server: Server;
  setReady(ready: boolean): void;
}

function sendJson(
  response: ServerResponse,
  statusCode: number,
  payload: Record<string, unknown>,
): void {
  response.writeHead(statusCode, {
    "cache-control": "no-store",
    "content-type": "application/json; charset=utf-8",
    "x-content-type-options": "nosniff",
  });
  response.end(JSON.stringify(payload));
}

export function createApp(config: AppConfig, logger: Logger): App {
  let ready = false;

  const server = createServer((request, response) => {
    const startedAt = process.hrtime.bigint();
    const requestId = randomUUID();
    const method = request.method ?? "UNKNOWN";
    const url = new URL(request.url ?? "/", "http://localhost");

    response.setHeader("x-request-id", requestId);
    response.once("finish", () => {
      const durationMs = Number(process.hrtime.bigint() - startedAt) / 1_000_000;
      logger.info("request.completed", {
        requestId,
        method,
        path: url.pathname,
        statusCode: response.statusCode,
        durationMs: Math.round(durationMs * 100) / 100,
      });
    });

    if (method !== "GET") {
      sendJson(response, 405, { error: "method_not_allowed", requestId });
      return;
    }

    if (url.pathname === "/health") {
      sendJson(response, 200, { status: "ok" });
      return;
    }

    if (url.pathname === "/ready") {
      sendJson(response, ready ? 200 : 503, {
        status: ready ? "ready" : "not_ready",
      });
      return;
    }

    if (url.pathname === "/api/v1/greeting") {
      const name = (url.searchParams.get("name") ?? "world").trim();
      if (name.length === 0 || name.length > 80) {
        sendJson(response, 400, {
          error: "invalid_name",
          requestId,
        });
        return;
      }

      sendJson(response, 200, {
        message: `Hello, ${name}!`,
        environment: config.environment,
      });
      return;
    }

    sendJson(response, 404, { error: "not_found", requestId });
  });

  server.keepAliveTimeout = 65_000;
  server.headersTimeout = 66_000;
  server.requestTimeout = 15_000;

  return {
    server,
    setReady(value: boolean): void {
      ready = value;
    },
  };
}
