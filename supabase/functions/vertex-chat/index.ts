import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { createClient } from "jsr:@supabase/supabase-js@2";
import { corsHeaders, jsonProblem, preflight } from "../_shared/http.ts";
import {
  getGoogleAccessToken,
  readProjectIdFromServiceAccount,
} from "../_shared/gcp_oauth.ts";

/**
 * Vertex AI (Gemini) `:generateContent` の **非ストリーミング** プロキシ。
 *
 * - 認証: 既存の Supabase JWT を関数内で検証（`gemini-chat-stream` と同方針）。
 * - GCP 認証: Secret `GCP_SERVICE_ACCOUNT_JSON` を JWT 署名 → access_token 取得。
 * - レスポンスは 1 回で `{ request_id, text, raw }` を返す（将来 stream 版を別関数で追加予定）。
 */

type ChatMessageWire = {
  role: string;
  text: string;
};

type RequestBodyWire = {
  request_id?: string;
  messages: ChatMessageWire[];
  persona_prompt?: string | null;
  theme_description?: string | null;
};

function envFlagTrue(raw: string | undefined): boolean {
  if (raw == null) return false;
  const v = raw.trim().toLowerCase();
  return v === "1" || v === "true" || v === "yes";
}

function envString(name: string): string | null {
  const v = Deno.env.get(name);
  if (v == null) return null;
  const trimmed = v.trim();
  return trimmed.length === 0 ? null : trimmed;
}

function buildVertexContents(messages: ChatMessageWire[]) {
  return messages.map((m) => {
    const normalized = (m.role || "user").toLowerCase();
    const role =
      normalized === "assistant" || normalized === "model" ? "model" : "user";
    return {
      role,
      parts: [{ text: m.text }],
    };
  });
}

function extractVertexText(response: unknown): string {
  const r = response as Record<string, unknown>;
  const candidates = r.candidates as Record<string, unknown>[] | undefined;
  if (!candidates?.[0]) return "";
  const content = candidates[0].content as Record<string, unknown> | undefined;
  const parts = content?.parts as Record<string, unknown>[] | undefined;
  if (!parts) return "";
  return parts.map((part) => (part?.text ?? "") as string).join("");
}

Deno.serve(async (req) => {
  const opt = preflight(req);
  if (opt) return opt;

  if (req.method !== "POST") {
    return jsonProblem(405, "method_not_allowed", "POST only");
  }

  try {
    const skipAuth = envFlagTrue(Deno.env.get("VERTEX_CHAT_SKIP_AUTH"));
    if (skipAuth) {
      console.warn(
        "vertex-chat: VERTEX_CHAT_SKIP_AUTH is set — auth checks skipped (development only)",
      );
    }

    if (!skipAuth) {
      const authHeader = req.headers.get("Authorization");
      if (!authHeader?.startsWith("Bearer ")) {
        return jsonProblem(401, "unauthorized", "Bearer token required");
      }

      const supabaseUrl = envString("SUPABASE_URL");
      const supabaseAnonKey = envString("SUPABASE_ANON_KEY");
      if (!supabaseUrl || !supabaseAnonKey) {
        return jsonProblem(500, "config", "SUPABASE credentials missing");
      }

      const sb = createClient(supabaseUrl, supabaseAnonKey, {
        global: { headers: { Authorization: authHeader } },
      });

      const { data: authData, error: authErr } = await sb.auth.getUser(
        authHeader.replace("Bearer ", "").trim(),
      );

      if (authErr || !authData?.user?.id) {
        return jsonProblem(401, "unauthorized", "Invalid session");
      }
    }

    const serviceAccountJSON = envString("GCP_SERVICE_ACCOUNT_JSON");
    if (!serviceAccountJSON) {
      return jsonProblem(500, "config", "GCP_SERVICE_ACCOUNT_JSON missing");
    }

    const projectId =
      envString("VERTEX_PROJECT_ID") ??
      readProjectIdFromServiceAccount(serviceAccountJSON);
    if (!projectId) {
      return jsonProblem(
        500,
        "config",
        "VERTEX_PROJECT_ID missing and project_id not found in service account JSON",
      );
    }

    const region = envString("VERTEX_REGION") ?? "asia-northeast1";
    const model = envString("VERTEX_CHAT_MODEL") ?? "gemini-2.5-flash";

    const parsed = (await req.json()) as RequestBodyWire;
    if (
      !parsed.messages ||
      !Array.isArray(parsed.messages) ||
      parsed.messages.length === 0
    ) {
      return jsonProblem(
        400,
        "invalid_body",
        "messages[] with at least one entry required",
      );
    }

    const requestId = parsed.request_id?.trim()?.length
      ? parsed.request_id!
      : crypto.randomUUID();

    const systemPieces: string[] = [
      "You are a conversational English tutoring partner.",
      "Keep responses natural — short‑to‑medium spoken English sentences suitable for headphones.",
      "Use clear punctuation.",
      "Reply with only the tutoring partner's spoken English — no role labels (e.g. Assistant / アシスタント), no colons after a role name, and no meta commentary about being an AI or assistant.",
      "Every reply MUST end with one clear question to the learner in English. The last non‑whitespace character of your reply must be '?'.",
    ];
    if (parsed.persona_prompt) {
      systemPieces.push(parsed.persona_prompt);
    }
    if (parsed.theme_description) {
      systemPieces.push(`Theme / situation: ${parsed.theme_description}`);
    }
    const systemInstruction = systemPieces.join("\n\n");

    const accessToken = await getGoogleAccessToken(
      serviceAccountJSON,
      "https://www.googleapis.com/auth/cloud-platform",
    );

    const vertexHost =
      envString("VERTEX_HOST") ?? `https://${region}-aiplatform.googleapis.com`;

    const upstreamUrl =
      `${vertexHost}/v1/projects/${encodeURIComponent(projectId)}` +
      `/locations/${encodeURIComponent(region)}` +
      `/publishers/google/models/${encodeURIComponent(model)}:generateContent`;

    const payload = {
      contents: buildVertexContents(parsed.messages),
      systemInstruction: { parts: [{ text: systemInstruction }] },
    };

    const upstream = await fetch(upstreamUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify(payload),
    });

    if (!upstream.ok) {
      const text = await upstream.text();
      return jsonProblem(upstream.status, "upstream_vertex_failed", text);
    }

    const responseJson = await upstream.json();
    const text = extractVertexText(responseJson);

    return new Response(
      JSON.stringify({
        type: "result",
        request_id: requestId,
        text,
        raw: responseJson,
      }),
      {
        status: 200,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json; charset=utf-8",
        },
      },
    );
  } catch (e) {
    const message = e instanceof Error ? e.message : "vertex-chat unexpected";
    return jsonProblem(500, "unexpected", message);
  }
});
