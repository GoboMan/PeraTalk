import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { jsonStub, preflight } from "../_shared/http.ts";

/**
 * App Store Server Notifications V2（S2S）受け口。
 * 仕様: JWS 検証 → subscription_events 保存 → subscriptions 冪等更新（未実装）。
 */
Deno.serve(async (req) => {
  const opt = preflight(req);
  if (opt) return opt;
  return jsonStub();
});
