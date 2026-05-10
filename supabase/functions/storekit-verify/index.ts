import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { jsonStub, preflight } from "../_shared/http.ts";

/**
 * StoreKit 2 クライアント検証（補助経路）。S2S が最終確定（未実装）。
 */
Deno.serve(async (req) => {
  const opt = preflight(req);
  if (opt) return opt;
  return jsonStub();
});
