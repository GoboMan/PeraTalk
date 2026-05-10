import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { jsonStub, preflight } from "../_shared/http.ts";

/**
 * last_seen_at に基づく警告メール・段階削除（Cron 想定。本番ではシークレット検証等を追加）。
 */
Deno.serve(async (req) => {
  const opt = preflight(req);
  if (opt) return opt;
  return jsonStub();
});
