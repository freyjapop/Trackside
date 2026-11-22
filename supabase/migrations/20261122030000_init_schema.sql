-- Trackside: initial schema
-- Every rider's data is private to them (row level security on user_id = auth.uid()).
-- Library content is readable by signed-in riders; Premium articles only by Premium riders.

-- ---------- helpers ----------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ---------- profiles ----------
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text,
  jump_units text not null default 'cm' check (jump_units in ('cm', 'ft')),
  is_premium boolean not null default false,
  premium_until date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
comment on table public.profiles is 'One row per rider, created automatically at sign-up.';
comment on column public.profiles.is_premium is 'Set by the service role (admin or billing webhook), never by the rider.';

create trigger profiles_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();

-- Create a profile whenever someone signs up.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'display_name', split_part(new.email, '@', 1)));
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- True when the current rider has an active Premium plan.
create or replace function public.is_premium()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select p.is_premium and (p.premium_until is null or p.premium_until >= current_date)
       from public.profiles p where p.id = (select auth.uid())),
    false);
$$;

-- ---------- horses ----------
create table public.horses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name text not null check (char_length(name) between 1 and 80),
  breed text,
  coat_colour text,
  height_hh numeric(3, 1) check (height_hh between 6 and 20),
  age smallint check (age between 0 and 50),
  sex text check (sex in ('Mare', 'Gelding', 'Stallion')),
  ownership text not null default 'School horse'
    check (ownership in ('School horse', 'Own', 'Loan', 'Lease', 'Friend''s horse')),
  yard text,
  notes text,
  archived boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index horses_user_id_idx on public.horses (user_id);
create trigger horses_updated_at before update on public.horses
  for each row execute function public.set_updated_at();

create table public.horse_care_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  horse_id uuid not null references public.horses (id) on delete cascade,
  care_type text not null
    check (care_type in ('Farrier', 'Vaccination', 'Worming / egg count', 'Dentist', 'Saddle fit check', 'Vet visit')),
  done_on date,
  next_due date,
  notes text,
  created_at timestamptz not null default now()
);
create index horse_care_events_user_id_idx on public.horse_care_events (user_id);
create index horse_care_events_horse_id_idx on public.horse_care_events (horse_id);

-- ---------- journal entries ----------
create table public.entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  ride_date date not null default current_date,
  session_type text not null default 'Private lesson'
    check (session_type in ('Private lesson', 'Group lesson', 'Schooling', 'Hack', 'Clinic', 'Competition')),
  duration_min smallint check (duration_min between 0 and 600),
  instructor text,
  location text,
  disciplines text[] not null default '{}',
  exercises text[] not null default '{}',
  max_fence_cm smallint check (max_fence_cm between 0 and 250),
  ride_rating smallint check (ride_rating between 1 and 5),
  confidence smallint check (confidence between 1 and 5),
  went_well text,
  was_hard text,
  instructor_said text,
  status text not null default 'complete' check (status in ('quick', 'complete')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index entries_user_date_idx on public.entries (user_id, ride_date desc);
create trigger entries_updated_at before update on public.entries
  for each row execute function public.set_updated_at();

create table public.entry_horses (
  entry_id uuid not null references public.entries (id) on delete cascade,
  horse_id uuid not null references public.horses (id) on delete cascade,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  primary key (entry_id, horse_id)
);
create index entry_horses_horse_id_idx on public.entry_horses (horse_id);
create index entry_horses_user_id_idx on public.entry_horses (user_id);

create table public.focus_points (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  entry_id uuid not null references public.entries (id) on delete cascade,
  body text not null check (char_length(body) between 1 and 300),
  status text not null default 'open' check (status in ('open', 'worked', 'improved', 'problem')),
  position smallint not null default 0,
  resolved_in_entry_id uuid references public.entries (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index focus_points_user_status_idx on public.focus_points (user_id, status);
create index focus_points_entry_id_idx on public.focus_points (entry_id);
create index focus_points_resolved_in_idx on public.focus_points (resolved_in_entry_id);
create trigger focus_points_updated_at before update on public.focus_points
  for each row execute function public.set_updated_at();

-- ---------- scores ----------
create table public.dressage_results (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  entry_id uuid not null unique references public.entries (id) on delete cascade,
  event text,
  test_name text,
  level text,
  judge text,
  percentage numeric(5, 2) check (percentage between 0 and 100),
  placement smallint check (placement >= 1),
  is_practice boolean not null default false,
  judge_comments text,
  created_at timestamptz not null default now()
);
create index dressage_results_user_id_idx on public.dressage_results (user_id);

create table public.dressage_marks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  result_id uuid not null references public.dressage_results (id) on delete cascade,
  position smallint not null default 0,
  movement text,
  mark numeric(3, 1) check (mark between 0 and 10),
  coefficient smallint not null default 1 check (coefficient between 1 and 3),
  comment text
);
create index dressage_marks_result_id_idx on public.dressage_marks (result_id);
create index dressage_marks_user_id_idx on public.dressage_marks (user_id);

create table public.jumping_results (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  entry_id uuid not null unique references public.entries (id) on delete cascade,
  event text,
  class_name text,
  height_cm smallint check (height_cm between 0 and 250),
  jump_faults smallint not null default 0 check (jump_faults >= 0),
  time_faults smallint not null default 0 check (time_faults >= 0),
  time_seconds numeric(6, 2) check (time_seconds >= 0),
  placement smallint check (placement >= 1),
  is_practice boolean not null default false,
  fault_causes text[] not null default '{}',
  is_clear boolean generated always as (jump_faults = 0 and time_faults = 0) stored,
  created_at timestamptz not null default now()
);
create index jumping_results_user_id_idx on public.jumping_results (user_id);

-- ---------- progress ----------
create table public.goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  body text not null check (char_length(body) between 1 and 200),
  discipline text,
  target_date date,
  achieved boolean not null default false,
  created_at timestamptz not null default now()
);
create index goals_user_id_idx on public.goals (user_id);

create table public.skill_progress (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  skill_id text not null,
  status smallint not null default 0 check (status between 0 and 3), -- 0 not started, 1 learning, 2 confident, 3 mastered
  updated_at timestamptz not null default now(),
  primary key (user_id, skill_id)
);
create trigger skill_progress_updated_at before update on public.skill_progress
  for each row execute function public.set_updated_at();

-- ---------- library ----------
create table public.library_articles (
  id text primary key,
  section text not null check (section in ('breeds', 'colours', 'terms', 'tack', 'care', 'tips')),
  title text not null,
  meta text,
  body text not null,
  is_free boolean not null default false,
  sort_order smallint not null default 0,
  last_reviewed date,
  created_at timestamptz not null default now()
);
create index library_articles_section_idx on public.library_articles (section, sort_order);

create table public.bookmarks (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  article_id text not null references public.library_articles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, article_id)
);
create index bookmarks_article_id_idx on public.bookmarks (article_id);

-- ---------- row level security ----------
alter table public.profiles enable row level security;
alter table public.horses enable row level security;
alter table public.horse_care_events enable row level security;
alter table public.entries enable row level security;
alter table public.entry_horses enable row level security;
alter table public.focus_points enable row level security;
alter table public.dressage_results enable row level security;
alter table public.dressage_marks enable row level security;
alter table public.jumping_results enable row level security;
alter table public.goals enable row level security;
alter table public.skill_progress enable row level security;
alter table public.library_articles enable row level security;
alter table public.bookmarks enable row level security;

-- Profiles: riders read and edit their own; Premium fields are not editable by riders.
create policy "Riders read own profile" on public.profiles
  for select to authenticated using (id = (select auth.uid()));
create policy "Riders update own profile" on public.profiles
  for update to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));
revoke update on public.profiles from authenticated, anon;
grant update (display_name, jump_units) on public.profiles to authenticated;

-- Rider-owned tables: full access to own rows only.
do $$
declare t text;
begin
  foreach t in array array['horses', 'horse_care_events', 'entries', 'entry_horses', 'focus_points',
                           'dressage_results', 'dressage_marks', 'jumping_results', 'goals',
                           'skill_progress', 'bookmarks']
  loop
    execute format('create policy "Riders read own rows" on public.%I for select to authenticated using (user_id = (select auth.uid()))', t);
    execute format('create policy "Riders add own rows" on public.%I for insert to authenticated with check (user_id = (select auth.uid()))', t);
    execute format('create policy "Riders update own rows" on public.%I for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()))', t);
    execute format('create policy "Riders delete own rows" on public.%I for delete to authenticated using (user_id = (select auth.uid()))', t);
  end loop;
end;
$$;

-- Library: free articles for every signed-in rider, the rest for Premium riders.
create policy "Free or Premium articles" on public.library_articles
  for select to authenticated using (is_free or (select public.is_premium()));

-- Every signed-in rider can list article titles (for the locked previews), without the article text.
create or replace function public.library_index()
returns table (id text, section text, title text, meta text, is_free boolean, sort_order smallint)
language sql
stable
security definer
set search_path = ''
as $$
  select a.id, a.section, a.title, a.meta, a.is_free, a.sort_order
  from public.library_articles a
  order by a.section, a.sort_order;
$$;

-- Function permissions: only signed-in riders may call the API functions.
revoke execute on function public.library_index() from public, anon;
grant execute on function public.library_index() to authenticated;
revoke execute on function public.is_premium() from public, anon;
grant execute on function public.is_premium() to authenticated;
revoke execute on function public.handle_new_user() from public, anon, authenticated;
