import {
  GetSecretValueCommand,
  SecretsManagerClient,
} from "@aws-sdk/client-secrets-manager";

export interface SecretValueClient {
  send(command: GetSecretValueCommand): Promise<{ SecretString?: string }>;
}

export function parseDatabasePassword(
  secretString: string | undefined,
  expectedUsername?: string,
): string {
  if (!secretString) throw new Error("Database credential secret is unavailable");
  let parsed: unknown;
  try {
    parsed = JSON.parse(secretString);
  } catch {
    throw new Error("Database credential secret has an invalid format");
  }
  if (!parsed || typeof parsed !== "object")
    throw new Error("Database credential secret has an invalid format");
  const secret = parsed as { username?: unknown; password?: unknown };
  if (expectedUsername && secret.username !== expectedUsername) {
    throw new Error("Database credential username does not match configuration");
  }
  if (typeof secret.password !== "string" || secret.password.length === 0) {
    throw new Error("Database credential secret is missing a password");
  }
  return secret.password;
}

export function createSecretsPasswordProvider(
  secretArn: string,
  region: string,
  expectedUsername: string,
  client: SecretValueClient = new SecretsManagerClient({ region }),
): () => Promise<string> {
  return async () => {
    const response = await client.send(
      new GetSecretValueCommand({ SecretId: secretArn }),
    );
    return parseDatabasePassword(response.SecretString, expectedUsername);
  };
}
