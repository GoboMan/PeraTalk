import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { jsonStub, preflight } from "../_shared/http.ts";

/**
 * 記憶用セッション要約・チャンクのサーバー取り込み（サニタイズ / LLM / ベクトル化は未実装）。
 */
Deno.serve(async (req) => {
  const opt = preflight(req);
  if (opt) return opt;
  return jsonStub();
});
