-- CMR+ / Central Dashboard tables on shared BizAgent Supabase project.
-- Designed for Firebase Auth UIDs (TEXT), not Supabase auth.users UUIDs.
-- Client uses publishable/anon key without Supabase session.

-- ---------------------------------------------------------------------------
-- Enums (idempotent)
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_type where typname = 'bug_severity') then
    create type public.bug_severity as enum ('critical', 'high', 'medium', 'low');
  end if;
end $$;

do $$
begin
  if not exists (select 1 from pg_type where typname = 'bug_status') then
    create type public.bug_status as enum (
      'new', 'assigned', 'in_progress', 'testing', 'resolved', 'closed'
    );
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key default gen_random_uuid(),
  user_id text not null unique,
  full_name text not null default '',
  avatar_url text,
  job_title text default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists profiles_user_id_idx on public.profiles (user_id);

alter table public.profiles enable row level security;

drop policy if exists "cmr_profiles_select" on public.profiles;
create policy "cmr_profiles_select"
  on public.profiles for select
  to anon, authenticated
  using (true);

drop policy if exists "cmr_profiles_insert" on public.profiles;
create policy "cmr_profiles_insert"
  on public.profiles for insert
  to anon, authenticated
  with check (true);

drop policy if exists "cmr_profiles_update" on public.profiles;
create policy "cmr_profiles_update"
  on public.profiles for update
  to anon, authenticated
  using (true)
  with check (true);

-- ---------------------------------------------------------------------------
-- projects
-- ---------------------------------------------------------------------------
create table if not exists public.projects (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text default '',
  created_by text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists projects_created_at_idx
  on public.projects (created_at desc);

alter table public.projects enable row level security;

drop policy if exists "cmr_projects_select" on public.projects;
create policy "cmr_projects_select"
  on public.projects for select
  to anon, authenticated
  using (true);

drop policy if exists "cmr_projects_insert" on public.projects;
create policy "cmr_projects_insert"
  on public.projects for insert
  to anon, authenticated
  with check (true);

drop policy if exists "cmr_projects_update" on public.projects;
create policy "cmr_projects_update"
  on public.projects for update
  to anon, authenticated
  using (true)
  with check (true);

drop policy if exists "cmr_projects_delete" on public.projects;
create policy "cmr_projects_delete"
  on public.projects for delete
  to anon, authenticated
  using (true);

-- ---------------------------------------------------------------------------
-- bugs
-- ---------------------------------------------------------------------------
create table if not exists public.bugs (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text not null default '',
  steps_to_reproduce text default '',
  expected_behavior text default '',
  actual_behavior text default '',
  severity public.bug_severity not null default 'medium',
  status public.bug_status not null default 'new',
  environment text default '',
  project_id uuid references public.projects (id) on delete set null,
  reporter_id text not null default '',
  assignee_id text,
  sla_deadline timestamptz,
  tracking_id text not null default 'BUG-00000',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists bugs_created_at_idx on public.bugs (created_at desc);
create index if not exists bugs_project_id_idx on public.bugs (project_id);
create index if not exists bugs_status_idx on public.bugs (status);

alter table public.bugs enable row level security;

drop policy if exists "cmr_bugs_select" on public.bugs;
create policy "cmr_bugs_select"
  on public.bugs for select
  to anon, authenticated
  using (true);

drop policy if exists "cmr_bugs_insert" on public.bugs;
create policy "cmr_bugs_insert"
  on public.bugs for insert
  to anon, authenticated
  with check (true);

drop policy if exists "cmr_bugs_update" on public.bugs;
create policy "cmr_bugs_update"
  on public.bugs for update
  to anon, authenticated
  using (true)
  with check (true);

drop policy if exists "cmr_bugs_delete" on public.bugs;
create policy "cmr_bugs_delete"
  on public.bugs for delete
  to anon, authenticated
  using (true);

-- ---------------------------------------------------------------------------
-- Realtime (best-effort; ignore if already published)
-- ---------------------------------------------------------------------------
do $$
begin
  alter publication supabase_realtime add table public.projects;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.bugs;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;

-- ---------------------------------------------------------------------------
-- Seed one project so dashboard is not empty after first deploy
-- ---------------------------------------------------------------------------
insert into public.projects (name, description, created_by)
select
  'Central Dashboard',
  'Predvolený projekt pre CMR+ / issue tracking',
  'system'
where not exists (
  select 1 from public.projects where name = 'Central Dashboard'
);
