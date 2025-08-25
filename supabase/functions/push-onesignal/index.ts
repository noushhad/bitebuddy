// @ts-nocheck
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Content-Type": "application/json; charset=utf-8",
};

// ✅ Env names (SUPABASE_* reserved)
const PROJECT_URL = Deno.env.get("PROJECT_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY")!;
const ANON_KEY = Deno.env.get("ANON_KEY")!; // <-- add this
const ONESIGNAL_APP_ID = Deno.env.get("ONESIGNAL_APP_ID")!;
const ONESIGNAL_REST_API_KEY = Deno.env.get("ONESIGNAL_REST_API_KEY")!;

// ---------- Helpers ----------
function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: CORS_HEADERS });
}

async function fetchJSON(url: string, init: RequestInit) {
  const res = await fetch(url, init);
  const text = await res.text();
  let data: any = text;
  try { data = text ? JSON.parse(text) : null; } catch {}
  if (!res.ok) throw new Error(`HTTP ${res.status} ${res.statusText}: ${text}`);
  return { data, status: res.status };
}

// ---------- Server ----------
serve(async (req) => {
  if (req.method === "OPTIONS") return json({}, 204);

  try {
    if (!ONESIGNAL_APP_ID || !ONESIGNAL_REST_API_KEY) {
      return json({ ok: false, error: "Missing OneSignal envs" }, 500);
    }

    const payload = await req.json();

    // -------- Rich flows (owner/customer) --------
    if (payload?.type === "owner_new_reservation" || payload?.type === "customer_status_update") {
      if (!PROJECT_URL || !SERVICE_ROLE_KEY || !ANON_KEY) {
        return json({ ok: false, error: "Missing Supabase service envs" }, 500);
      }

      const reservationId: string | undefined = payload?.reservation_id;
      if (!reservationId) return json({ ok: false, error: "reservation_id required" }, 400);

      // 1) Reservation (service role bypasses RLS)
      const { data: resv } = await fetchJSON(
        `${PROJECT_URL}/rest/v1/reservations?select=id,restaurant_id,user_id,guests,date,time,status&eq.id=${encodeURIComponent(reservationId)}`,
        {
          headers: {
            apikey: ANON_KEY,                                 // <-- anon here
            Authorization: `Bearer ${SERVICE_ROLE_KEY}`,       // <-- service role here
          },
        }
      );
      if (!Array.isArray(resv) || resv.length === 0) {
        return json({ ok: false, error: "Reservation not found" }, 404);
      }
      const reservation = resv[0];

      // 2) Restaurant (to get owner_id + name)
      const { data: rest } = await fetchJSON(
        `${PROJECT_URL}/rest/v1/restaurants?select=id,name,owner_id&eq.id=${encodeURIComponent(reservation.restaurant_id)}`,
        {
          headers: {
            apikey: ANON_KEY,                                 // <-- anon here
            Authorization: `Bearer ${SERVICE_ROLE_KEY}`,       // <-- service role here
          },
        }
      );
      if (!Array.isArray(rest) || rest.length === 0) {
        return json({ ok: false, error: "Restaurant not found" }, 404);
      }
      const restaurant = rest[0];

      // 3) OneSignal body
      let onesignalBody: Record<string, unknown>;
      if (payload.type === "owner_new_reservation") {
        const ownerUid = restaurant.owner_id as string;
        const dateTimeTxt = `${reservation.date} ${reservation.time}`;
        onesignalBody = {
          app_id: ONESIGNAL_APP_ID,
          include_aliases: { external_id: [ownerUid] },
          headings: { en: "New reservation request" },
          contents: { en: `New request at ${dateTimeTxt} for ${reservation.guests} guest(s) — ${restaurant.name}` },
          data: { kind: "owner_new_reservation", reservation_id: reservation.id, restaurant_id: restaurant.id },
        };
      } else {
        const customerUid = reservation.user_id as string;
        const title = payload.title ?? "Reservation update";
        const message = payload.message ?? `Your reservation at ${restaurant.name} is now "${reservation.status}".`;
        onesignalBody = {
          app_id: ONESIGNAL_APP_ID,
          include_aliases: { external_id: [customerUid] },
          headings: { en: title },
          contents: { en: message },
          data: {
            kind: "customer_status_update",
            reservation_id: reservation.id,
            restaurant_id: restaurant.id,
            status: reservation.status,
          },
        };
      }

      // 4) Send push
      const { data: pushRes } = await fetchJSON("https://api.onesignal.com/notifications", {
        method: "POST",
        headers: {
          "Content-Type": "application/json; charset=utf-8",
          Authorization: `Basic ${ONESIGNAL_REST_API_KEY}`,
        },
        body: JSON.stringify(onesignalBody),
      });

      return json({ ok: true, pushRes });
    }

    // -------- Legacy direct send --------
    const { userIds, title, body, data } = payload || {};
    if (!userIds || !Array.isArray(userIds) || userIds.length === 0) {
      return json({ ok: false, error: "No userIds provided and no supported type" }, 400);
    }

    const onesignalBody = {
      app_id: ONESIGNAL_APP_ID,
      include_aliases: { external_id: userIds },
      headings: { en: title || "" },
      contents: { en: body || "" },
      data: data || {},
    };

    const { data: legacyPushRes } = await fetchJSON("https://api.onesignal.com/notifications", {
      method: "POST",
      headers: {
        "Content-Type": "application/json; charset=utf-8",
        Authorization: `Basic ${ONESIGNAL_REST_API_KEY}`,
      },
      body: JSON.stringify(onesignalBody),
    });

    return json({ ok: true, pushRes: legacyPushRes });
  } catch (err: any) {
    return json({ ok: false, error: String(err?.message ?? err) }, 500);
  }
});
