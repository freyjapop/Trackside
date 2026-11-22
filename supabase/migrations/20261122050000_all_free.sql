-- Trackside: Premium is paused, so every library article is free for signed-in riders.
-- The Premium columns, is_premium() and the Stripe edge functions stay in place for later.
update public.library_articles set is_free = true;
alter table public.library_articles alter column is_free set default true;
