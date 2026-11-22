-- Trackside: table privileges for signed-in riders (row level security still limits them to their own rows).
grant select on public.profiles to authenticated;
grant select, insert, update, delete on
  public.horses, public.horse_care_events, public.entries, public.entry_horses, public.focus_points,
  public.dressage_results, public.dressage_marks, public.jumping_results, public.goals,
  public.skill_progress, public.bookmarks
to authenticated;
grant select on public.library_articles to authenticated;

-- Signed-out visitors get nothing.
revoke all on all tables in schema public from anon;

-- is_premium only reads the rider's own profile, which RLS already allows, so it can run as the caller.
alter function public.is_premium() security invoker;
