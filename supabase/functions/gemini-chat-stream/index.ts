import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { createClient } from "jsr:@supabase/supabase-js@2";
import { corsHeaders, jsonProblem, preflight } from "../_shared/http.ts";

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

/** Gemini SSE `data:` 行からテキスト断片のみを取り出す。 */
function geminiAccumulatedText(fragment: Record<string, unknown>): string {
  const candidates =
    fragment.candidates as Record<string, unknown>[] | undefined;
  if (!candidates?.[0]) return "";
  const content = candidates[0].content as Record<string, unknown> | undefined;
  const parts = content?.parts as Record<string, unknown>[] | undefined;
  if (!parts) return "";
  return parts.map((part) => (part?.text ?? "") as string).join("");
}

/** 開発用: Edge Function のシークレットに `GEMINI_CHAT_SKIP_AUTH=true` を置いたときだけ有効。本番では必ず未設定にすること。 */
function envFlagTrue(raw: string | undefined): boolean {
  if (raw == null) return false;
  const v = raw.trim().toLowerCase();
  return v === "1" || v === "true" || v === "yes";
}

function buildGeminiContents(messages: ChatMessageWire[]) {
  return messages.map((m) => {
    const normalized = (m.role || "user").toLowerCase();
    const role =
      normalized === "assistant" || normalized === "model"
        ? "model"
        : "user";
    return {
      role,
      parts: [{ text: m.text }],
    };
  });
}

Deno.serve(async (req) => {
  const opt = preflight(req);
  if (opt) return opt;

  if (req.method !== "POST") {
    return jsonProblem(405, "method_not_allowed", "POST only");
  }

  try {
    const skipAuth = envFlagTrue(Deno.env.get("GEMINI_CHAT_SKIP_AUTH"));
    if (skipAuth) {
      console.warn(
        "gemini-chat-stream: GEMINI_CHAT_SKIP_AUTH is set — auth checks skipped (development only)",
      );
    }

    if (!skipAuth) {
      const authHeader = req.headers.get("Authorization");
      if (!authHeader?.startsWith("Bearer ")) {
        return jsonProblem(401, "unauthorized", "Bearer token required");
      }

      const supabaseUrl = Deno.env.get("SUPABASE_URL");
      const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
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

    const geminiKey = Deno.env.get("GEMINI_API_KEY");
    if (!geminiKey) {
      return jsonProblem(500, "config", "GEMINI_API_KEY missing");
    }

    const parsed = (await req.json()) as RequestBodyWire;
    if (
      !parsed.messages ||
      !Array.isArray(parsed.messages) ||
      parsed.messages.length === 0
    ) {
      return jsonProblem(
        400,
        "invalid_body",
        "messages[] with at least one entry required"
      );
    }

    const requestId = parsed.request_id?.trim()?.length ? parsed.request_id! : crypto.randomUUID();

    const model =
      Deno.env.get("GEMINI_CHAT_MODEL")?.trim()?.length ?
        Deno.env.get("GEMINI_CHAT_MODEL")! :
      "gemini-2.0-flash";

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

    const geminiPayload = {
      contents: buildGeminiContents(parsed.messages),
      systemInstruction: {
        parts: [{ text: systemInstruction }],
      },
    };

    const geminiRoot =
      Deno.env.get("GEMINI_API_HOST")?.trim()?.length ?
        Deno.env.get("GEMINI_API_HOST")! :
      "https://generativelanguage.googleapis.com/v1beta";

    const upstreamUrl =
      `${geminiRoot}/models/${encodeURIComponent(model)}` +
      `:streamGenerateContent?alt=sse&key=${encodeURIComponent(geminiKey)}`;

    const upstream = await fetch(upstreamUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(geminiPayload),
    });

    if (!upstream.ok || !upstream.body) {
      const text = await upstream.text();
      return jsonProblem(upstream.status, "upstream_gemini_failed", text);
    }

    const encoder = new TextEncoder();

    const stream = new ReadableStream<Uint8Array>({
      async start(controller) {
        controller.enqueue(encoder.encode(metaEvent(requestId)));

        const reader = upstream.body!.getReader();
        const decoder = new TextDecoder();
        let buffer = "";
        /** iOS クライアントは追記デルタ前提。Gemini は同一ターンの累積全文を返すため差分だけ送る。 */
        const streamTextAcc = { lastFull: "" };

        try {
          while (true) {
            const { value, done } = await reader.read();
            if (done) break;
            buffer += decoder.decode(value, { stream: true });
            buffer = consumeGeminiSSEBuffer(
              controller,
              encoder,
              buffer,
              requestId,
              streamTextAcc,
            );
          }
          flushTrailingBuffer(
            controller,
            encoder,
            buffer,
            requestId,
            streamTextAcc,
          );

          controller.enqueue(encoder.encode(doneEvent(requestId)));
          controller.close();
        } catch (e) {
          try {
            controller.enqueue(
              encoder.encode(
                sseErrorEnvelope(
                  e instanceof Error ? e.message : "stream_error_ex"
                )
              )
            );
          } catch {
            //
          }
          controller.close();
        }
      },
    });

    const headers: Record<string, string> = {
      ...corsHeaders,
      "Content-Type": "text/event-stream; charset=utf-8",
      "Cache-Control": "no-cache",
      Connection: "keep-alive",
    };

    return new Response(stream, { status: 200, headers });
  } catch (_) {
    return jsonProblem(500, "unexpected", "stream bootstrap failed");
  }
});

function metaEvent(requestId: string) {
  return sseBlock({
    event: "meta",
    payload: JSON.stringify({ type: "meta", request_id: requestId }),
  });
}

function doneEvent(requestId: string) {
  return sseBlock({
    event: "done",
    payload: JSON.stringify({ type: "done", request_id: requestId }),
  });
}

function sseBlock(parts: { event: string; payload: string }) {
  const lines =
    [`event: ${parts.event}`, `data: ${parts.payload}`].join("\n") +
    `\n\n`;
  return lines;
}

function sseErrorEnvelope(message: string) {
  return sseBlock({
    event: "error",
    payload: JSON.stringify({
      type: "error",
      code: "stream_internal",
      message,
    }),
  });
}

/** BFF 向け SSE 送信（追記用の差分テキスト）。 */
function enqueueDelta(controller: ReadableStreamDefaultController<Uint8Array>, encoder: TextEncoder,
  fragment: string, requestId: string) {
  if (fragment.length === 0) return;
  const body = sseBlock({
    event: "delta",
    payload: JSON.stringify({
      type: "delta",
      text: fragment,
      request_id: requestId,
    }),
  });
  controller.enqueue(encoder.encode(body));
}

type StreamTextAccumulator = { lastFull: string };

function deltaFromAccumulated(
  acc: StreamTextAccumulator,
  accumulated: string,
): string {
  if (accumulated === acc.lastFull) return "";
  let delta: string;
  if (accumulated.startsWith(acc.lastFull)) {
    delta = accumulated.slice(acc.lastFull.length);
  } else {
    delta = accumulated;
  }
  acc.lastFull = accumulated;
  return delta;
}

function consumeGeminiSSEBuffer(
  controller: ReadableStreamDefaultController<Uint8Array>,
  encoder: TextEncoder,
  bufferArg: string,
  requestId: string,
  streamTextAcc: StreamTextAccumulator,
): string {
  let buffer = bufferArg;
  while (true) {
    const sep = buffer.indexOf("\n\n");
    if (sep < 0) break;

    const block = buffer.slice(0, sep);
    buffer = buffer.slice(sep + 2);

    for (const line of block.split("\n")) {
      const trimmedLine = line.trim();
      if (!trimmedLine.startsWith("data:")) continue;

      const data = trimmedLine.slice(5).trim();
      if (data === "[DONE]") continue;
      try {
        const obj = JSON.parse(data) as Record<string, unknown>;
        const full = geminiAccumulatedText(obj);
        const delta = deltaFromAccumulated(streamTextAcc, full);
        enqueueDelta(controller, encoder, delta, requestId);
      } catch (_) {
        // ignore malformed Gemini chunk boundary
      }
    }
  }
  return buffer;
}

function flushTrailingBuffer(
  controller: ReadableStreamDefaultController<Uint8Array>,
  encoder: TextEncoder,
  buffer: string,
  requestId: string,
  streamTextAcc: StreamTextAccumulator,
) {
  if (!buffer.trim()) return;

  consumeGeminiSSEBuffer(
    controller,
    encoder,
    `${buffer.trim()}\n\n`,
    requestId,
    streamTextAcc,
  );
}
