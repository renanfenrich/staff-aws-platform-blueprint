export async function api<T>(path: string, init?: RequestInit): Promise<T> {
  const response = await fetch(path, {
    ...init,
    headers: { "content-type": "application/json", ...init?.headers },
  });
  if (!response.ok) throw new Error("Request failed");
  return response.status === 204 ? ({} as T) : ((await response.json()) as T);
}
