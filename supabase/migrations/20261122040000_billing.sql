-- Trackside: Stripe billing fields. Written only by the stripe-webhook edge function (service role).
alter table public.profiles
  add column stripe_customer_id text unique,
  add column stripe_subscription_id text,
  add column subscription_status text,
  add column plan_interval text check (plan_interval in ('month', 'year'));

comment on column public.profiles.subscription_status is 'Mirrors the Stripe subscription status (trialing, active, past_due, canceled, ...).';
-- Riders can still only update display_name and jump_units (column grants from the init migration).
