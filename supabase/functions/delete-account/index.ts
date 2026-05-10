import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { jsonStub, preflight } from "../_shared/http.ts";

/**
 * アカウント削除: 再認証済みユーザーを検証のうえ auth.users 削除（未実装）。
 */
Deno.serve(async (req) => {
  const opt = preflight(req);
  if (opt) return opt;
  return jsonStub();
});
