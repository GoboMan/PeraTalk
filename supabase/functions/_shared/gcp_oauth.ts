/**
 * GCP サービスアカウント JSON から OAuth2 アクセストークンを取得する。
 *
 * - 鍵は Edge Function の Secret（例: `GCP_SERVICE_ACCOUNT_JSON`）として保持する想定。
 * - 取得済みトークンはモジュールスコープにメモリキャッシュ（Edge Function インスタンス寿命）。
 *   有効期限の 60 秒前までヒットとし、それ以降は再取得する。
 * - スコープ違い・鍵違いを跨ぐ場合に備えてキャッシュキーを `(client_email, scope)` で持つ。
 */

type ServiceAccountJSON = {
  client_email: string;
  private_key: string;
  token_uri?: string;
  project_id?: string;
};

type CachedToken = {
  accessToken: string;
  expiresAtEpochSec: number;
};

const tokenCache = new Map<string, CachedToken>();

export function readProjectIdFromServiceAccount(json: string): string | null {
  try {
    const parsed = JSON.parse(json) as ServiceAccountJSON;
    return parsed.project_id ?? null;
  } catch (_) {
    return null;
  }
}

export async function getGoogleAccessToken(
  serviceAccountJSON: string,
  scope: string,
): Promise<string> {
  const nowSec = Math.floor(Date.now() / 1000);
  const sa = parseServiceAccount(serviceAccountJSON);

  const cacheKey = `${sa.client_email}::${scope}`;
  const cached = tokenCache.get(cacheKey);
  if (cached && cached.expiresAtEpochSec - 60 > nowSec) {
    return cached.accessToken;
  }

  const tokenUri = sa.token_uri ?? "https://oauth2.googleapis.com/token";
  const assertion = await buildSignedJWT(sa, scope, tokenUri, nowSec);

  const body = new URLSearchParams({
    grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
    assertion,
  });

  const resp = await fetch(tokenUri, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: body.toString(),
  });

  if (!resp.ok) {
    const text = await resp.text();
    throw new Error(`google oauth token exchange failed (${resp.status}): ${text}`);
  }

  const data = (await resp.json()) as { access_token: string; expires_in: number };
  if (!data.access_token || !data.expires_in) {
    throw new Error("google oauth response missing access_token or expires_in");
  }

  tokenCache.set(cacheKey, {
    accessToken: data.access_token,
    expiresAtEpochSec: nowSec + data.expires_in,
  });
  return data.access_token;
}

function parseServiceAccount(json: string): ServiceAccountJSON {
  let parsed: ServiceAccountJSON;
  try {
    parsed = JSON.parse(json) as ServiceAccountJSON;
  } catch (_) {
    throw new Error("service account JSON parse failed");
  }
  if (!parsed.client_email || !parsed.private_key) {
    throw new Error("service account JSON missing client_email or private_key");
  }
  return parsed;
}

async function buildSignedJWT(
  sa: ServiceAccountJSON,
  scope: string,
  tokenUri: string,
  nowSec: number,
): Promise<string> {
  const header = base64UrlEncode(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = base64UrlEncode(
    JSON.stringify({
      iss: sa.client_email,
      scope,
      aud: tokenUri,
      iat: nowSec,
      exp: nowSec + 3600,
    }),
  );
  const signingInput = `${header}.${claims}`;
  const signature = await signRS256(sa.private_key, signingInput);
  return `${signingInput}.${signature}`;
}

async function signRS256(privateKeyPem: string, data: string): Promise<string> {
  const keyBytes = pemToPkcs8(privateKeyPem);
  const key = await crypto.subtle.importKey(
    "pkcs8",
    keyBytes,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(data),
  );
  return base64UrlEncode(new Uint8Array(signature));
}

/** PEM (`-----BEGIN PRIVATE KEY-----` 〜) を PKCS#8 DER バイト列にデコードする。 */
function pemToPkcs8(pem: string): Uint8Array {
  const normalized = pem.replace(/\\n/g, "\n");
  const stripped = normalized
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s+/g, "");
  const raw = atob(stripped);
  const out = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) out[i] = raw.charCodeAt(i);
  return out;
}

function base64UrlEncode(data: string | Uint8Array): string {
  const bytes = typeof data === "string" ? new TextEncoder().encode(data) : data;
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
