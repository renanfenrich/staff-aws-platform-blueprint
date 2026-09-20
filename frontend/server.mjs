import { createReadStream } from "node:fs";
import { access, stat } from "node:fs/promises";
import { createServer } from "node:http";
import { extname, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";

const mimeTypes = {
  ".css": "text/css; charset=utf-8",
  ".html": "text/html; charset=utf-8",
  ".ico": "image/x-icon",
  ".js": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".map": "application/json; charset=utf-8",
  ".svg": "image/svg+xml",
  ".woff2": "font/woff2",
};

const send = (response, status, body = "", headers = {}) => {
  response.writeHead(status, { "content-length": Buffer.byteLength(body), ...headers });
  response.end(body);
};

const safePath = (root, pathname) => {
  let decoded;
  try {
    decoded = decodeURIComponent(pathname);
  } catch {
    return null;
  }
  if (decoded.includes("\0") || decoded.includes("\\")) return null;
  const file = resolve(root, `.${decoded}`);
  return file === root || file.startsWith(`${root}${sep}`) ? file : null;
};

const serveFile = async (request, response, file) => {
  try {
    const details = await stat(file);
    if (!details.isFile()) return false;
    response.writeHead(200, {
      "content-length": details.size,
      "content-type": mimeTypes[extname(file)] ?? "application/octet-stream",
    });
    if (request.method === "HEAD") response.end();
    else createReadStream(file).pipe(response);
    return true;
  } catch {
    return false;
  }
};

export const createFrontendServer = (root) => {
  const buildRoot = resolve(root);
  return createServer(async (request, response) => {
    if (request.method !== "GET" && request.method !== "HEAD") {
      send(response, 405, "Method Not Allowed", { allow: "GET, HEAD" });
      return;
    }

    const pathname = new URL(request.url ?? "/", "http://localhost").pathname;
    if (pathname === "/health") {
      send(response, 200, "ok", { "content-type": "text/plain; charset=utf-8" });
      return;
    }
    if (pathname === "/api" || pathname.startsWith("/api/")) {
      send(response, 404, "Not Found", { "content-type": "text/plain; charset=utf-8" });
      return;
    }

    const file = safePath(buildRoot, pathname);
    if (!file) {
      send(response, 400, "Bad Request", {
        "content-type": "text/plain; charset=utf-8",
      });
      return;
    }
    if (await serveFile(request, response, file)) return;

    if (extname(pathname)) {
      send(response, 404, "Not Found", { "content-type": "text/plain; charset=utf-8" });
      return;
    }
    const index = resolve(buildRoot, "index.html");
    try {
      await access(index);
    } catch {
      send(response, 500, "Frontend build is unavailable");
      return;
    }
    if (!(await serveFile(request, response, index)))
      send(response, 500, "Frontend build is unavailable");
  });
};

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const root =
    process.env.FRONTEND_DIST_DIR ?? new URL("./dist", import.meta.url).pathname;
  const port = Number(process.env.PORT ?? 8080);
  const host = process.env.HOST ?? "0.0.0.0";
  createFrontendServer(root).listen(port, host);
}
