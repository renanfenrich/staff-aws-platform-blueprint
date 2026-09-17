import { createHash, randomBytes, randomUUID } from "node:crypto";
import {
  createServer,
  type IncomingMessage,
  type Server,
  type ServerResponse,
} from "node:http";
import { Algorithm, hash, verify } from "@node-rs/argon2";
import type { AppConfig } from "./config.js";
import type { Database } from "./database.js";
import type { Logger } from "./logger.js";

export interface App {
  close(): Promise<void>;
  server: Server;
}
type User = { id: string; email: string };
const statuses = new Set(["todo", "in_progress", "done"]);
function send(
  response: ServerResponse,
  status: number,
  payload: Record<string, unknown>,
  headers: Record<string, string> = {},
): void {
  response.writeHead(status, {
    "cache-control": "no-store",
    "content-type": "application/json; charset=utf-8",
    "x-content-type-options": "nosniff",
    ...headers,
  });
  response.end(JSON.stringify(payload));
}
function cookieValue(request: IncomingMessage): string | undefined {
  return request.headers.cookie
    ?.split(";")
    .map((part) => part.trim())
    .find((part) => part.startsWith("session="))
    ?.slice(8);
}
function sessionHash(token: string): string {
  return createHash("sha256").update(token).digest("hex");
}
function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
    value,
  );
}
async function body(
  request: IncomingMessage,
): Promise<Record<string, unknown> | undefined> {
  const chunks: Buffer[] = [];
  let size = 0;
  for await (const chunk of request) {
    size += chunk.length;
    if (size > 16_384) return undefined;
    chunks.push(chunk);
  }
  try {
    const parsed: unknown = JSON.parse(Buffer.concat(chunks).toString("utf8"));
    return parsed && typeof parsed === "object" && !Array.isArray(parsed)
      ? (parsed as Record<string, unknown>)
      : undefined;
  } catch {
    return undefined;
  }
}
function text(value: unknown, maximum: number): string | undefined {
  return typeof value === "string" &&
    value.trim().length > 0 &&
    value.trim().length <= maximum
    ? value.trim()
    : undefined;
}

export function createApp(config: AppConfig, logger: Logger, database: Database): App {
  async function authenticated(request: IncomingMessage): Promise<User | undefined> {
    const token = cookieValue(request);
    if (!token || !/^[A-Za-z0-9_-]{43}$/.test(token)) return undefined;
    const result = await database.query<User>(
      "SELECT u.id, u.email FROM sessions s JOIN users u ON u.id = s.user_id WHERE s.token_hash = $1 AND s.expires_at > now()",
      [sessionHash(token)],
    );
    return result.rows[0];
  }
  async function issueSession(response: ServerResponse, userId: string): Promise<void> {
    const token = randomBytes(32).toString("base64url");
    const expires = new Date(Date.now() + config.sessionTtlHours * 3_600_000);
    await database.query(
      "INSERT INTO sessions (token_hash, user_id, expires_at) VALUES ($1, $2, $3)",
      [sessionHash(token), userId, expires],
    );
    response.setHeader(
      "set-cookie",
      `session=${token}; HttpOnly; SameSite=Lax; Path=/; Expires=${expires.toUTCString()}${config.environment === "production" ? "; Secure" : ""}`,
    );
  }
  const server = createServer(async (request, response) => {
    const requestId = randomUUID();
    const method = request.method ?? "UNKNOWN";
    const url = new URL(request.url ?? "/", "http://localhost");
    response.setHeader("x-request-id", requestId);
    response.once("finish", () =>
      logger.info("request.completed", {
        requestId,
        method,
        path: url.pathname,
        statusCode: response.statusCode,
      }),
    );
    try {
      if (method === "GET" && url.pathname === "/health")
        return send(response, 200, { status: "ok" });
      if (method === "GET" && url.pathname === "/ready") {
        const ready = await database.ready();
        return send(response, ready ? 200 : 503, {
          status: ready ? "ready" : "not_ready",
        });
      }
      if (!url.pathname.startsWith("/api/"))
        return send(response, 404, { error: "not_found", requestId });
      if (method === "POST" && url.pathname === "/api/auth/register") {
        const input = await body(request);
        const email =
          typeof input?.email === "string"
            ? input.email.trim().toLowerCase()
            : undefined;
        const password =
          typeof input?.password === "string" ? input.password : undefined;
        if (
          !email ||
          !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) ||
          email.length > 254 ||
          !password ||
          password.length < 12 ||
          password.length > 128
        )
          return send(response, 400, { error: "invalid_input", requestId });
        const id = randomUUID();
        const passwordHash = await hash(password, {
          algorithm: Algorithm.Argon2id,
          memoryCost: 19456,
          timeCost: 2,
          parallelism: 1,
        });
        try {
          await database.query(
            "INSERT INTO users (id, email, password_hash) VALUES ($1, $2, $3)",
            [id, email, passwordHash],
          );
        } catch {
          return send(response, 409, { error: "email_exists", requestId });
        }
        await issueSession(response, id);
        return send(response, 201, { user: { id, email } });
      }
      if (method === "POST" && url.pathname === "/api/auth/login") {
        const input = await body(request);
        const email =
          typeof input?.email === "string" ? input.email.trim().toLowerCase() : "";
        const password = typeof input?.password === "string" ? input.password : "";
        const result = await database.query<{
          id: string;
          email: string;
          password_hash: string;
        }>("SELECT id, email, password_hash FROM users WHERE email = $1", [email]);
        const account = result.rows[0];
        if (!account || !(await verify(account.password_hash, password)))
          return send(response, 401, { error: "invalid_credentials", requestId });
        await issueSession(response, account.id);
        return send(response, 200, { user: { id: account.id, email: account.email } });
      }
      if (method === "POST" && url.pathname === "/api/auth/logout") {
        const token = cookieValue(request);
        if (token)
          await database.query("DELETE FROM sessions WHERE token_hash = $1", [
            sessionHash(token),
          ]);
        return send(
          response,
          204,
          {},
          { "set-cookie": "session=; HttpOnly; SameSite=Lax; Path=/; Max-Age=0" },
        );
      }
      const user = await authenticated(request);
      if (!user) return send(response, 401, { error: "unauthorized", requestId });
      if (method === "GET" && url.pathname === "/api/projects") {
        const result = await database.query(
          "SELECT id, name, created_at, updated_at FROM projects WHERE owner_user_id = $1 ORDER BY created_at DESC",
          [user.id],
        );
        return send(response, 200, { projects: result.rows });
      }
      if (method === "POST" && url.pathname === "/api/projects") {
        const name = text((await body(request))?.name, 120);
        if (!name) return send(response, 400, { error: "invalid_input", requestId });
        const id = randomUUID();
        const result = await database.query(
          "INSERT INTO projects (id, owner_user_id, name) VALUES ($1, $2, $3) RETURNING id, name, created_at, updated_at",
          [id, user.id, name],
        );
        return send(response, 201, { project: result.rows[0] ?? null });
      }
      const projectMatch = /^\/api\/projects\/([^/]+)(?:\/tasks(?:\/([^/]+))?)?$/.exec(
        url.pathname,
      );
      if (!projectMatch) return send(response, 404, { error: "not_found", requestId });
      const projectId = projectMatch[1];
      const taskId = projectMatch[2];
      if (!projectId || !isUuid(projectId))
        return send(response, 404, { error: "not_found", requestId });
      if (!taskId && method === "GET") {
        const project = await database.query(
          "SELECT id, name, created_at, updated_at FROM projects WHERE id = $1 AND owner_user_id = $2",
          [projectId, user.id],
        );
        return project.rows[0]
          ? send(response, 200, { project: project.rows[0] })
          : send(response, 404, { error: "not_found", requestId });
      }
      const project = await database.query(
        "SELECT id FROM projects WHERE id = $1 AND owner_user_id = $2",
        [projectId, user.id],
      );
      if (!project.rows[0])
        return send(response, 404, { error: "not_found", requestId });
      if (!taskId && method === "GET") {
        const tasks = await database.query(
          "SELECT id, title, status, created_at, updated_at FROM tasks WHERE project_id = $1 ORDER BY created_at",
          [projectId],
        );
        return send(response, 200, { tasks: tasks.rows });
      }
      if (!taskId && method === "POST") {
        const title = text((await body(request))?.title, 240);
        if (!title) return send(response, 400, { error: "invalid_input", requestId });
        const id = randomUUID();
        const task = await database.query(
          "INSERT INTO tasks (id, project_id, title) VALUES ($1, $2, $3) RETURNING id, title, status, created_at, updated_at",
          [id, projectId, title],
        );
        return send(response, 201, { task: task.rows[0] ?? null });
      }
      if (taskId && method === "PATCH") {
        if (!isUuid(taskId))
          return send(response, 404, { error: "not_found", requestId });
        const status = (await body(request))?.status;
        if (typeof status !== "string" || !statuses.has(status))
          return send(response, 400, { error: "invalid_input", requestId });
        const task = await database.query(
          "UPDATE tasks SET status = $1, updated_at = now() WHERE id = $2 AND project_id = $3 RETURNING id, title, status, created_at, updated_at",
          [status, taskId, projectId],
        );
        return task.rows[0]
          ? send(response, 200, { task: task.rows[0] })
          : send(response, 404, { error: "not_found", requestId });
      }
      return send(response, 405, { error: "method_not_allowed", requestId });
    } catch {
      send(response, 503, { error: "service_unavailable", requestId });
    }
  });
  server.keepAliveTimeout = 65_000;
  server.headersTimeout = 66_000;
  server.requestTimeout = 15_000;
  return {
    server,
    async close() {
      await database.close();
    },
  };
}
