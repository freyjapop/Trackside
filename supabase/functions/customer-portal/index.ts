// Opens the Stripe customer portal so a rider can change plan, update their card or cancel.
// POST { return_url?: string }  (signed-in rider's JWT required)
import Stripe from "npm:stripe@17.7.0";
import { createClient } from "npm:@supabase/supabase-js@2.49.4";

const DEFAULT_RETURN = Deno.env.get("SITE_URL") ?? "https://freyjapop.github.io/Trackside/";
const ALLOWED_ORIGINS = [new URL(DEFAULT_RETURN).origin, "http://localhost:8000", "http://127.0.0.1:8000"];

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

function safeReturn(url: unknown): string {
  try {
    const u = new URL(String(url));
    if (ALLOWED_ORIGINS.includes(u.origin)) return u.origin + u.pathname;
  } catch { /* fall through */ }
  return DEFAULT_RETURN;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Use POST" }, 405);
  const key = Deno.env.get("STRIPE_SECRET_KEY");
  if (!key) return json({ error: "Payments are not set up yet." }, 503);
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const asRider = createClient(supabaseUrl, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
    });
    const { data: { user }, error } = await asRider.auth.getUser();
    if (error || !user) return json({ error: "Please sign in first." }, 401);

    const admin = createClient(supabaseUrl, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const { data: profile } = await admin.from("profiles").select("stripe_customer_id").eq("id", user.id).single();
    if (!profile?.stripe_customer_id) return json({ error: "No subscription found." }, 404);

    const { return_url } = await req.json().catch(() => ({}));
    const stripe = new Stripe(key);
    const portal = await stripe.billingPortal.sessions.create({
      customer: profile.stripe_customer_id,
      return_url: `${safeReturn(return_url)}#home`,
    });
    return json({ url: portal.url });
  } catch (e) {
    console.error(e);
    return json({ error: "Could not open subscription settings. Please try again." }, 500);
  }
});
