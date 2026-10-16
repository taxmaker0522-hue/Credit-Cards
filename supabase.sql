-- JAPP Technosoft staff portal: run this once in Supabase > SQL Editor.

create table if not exists public.profiles (
  id    uuid primary key references auth.users on delete cascade,
  email text,
  role  text not null default 'staff' check (role in ('staff', 'admin'))
);

create table if not exists public.gateways (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  url        text not null,
  logo_url   text,
  color      text default '#1f5eff',
  sort       int  default 0,
  created_at timestamptz default now()
);

alter table public.profiles enable row level security;
alter table public.gateways enable row level security;

create or replace function public.is_admin()
returns boolean language sql security definer set search_path = public stable as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'admin');
$$;

-- every new Supabase user automatically gets a 'staff' profile
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, email) values (new.id, new.email) on conflict do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- profiles: a user reads their own row, admins read all
drop policy if exists "profiles read" on public.profiles;
create policy "profiles read" on public.profiles for select to authenticated
  using (id = auth.uid() or public.is_admin());

-- gateways: any logged-in staff can read; only admins can change
drop policy if exists "gateways read" on public.gateways;
create policy "gateways read" on public.gateways for select to authenticated using (true);
drop policy if exists "gateways admin insert" on public.gateways;
create policy "gateways admin insert" on public.gateways for insert to authenticated with check (public.is_admin());
drop policy if exists "gateways admin update" on public.gateways;
create policy "gateways admin update" on public.gateways for update to authenticated using (public.is_admin());
drop policy if exists "gateways admin delete" on public.gateways;
create policy "gateways admin delete" on public.gateways for delete to authenticated using (public.is_admin());

-- starter gateways (replace the links with the real login pages, or edit them in the site's admin panel)
insert into public.gateways (name, url, sort) values
  ('PaySwitch', 'https://payswitch.example.com/login', 1),
  ('GreenPay',  'https://greenpay.example.com/login', 2);

-- AFTER creating your own user (Authentication > Users > Add user), make it the admin:
-- update public.profiles set role = 'admin' where email = 'your-email@example.com';
