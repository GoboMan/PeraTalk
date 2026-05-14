/** CORS と最小 JSON 応答。*/

export const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

export function preflight(req: Request): Response | null {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  return null;
}

/** 処理未実装のプレースホルダ応答（200 + `{ ok: true }`）。 */
export function jsonStub(): Response {
  return new Response(JSON.stringify({ ok: true }), {
    status: 200,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

export function jsonProblem(
  status: number,
  code: string,
  detail: string,
): Response {
  return new Response(
    JSON.stringify({ type: "error", code, message: detail }),
    {
      status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    },
  );
}
