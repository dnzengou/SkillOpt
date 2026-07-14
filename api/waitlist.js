export const config = { runtime: 'edge' };

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const CORS = {
  'access-control-allow-origin': '*',
  'access-control-allow-methods': 'POST, OPTIONS',
  'access-control-allow-headers': 'content-type',
};

// Airtable is opinionated for MVP: 1000 rows free, no schema management, exportable.
// Swap for Supabase/ConvertKit/Loops.so by changing store() only.
async function store({ email, source, plan, ua, ip }) {
  const key = globalThis.process?.env?.AIRTABLE_API_KEY;
  const base = globalThis.process?.env?.AIRTABLE_BASE_ID;
  const table = globalThis.process?.env?.AIRTABLE_TABLE || 'Waitlist';
  if (!key || !base) throw new Error('storage-unconfigured');
  const url = `https://api.airtable.com/v0/${base}/${encodeURIComponent(table)}`;
  const r = await fetch(url, {
    method: 'POST',
    headers: { authorization: `Bearer ${key}`, 'content-type': 'application/json' },
    body: JSON.stringify({
      fields: { Email: email, Source: source, Plan: plan, UA: ua, IP: ip, Timestamp: new Date().toISOString() },
      typecast: true,
    }),
  });
  if (!r.ok) throw new Error(`store-${r.status}`);
  return r.json();
}

// Best-effort in-memory throttle per edge instance. Not a substitute for
// Upstash/Cloudflare-KV at scale, but blocks trivial abuse for free.
const seen = new Map();
function throttle(ip) {
  const now = Date.now();
  const last = seen.get(ip) || 0;
  if (now - last < 3000) return false;
  seen.set(ip, now);
  if (seen.size > 500) seen.clear();
  return true;
}

export default async function handler(req) {
  if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: CORS });
  if (req.method !== 'POST') return json({ error: 'method-not-allowed' }, 405);

  const ip = req.headers.get('x-forwarded-for')?.split(',')[0].trim() || 'unknown';
  if (!throttle(ip)) return json({ error: 'rate-limited' }, 429);

  let body;
  try { body = await req.json(); } catch { return json({ error: 'invalid-json' }, 400); }
  const email = String(body?.email || '').trim().toLowerCase();
  if (!EMAIL_RE.test(email) || email.length > 200) return json({ error: 'invalid-email' }, 400);

  const source = String(body?.source || 'unknown').slice(0, 40);
  const plan = String(body?.plan || 'pro').slice(0, 20);
  const ua = req.headers.get('user-agent')?.slice(0, 200) || '';

  try {
    await store({ email, source, plan, ua, ip });
    // Best-effort: forward to gtm-engine for ICP scoring. Failure is silent —
    // Airtable already has the row; scoring can be replayed later.
    forwardToGtm({ email, source, plan, ua }).catch((e) =>
      console.warn('gtm-forward', e?.message || e),
    );
    return json({ ok: true, message: "You're in." }, 200);
  } catch (e) {
    // Never surface storage errors to the client; landing page has offline fallback.
    console.error('waitlist-store', e?.message || e);
    return json({ error: 'store-failed' }, 502);
  }
}

async function forwardToGtm({ email, source, plan, ua }) {
  const url = globalThis.process?.env?.GTM_ENGINE_URL;
  const token = globalThis.process?.env?.GTM_ENGINE_TOKEN;
  if (!url || !token) return;
  await fetch(`${url.replace(/\/$/, '')}/accounts`, {
    method: 'POST',
    headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
    body: JSON.stringify({ email, source, plan, ua }),
  });
}

function json(body, status) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json', ...CORS },
  });
}
