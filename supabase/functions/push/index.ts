// Функция «push»: отправляет уведомление партнёру через Firebase Cloud Messaging.
// Вызывается из базы данных после изменения записи (см. supabase/push.sql).
import { createClient } from "npm:@supabase/supabase-js@2";

const SA = JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT") ?? "{}");
const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

function b64url(data: ArrayBuffer | string): string {
  const bytes = typeof data === "string"
    ? new TextEncoder().encode(data)
    : new Uint8Array(data);
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

let cached: { token: string; exp: number } | null = null;

async function accessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cached && cached.exp > now + 60) return cached.token;
  const unsigned = b64url(JSON.stringify({ alg: "RS256", typ: "JWT" })) + "." +
    b64url(JSON.stringify({
      iss: SA.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
    }));
  const pem = String(SA.private_key).replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  );
  const r = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: unsigned + "." + b64url(sig),
    }),
  });
  const j = await r.json();
  if (!j.access_token) throw new Error("Нет access_token: " + JSON.stringify(j));
  cached = { token: j.access_token, exp: now + 3000 };
  return j.access_token;
}

function categoryOf(kind: string): string | null {
  switch (kind) {
    case "message": return "chat";
    case "shift":
    case "dayoff": return "schedule";
    case "event": return "event";
    case "shopping": return "shopping";
    case "todo": return "todo";
    case "post": return "feed";
    case "doc": return "docs";
    case "kiss": return "kiss";
  }
  return null;
}

const CATEGORY_TEXT: Record<string, string> = {
  schedule: "график",
  event: "события",
  shopping: "покупки",
  todo: "дела",
  feed: "ленту",
  docs: "документы",
};

Deno.serve(async (req) => {
  try {
    const body = await req.json();
    const incoming = body?.record;
    if (body?.table !== "records" || !incoming?.id) return new Response("ignored");
    const cat = categoryOf(String(incoming.kind));
    if (!cat) return new Response("ignored kind");
    // Правка сообщения (пометка «важное», реакция): это не новое сообщение, не уведомляем.
    if (incoming.kind === "message") {
      const edited = Number(incoming.data?.editedAt ?? 0);
      if (edited && Date.now() - edited < 120000) return new Response("edit");
      if (incoming.data?.from && incoming.data.from !== incoming.updated_by) {
        return new Response("flag change");
      }
    }

    // Текст берём из базы, а не из присланного запроса.
    const { data: row } = await supabase.from("records").select("*").eq("id", incoming.id).maybeSingle();
    if (!row) return new Response("gone");
    if (Date.now() - new Date(row.updated_at).getTime() > 30000) return new Response("stale");

    const ins = await supabase.from("push_log").insert({
      id: `${row.id}:${row.updated_at}`,
      pair_id: row.pair_id,
      category: cat,
    });
    if (ins.error) return new Response("duplicate");

    if (cat !== "chat") {
      const since = new Date(Date.now() - 60000).toISOString();
      const { count } = await supabase.from("push_log").select("id", { count: "exact", head: true })
        .eq("pair_id", row.pair_id).eq("category", cat).gt("sent_at", since);
      if ((count ?? 0) > 1) return new Response("throttled");
    }

    const { data: sender } = await supabase.from("members").select("name").eq("id", row.updated_by).maybeSingle();
    const name = sender?.name ?? "Партнёр";
    const { data: devices } = await supabase.from("devices").select("token")
      .eq("pair_id", row.pair_id).neq("member_id", row.updated_by);
    if (!devices?.length) return new Response("no devices");

    let title: string;
    let text: string;
    if (cat === "chat") {
      title = name;
      const t = String(row.data?.type ?? "text");
      const caption = String(row.data?.text ?? "").slice(0, 140);
      if (t === "image") text = "📷 Фото" + (caption ? ": " + caption : "");
      else if (t === "video") text = "🎥 Видео" + (caption ? ": " + caption : "");
      else if (t === "audio") text = "🎤 Голосовое сообщение";
      else if (t === "file") text = "📎 " + String(row.data?.name ?? "Файл");
      else text = caption || "Новое сообщение";
    } else if (cat === "kiss") {
      title = `${name} 💋`;
      text = "Прислал(а) тебе поцелуйчики";
    }

    const bearer = await accessToken();
    let sent = 0;
    for (const d of devices) {
      const r = await fetch(`https://fcm.googleapis.com/v1/projects/${SA.project_id}/messages:send`, {
        method: "POST",
        headers: { Authorization: `Bearer ${bearer}`, "Content-Type": "application/json" },
        body: JSON.stringify({
          message: {
            token: d.token,
            notification: { title, body: text },
            android: { priority: "HIGH", notification: { channel_id: "partner" } },
            webpush: { headers: { Urgency: "high" } },
          },
        }),
      });
      if (r.ok) {
        sent++;
      } else {
        const t = await r.text();
        console.log("FCM ошибка", r.status, t);
        if (r.status === 404 || t.includes("UNREGISTERED")) {
          await supabase.from("devices").delete().eq("token", d.token);
        }
      }
    }
    return new Response(`sent ${sent}`);
  } catch (e) {
    console.log("push error", String(e));
    return new Response("error: " + String(e), { status: 500 });
  }
});
