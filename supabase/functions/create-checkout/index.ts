// Starts a Stripe Checkout session for Trackside Premium.
// POST { plan: "monthly" | "annual", return_url?: string }  (signed-in rider's JWT required)
import Stripe from "npm:stripe@17.7.0";
import { createClient } from "npm:@supabase/supabase-js@2.49.4";

const PLANS: Record<string, { amount: number; interval: "month" | "year"; trialDays: number }> = {
  monthly: { amount: 399, interval: "month", trialDays: 0 }, // US$3.99 a month
  annual: { amount: 2999, interval: "year", trialDays: 7 }, // US$29.99 a year, 7-day free trial
};
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

    const { plan, return_url } = await req.json().catch(() => ({}));
    const p = PLANS[plan as string];
    if (!p) return json({ error: "Unknown plan." }, 400);

    const stripe = new Stripe(key);
    const admin = createClient(supabaseUrl, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const { data: profile } = await admin.from("profiles").select("stripe_customer_id, is_premium").eq("id", user.id).single();
    if (profile?.is_premium) return json({ error: "You already have Premium." }, 409);

    let customer = profile?.stripe_customer_id as string | null;
    if (!customer) {
      const c = await stripe.customers.create({ email: user.email, metadata: { supabase_user_id: user.id } });
      customer = c.id;
      await admin.from("profiles").update({ stripe_customer_id: customer }).eq("id", user.id);
    }

    const base = safeReturn(return_url);
    const session = await stripe.checkout.sessions.create({
      mode: "subscription",
      customer,
      client_reference_id: user.id,
      line_items: [{
        quantity: 1,
        price_data: {
          currency: "usd",
          unit_amount: p.amount,
          recurring: { interval: p.interval },
          product_data: { name: "Trackside Premium" },
        },
      }],
      subscription_data: {
        metadata: { supabase_user_id: user.id, plan: String(plan) },
        ...(p.trialDays ? { trial_period_days: p.trialDays } : {}),
      },
      allow_promotion_codes: true,
      success_url: `${base}?checkout=success#home`,
      cancel_url: `${base}?checkout=cancel#home`,
    });
    return json({ url: session.url });
  } catch (e) {
    console.error(e);
    return json({ error: "Could not start checkout. Please try again." }, 500);
  }
});
