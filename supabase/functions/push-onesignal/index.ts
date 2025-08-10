// @ts-nocheck  <-- disables TS checking so VS Code won't complain about Deno imports/globals
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

serve(async (req) => {
  try {
    const { userIds, title, body, data } = await req.json();

    if (!userIds || !Array.isArray(userIds) || userIds.length === 0) {
      return new Response(JSON.stringify({ error: "No userIds provided" }), {
        status: 400,
      });
    }

    // Use globalThis.Deno to avoid type complaints
    const appId = (globalThis as any).Deno.env.get("cc41662b-1795-432b-9ced-8f69d487a56a");
    const apiKey = (globalThis as any).Deno.env.get("k774jhxbkug7mi7fhabfpgcjm");

    if (!appId || !apiKey) {
      return new Response(JSON.stringify({ error: "Missing OneSignal secrets" }), {
        status: 500,
      });
    }

    const res = await fetch("https://onesignal.com/api/v1/notifications", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Basic ${apiKey}`,
      },
      body: JSON.stringify({
        app_id: appId,
        include_aliases: { external_id: userIds },
        headings: { en: title || "" },
        contents: { en: body || "" },
        data: data || {},
      }),
    });

    const text = await res.text();

    if (!res.ok) {
      return new Response(text, { status: res.status });
    }

    return new Response(text, { status: 200 });
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), { status: 500 });
  }
});
