import "jsr:@supabase/functions-js/edge-runtime.d.ts";

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-appwrite-jwt",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export class MediaFunctionError extends Error {
  constructor(public readonly code: string, public readonly status: number, message: string) {
    super(message);
  }
}

export function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });
}

export function errorResponse(error: unknown): Response {
  if (error instanceof MediaFunctionError) return json({ error: error.code, message: error.message }, error.status);
  console.error("community-media internal error", error instanceof Error ? error.name : "unknown");
  return json({ error: "internal_error", message: "The media service is temporarily unavailable." }, 500);
}

export function requirePostRequest(req: Request): void {
  if (req.method === "OPTIONS") throw new MediaFunctionError("cors_preflight", 204, "");
  if (req.method !== "POST") throw new MediaFunctionError("method_not_allowed", 405, "Only POST is supported.");
}

export function getEnv(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new MediaFunctionError("service_not_configured", 503, "The media service is not configured.");
  return value;
}

export function appwriteJwt(req: Request): string {
  const value = req.headers.get("x-appwrite-jwt")?.trim() || req.headers.get("authorization")?.replace(/^Bearer\s+/i, "").trim();
  if (!value) throw new MediaFunctionError("authentication_required", 401, "Sign in to use Community media.");
  return value;
}

export async function validateAppwriteIdentity(req: Request): Promise<{ id: string; name?: string; email?: string }> {
  const jwt = appwriteJwt(req);
  const endpoint = "https://nyc.cloud.appwrite.io/v1";
  const project = "6aa4295900094d600163";
  const response = await fetch(`${endpoint.replace(/\/$/, "")}/account`, {
    headers: { "X-Appwrite-Project": project, "X-Appwrite-JWT": jwt },
  });
  if (!response.ok) throw new MediaFunctionError("authentication_required", 401, "The Appwrite session is invalid or expired.");
  const body = await response.json();
  const id = typeof body?.$id === "string" ? body.$id.trim() : "";
  if (!id) throw new MediaFunctionError("authentication_required", 401, "The Appwrite session is invalid.");
  return { id, name: typeof body?.name === "string" ? body.name : undefined, email: typeof body?.email === "string" ? body.email : undefined };
}

export function serviceConfig() {
  return {
    supabaseUrl: getEnv("SUPABASE_URL").replace(/\/$/, ""),
    serviceRoleKey: getEnv("SUPABASE_SERVICE_ROLE_KEY"),
    b2KeyId: getEnv("B2_KEY_ID"),
    b2ApplicationKey: getEnv("B2_APPLICATION_KEY"),
    b2Bucket: getEnv("B2_BUCKET_NAME"),
    b2Endpoint: getEnv("B2_S3_ENDPOINT").replace(/\/$/, ""),
    b2Region: getEnv("B2_REGION"),
  };
}

export function supabaseHeaders(serviceRoleKey: string): HeadersInit {
  return { apikey: serviceRoleKey, Authorization: `Bearer ${serviceRoleKey}`, "Content-Type": "application/json" };
}

export async function supabaseGet(config: ReturnType<typeof serviceConfig>, path: string): Promise<any[]> {
  const response = await fetch(`${config.supabaseUrl}/rest/v1/${path}`, { headers: supabaseHeaders(config.serviceRoleKey) });
  if (!response.ok) throw new MediaFunctionError("database_error", 502, "The media metadata service is unavailable.");
  const body = await response.json();
  return Array.isArray(body) ? body : [];
}

export async function supabaseInsert(config: ReturnType<typeof serviceConfig>, table: string, payload: Record<string, unknown>): Promise<any> {
  const response = await fetch(`${config.supabaseUrl}/rest/v1/${table}`, { method: "POST", headers: { ...supabaseHeaders(config.serviceRoleKey), Prefer: "return=representation" }, body: JSON.stringify(payload) });
  if (!response.ok) throw new MediaFunctionError("database_error", 502, "The media metadata service is unavailable.");
  const body = await response.json();
  return Array.isArray(body) ? body[0] : body;
}

export async function supabaseDelete(config: ReturnType<typeof serviceConfig>, table: string, filter: string): Promise<void> {
  const response = await fetch(`${config.supabaseUrl}/rest/v1/${table}?${filter}`, { method: "DELETE", headers: supabaseHeaders(config.serviceRoleKey) });
  if (!response.ok) throw new MediaFunctionError("database_error", 502, "The media metadata service is unavailable.");
}

export async function supabaseUpdate(config: ReturnType<typeof serviceConfig>, table: string, filter: string, payload: Record<string, unknown>): Promise<any> {
  const response = await fetch(`${config.supabaseUrl}/rest/v1/${table}?${filter}`, { method: "PATCH", headers: { ...supabaseHeaders(config.serviceRoleKey), Prefer: "return=representation" }, body: JSON.stringify(payload) });
  if (!response.ok) throw new MediaFunctionError("database_error", 502, "The media metadata service is unavailable.");
  const body = await response.json();
  return Array.isArray(body) ? body[0] : body;
}

const encoder = new TextEncoder();
function hex(bytes: ArrayBuffer): string { return Array.from(new Uint8Array(bytes)).map((byte) => byte.toString(16).padStart(2, "0")).join(""); }
async function sha256(value: string | ArrayBuffer): Promise<string> { return hex(await crypto.subtle.digest("SHA-256", typeof value === "string" ? encoder.encode(value) : value)); }
async function hmac(key: ArrayBuffer | Uint8Array, value: string): Promise<ArrayBuffer> {
  const cryptoKey = await crypto.subtle.importKey("raw", key, { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  return crypto.subtle.sign("HMAC", cryptoKey, encoder.encode(value));
}
function awsEncode(value: string): string { return encodeURIComponent(value).replace(/[!'()*]/g, (char) => `%${char.charCodeAt(0).toString(16).toUpperCase()}`); }
function canonicalKey(key: string): string { return key.split("/").filter(Boolean).map(awsEncode).join("/"); }
function amzDate(date: Date): { short: string; full: string } { const full = date.toISOString().replace(/[-:]|\.\d{3}/g, ""); return { short: full.slice(0, 8), full }; }

async function signingKey(secret: string, date: string, region: string, service: string): Promise<ArrayBuffer> {
  const kDate = await hmac(encoder.encode(`AWS4${secret}`), date);
  const kRegion = await hmac(kDate, region);
  const kService = await hmac(kRegion, service);
  return hmac(kService, "aws4_request");
}

function endpointParts(endpoint: string, bucket: string): { host: string; base: string } {
  const parsed = new URL(endpoint);
  return { host: `${bucket}.${parsed.host}`, base: `${parsed.protocol}//${bucket}.${parsed.host}` };
}

export async function presign(config: ReturnType<typeof serviceConfig>, method: "GET" | "PUT", key: string, contentType?: string, expires = 600): Promise<string> {
  const { host, base } = endpointParts(config.b2Endpoint, config.b2Bucket);
  const now = new Date();
  const date = amzDate(now);
  const service = "s3";
  const credential = `${config.b2KeyId}/${date.short}/${config.b2Region}/${service}/aws4_request`;
  const signedHeaders = contentType ? "content-type;host" : "host";
  const query = new URLSearchParams({ "X-Amz-Algorithm": "AWS4-HMAC-SHA256", "X-Amz-Credential": credential, "X-Amz-Date": date.full, "X-Amz-Expires": String(Math.min(Math.max(expires, 1), 3600)), "X-Amz-SignedHeaders": signedHeaders });
  const canonicalQuery = [...query.entries()].sort(([a], [b]) => a.localeCompare(b)).map(([key, value]) => `${awsEncode(key)}=${awsEncode(value)}`).join("&");
  const canonicalHeaders = contentType ? `content-type:${contentType}\nhost:${host}\n` : `host:${host}\n`;
  const canonicalRequest = [method, `/${canonicalKey(key)}`, canonicalQuery, canonicalHeaders, signedHeaders, "UNSIGNED-PAYLOAD"].join("\n");
  const scope = `${date.short}/${config.b2Region}/${service}/aws4_request`;
  const stringToSign = `AWS4-HMAC-SHA256\n${date.full}\n${scope}\n${await sha256(canonicalRequest)}`;
  const signature = hex(await hmac(await signingKey(config.b2ApplicationKey, date.short, config.b2Region, service), stringToSign));
  query.set("X-Amz-Signature", signature);
  return `${base}/${canonicalKey(key)}?${[...query.entries()].sort(([a], [b]) => a.localeCompare(b)).map(([key, value]) => `${awsEncode(key)}=${awsEncode(value)}`).join("&")}`;
}

export async function signedB2Request(config: ReturnType<typeof serviceConfig>, method: "HEAD" | "DELETE", key: string, contentType?: string): Promise<Response> {
  const { host, base } = endpointParts(config.b2Endpoint, config.b2Bucket);
  const now = new Date();
  const date = amzDate(now);
  const canonicalUri = `/${canonicalKey(key)}`;
  const canonicalHeaders = contentType ? `content-type:${contentType}\nhost:${host}\nx-amz-content-sha256:UNSIGNED-PAYLOAD\nx-amz-date:${date.full}\n` : `host:${host}\nx-amz-content-sha256:UNSIGNED-PAYLOAD\nx-amz-date:${date.full}\n`;
  const signedHeaders = contentType ? "content-type;host;x-amz-content-sha256;x-amz-date" : "host;x-amz-content-sha256;x-amz-date";
  const canonicalRequest = [method, canonicalUri, "", canonicalHeaders, signedHeaders, "UNSIGNED-PAYLOAD"].join("\n");
  const scope = `${date.short}/${config.b2Region}/s3/aws4_request`;
  const stringToSign = `AWS4-HMAC-SHA256\n${date.full}\n${scope}\n${await sha256(canonicalRequest)}`;
  const signature = hex(await hmac(await signingKey(config.b2ApplicationKey, date.short, config.b2Region, "s3"), stringToSign));
  return fetch(`${base}${canonicalUri}`, { method, headers: { Host: host, "x-amz-date": date.full, "x-amz-content-sha256": "UNSIGNED-PAYLOAD", ...(contentType ? { "content-type": contentType } : {}), Authorization: `AWS4-HMAC-SHA256 Credential=${config.b2KeyId}/${scope}, SignedHeaders=${signedHeaders}, Signature=${signature}` } });
}

export function readJson(req: Request): Promise<any> { return req.json().catch(() => { throw new MediaFunctionError("invalid_json", 400, "The request body is invalid."); }); }
export function requireString(value: unknown, name: string, max = 256): string { if (typeof value !== "string" || value.trim().length === 0 || value.length > max) throw new MediaFunctionError("invalid_input", 400, `Invalid ${name}.`); return value.trim(); }
export function requireMediaType(value: unknown): "image" | "audio" { if (value !== "image" && value !== "audio") throw new MediaFunctionError("invalid_media_type", 400, "Only image and audio media are supported."); return value; }
export function requireMime(type: "image" | "audio", value: unknown): string { const mime = requireString(value, "mime type", 128).toLowerCase(); const valid = type === "image" ? /^(image\/(jpeg|png|webp|gif))$/ : /^(audio\/(mpeg|mp4|aac|ogg|wav|webm|x-m4a))$/; if (!valid.test(mime)) throw new MediaFunctionError("invalid_mime", 400, "This media type is not supported."); return mime; }
export function requireSize(value: unknown, type: "image" | "audio"): number { const size = typeof value === "number" && Number.isInteger(value) ? value : NaN; const max = type === "image" ? 10 * 1024 * 1024 : 15 * 1024 * 1024; if (!Number.isFinite(size) || size < 1 || size > max) throw new MediaFunctionError("invalid_file_size", 400, "The file size is invalid or too large."); return size; }
export function objectKey(userId: string, postId: string, mediaType: string, mimeType: string): string { const extension = mimeType.split("/")[1].replace(/[^a-z0-9]/g, "").slice(0, 8) || "bin"; return `community/${userId}/${postId}/${crypto.randomUUID()}.${extension}`; }
export async function ownedPost(config: ReturnType<typeof serviceConfig>, postId: string, userId: string): Promise<any> { const rows = await supabaseGet(config, `community_posts?id=eq.${encodeURIComponent(postId)}&author_id=eq.${encodeURIComponent(userId)}&deleted_at=is.null&select=id,author_id&limit=1`); if (!rows.length) throw new MediaFunctionError("forbidden", 403, "You do not have permission for this post."); return rows[0]; }
