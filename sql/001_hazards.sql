-- Run in the Supabase SQL Editor. Safe to re-run for this schema.
begin;
-- Enable Authentication > Providers > Anonymous sign-ins in the dashboard.
-- The mobile app uses the PUBLISHABLE key, never the service_role key.

create table if not exists public.hazards (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null default auth.uid() references auth.users(id),
  category text not null check (
    category in ('pothole', 'roadworks', 'blockedLane', 'intersection')
  ),
  severity text not null check (severity in ('low', 'moderate', 'high')),
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  description text not null default '' check (length(description) <= 300),
  status text not null default 'active' check (status in ('active', 'resolved')),
  confirmations_count integer not null default 0 check (confirmations_count >= 0),
  created_at timestamptz not null default now()
);

create index if not exists hazards_created_at_idx on public.hazards(created_at desc);
create index if not exists hazards_status_idx on public.hazards(status);

create table if not exists public.hazard_confirmations (
  hazard_id uuid not null references public.hazards(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (hazard_id, user_id)
);

alter table public.hazards enable row level security;
alter table public.hazard_confirmations enable row level security;

-- Signed-in anonymous users also receive the 'authenticated' database role.
drop policy if exists "hazards_read_authenticated" on public.hazards;
create policy "hazards_read_authenticated"
  on public.hazards for select to authenticated using (true);

drop policy if exists "hazards_insert_as_self" on public.hazards;
create policy "hazards_insert_as_self"
  on public.hazards for insert to authenticated
  with check (reporter_id = (select auth.uid())
    and status = 'active' and confirmations_count = 0);

-- Explicit least-privilege grants: timestamps, IDs, owner and counts are server-owned.
revoke all on public.hazards from anon, authenticated;
revoke insert (id, reporter_id, category, severity, latitude, longitude,
  description, status, confirmations_count, created_at)
  on public.hazards from anon, authenticated;
revoke update (id, reporter_id, category, severity, latitude, longitude,
  description, status, confirmations_count, created_at)
  on public.hazards from anon, authenticated;
grant select on public.hazards to authenticated;
grant insert (category, severity, latitude, longitude, description)
  on public.hazards to authenticated;
grant update (status) on public.hazards to authenticated;
revoke all on public.hazard_confirmations from anon, authenticated;

drop policy if exists "hazards_update_owned" on public.hazards;
create policy "hazards_update_owned"
  on public.hazards for update to authenticated
  using (reporter_id = (select auth.uid()))
  with check (reporter_id = (select auth.uid()) and status = 'resolved');

-- No direct table access is provided to hazard_confirmations.
-- A controlled SQL function below performs a confirmation once per user.
create or replace function public.confirm_hazard(p_hazard_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  inserted_count integer;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required';
  end if;

  -- Serialize confirmations and resolution on the same hazard row.
  perform 1 from public.hazards
    where id = p_hazard_id and status = 'active' for update;
  if not found then
    raise exception 'Hazard does not exist or has been resolved';
  end if;

  insert into public.hazard_confirmations (hazard_id, user_id)
    values (p_hazard_id, (select auth.uid()))
    on conflict do nothing;
  get diagnostics inserted_count = row_count;

  if inserted_count > 0 then
    update public.hazards
      set confirmations_count = confirmations_count + 1
      where id = p_hazard_id;
  end if;
end;
$$;

revoke all on function public.confirm_hazard(uuid) from public;
grant execute on function public.confirm_hazard(uuid) to authenticated;

-- Enable events once; rerunning this script does not add duplicate members.
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
    and not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public' and tablename = 'hazards'
    ) then
    alter publication supabase_realtime add table public.hazards;
  end if;
end;
$$;

commit;
