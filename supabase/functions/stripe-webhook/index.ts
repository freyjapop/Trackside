// Receives Stripe events and switches Premium on or off in public.profiles.
// Stripe calls this directly, so JWT verification is off; the Stripe signature is checked instead.
import Stripe from "npm:stripe@17.7.0";
import { createClient } from "npm:@supabase/supabase-js@2.49.4";

const PREMIUM_STATUSES = new Set(["active", "trialing", "past_due"]);

Deno.serve(async (req) => {
  const key = Deno.env.get("STRIPE_SECRET_KEY");
  const whsec = Deno.env.get("STRIPE_WEBHOOK_SECRET");
  if (!key || !whsec) return new Response("Payments are not set up yet.", { status: 503 });

  const stripe = new Stripe(key);
  const signature = req.headers.get("stripe-signature");
  const body = await req.text();
  let event: Stripe.Event;
  try {
    event = await stripe.webhooks.constructEventAsync(body, signature ?? "", whsec, undefined, Stripe.createSubtleCryptoProvider());
  } catch (e) {
    console.error("Bad signature", e);
    return new Response("Invalid signature", { status: 400 });
  }

  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  async function apply(sub: Stripe.Subscription, userIdHint?: string | null) {
    const customerId = typeof sub.customer === "string" ? sub.customer : sub.customer.id;
    let userId = userIdHint ?? (sub.metadata?.supabase_user_id || null);
    if (!userId) {
      const { data } = await admin.from("profiles").select("id").eq("stripe_customer_id", customerId).maybeSingle();
      userId = data?.id ?? null;
    }
    if (!userId) { console.error("No rider for customer", customerId); return; }

    // current_period_end moved onto subscription items in newer Stripe API versions.
    // deno-lint-ignore no-explicit-any
    const anySub = sub as any;
    const periodEnd: number | undefined = anySub.current_period_end ?? anySub.items?.data?.[0]?.current_period_end;
    const premium = PREMIUM_STATUSES.has(sub.status);
    const interval = sub.items?.data?.[0]?.price?.recurring?.interval;

    const { error } = await admin.from("profiles").update({
      is_premium: premium,
      premium_until: premium && periodEnd ? new Date((periodEnd + 3 * 86400) * 1000).toISOString().slice(0, 10) : null,
      stripe_customer_id: customerId,
      stripe_subscription_id: sub.id,
      subscription_status: sub.status,
      plan_interval: interval === "month" || interval === "year" ? interval : null,
    }).eq("id", userId);
    if (error) throw error;
  }

  try {
    switch (event.type) {
      case "checkout.session.completed": {
        const s = event.data.object as Stripe.Checkout.Session;
        if (s.mode === "subscription" && s.subscription) {
          const sub = await stripe.subscriptions.retrieve(typeof s.subscription === "string" ? s.subscription : s.subscription.id);
          await apply(sub, s.client_reference_id);
        }
        break;
      }
      case "customer.subscription.created":
      case "customer.subscription.updated":
      case "customer.subscription.deleted":
        await apply(event.data.object as Stripe.Subscription);
        break;
    }
    return new Response(JSON.stringify({ received: true }), { headers: { "Content-Type": "application/json" } });
  } catch (e) {
    console.error(e);
    return new Response("Webhook handler failed", { status: 500 });
  }
});
