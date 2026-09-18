import { afterEach, describe, expect, it, vi } from "vitest";
import { api } from "./api.js";

describe("API client", () => {
  afterEach(() => vi.unstubAllGlobals());

  it("uses the same-origin API and preserves auth cookies", async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValue(new Response('{"projects":[]}', { status: 200 }));
    vi.stubGlobal("fetch", fetchMock);
    await expect(api<{ projects: unknown[] }>("/api/projects")).resolves.toEqual({
      projects: [],
    });
    expect(fetchMock).toHaveBeenCalledWith(
      "/api/projects",
      expect.objectContaining({ headers: { "content-type": "application/json" } }),
    );
  });

  it("surfaces API failures instead of accepting an unauthenticated response", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue(new Response("{}", { status: 401 })),
    );
    await expect(api("/api/projects")).rejects.toThrow("Request failed");
  });
});
