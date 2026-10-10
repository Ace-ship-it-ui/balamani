-- Application data is accessible only through the authenticated Edge Function.
begin;
create schema if not exists balamani_private;
revoke all on schema balamani_private from public, anon, authenticated;
create table if not exists balamani_private.owners (email text primary key check(email=lower(email)));
alter table balamani_private.owners enable row level security;
create table if not exists public.balamani_members (
 id uuid primary key references auth.users(id), email text not null unique,
 full_name text not null default '', dog_name text not null default '',
 active boolean not null default true, created_at timestamptz not null default now()
);
create table if not exists public.balamani_bookings (
 id uuid primary key default gen_random_uuid(), member_id uuid not null references public.balamani_members(id),
 dog_name text not null check(length(dog_name) between 1 and 100),
 arrival date not null, departure date not null check(departure>=arrival and departure<=arrival+90),
 status text not null default 'Pending' check(status in ('Pending','Confirmed','Declined','Cancelled')),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.balamani_blocked_dates (day date primary key);
create table if not exists public.balamani_audit (
 id bigint generated always as identity primary key, actor_id uuid,
 action text not null, target_id uuid, created_at timestamptz not null default now()
);
create index if not exists balamani_bookings_member on public.balamani_bookings(member_id,created_at);
create unique index if not exists balamani_booking_no_duplicate on public.balamani_bookings(member_id,arrival,departure) where status in ('Pending','Confirmed');
alter table public.balamani_members enable row level security;
alter table public.balamani_bookings enable row level security;
alter table public.balamani_blocked_dates enable row level security;
alter table public.balamani_audit enable row level security;
revoke all on public.balamani_members,public.balamani_bookings,public.balamani_blocked_dates,public.balamani_audit from anon,authenticated;
grant all on public.balamani_members,public.balamani_bookings,public.balamani_blocked_dates,public.balamani_audit to service_role;
grant usage, select on sequence public.balamani_audit_id_seq to service_role;

create or replace function public.balamani_is_owner_email(p_email text) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from balamani_private.owners where email=lower(trim(p_email)));
$$;
create or replace function public.balamani_actor(p_id uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',m.id,'email',u.email,'full_name',m.full_name,'dog_name',m.dog_name,
 'owner',exists(select 1 from balamani_private.owners o where o.email=lower(u.email)))
 from public.balamani_members m join auth.users u on u.id=m.id
 where m.id=p_id and m.active and u.email_confirmed_at is not null;
$$;
create or replace function public.balamani_change(p_actor uuid,p_action text,p_data jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor jsonb; b public.balamani_bookings; a date; z date; target uuid; state text;
begin
 actor:=public.balamani_actor(p_actor);
 if actor is null then raise exception 'Access denied'; end if;
 -- One transaction lock serializes calendar changes and booking decisions.
 perform pg_advisory_xact_lock(734281);
 if p_action='request' then
  a:=(p_data->>'arrival')::date; z:=(p_data->>'departure')::date;
  if a is null or z is null or a<current_date or z<a or z>a+90 or a>current_date+730 then raise exception 'Choose a valid stay within the next two years, up to 90 days'; end if;
  if exists(select 1 from public.balamani_blocked_dates where day between a and z) then raise exception 'Your stay includes an unavailable date'; end if;
  if length(trim(coalesce(p_data->>'dog_name',''))) not between 1 and 100 then raise exception 'Enter your dog name'; end if;
  insert into public.balamani_bookings(member_id,dog_name,arrival,departure)
  values(p_actor,trim(p_data->>'dog_name'),a,z) returning id into target;
 elsif p_action='decision' then
  if not (actor->>'owner')::boolean then raise exception 'Owner access required'; end if;
  target:=(p_data->>'id')::uuid; state:=p_data->>'status';
  select * into b from public.balamani_bookings where id=target for update;
  if b.id is null then raise exception 'Booking not found'; end if;
  if state not in ('Confirmed','Declined','Cancelled') or state is null then raise exception 'Invalid decision'; end if;
  if (state in ('Confirmed','Declined') and b.status<>'Pending') or (state='Cancelled' and b.status not in ('Pending','Confirmed')) then raise exception 'Booking has already changed. Refresh and try again'; end if;
  if state='Confirmed' and exists(select 1 from public.balamani_blocked_dates where day between b.arrival and b.departure) then raise exception 'Reopen blocked dates before confirming this stay'; end if;
  update public.balamani_bookings set status=state,updated_at=now() where id=target;
 elsif p_action='cancel' then
  target:=(p_data->>'id')::uuid;
  update public.balamani_bookings set status='Cancelled',updated_at=now() where id=target and member_id=p_actor and status='Pending';
  if not found then raise exception 'Only your pending requests can be withdrawn'; end if;
 elsif p_action='block' then
  if not (actor->>'owner')::boolean then raise exception 'Owner access required'; end if;
  a:=(p_data->>'day')::date;
  if a is null or a<current_date or a>current_date+730 then raise exception 'Choose a future date within two years'; end if;
  if (p_data->>'blocked')::boolean then insert into public.balamani_blocked_dates values(a) on conflict do nothing;
  else delete from public.balamani_blocked_dates where day=a; end if;
 elsif p_action='profile' then
  if length(trim(coalesce(p_data->>'full_name',''))) not between 1 and 100 or length(trim(coalesce(p_data->>'dog_name',''))) not between 1 and 100 then raise exception 'Enter your name and dog name (up to 100 characters each)'; end if;
  update public.balamani_members set full_name=trim(p_data->>'full_name'),dog_name=trim(p_data->>'dog_name') where id=p_actor;
 else raise exception 'Unknown action'; end if;
 insert into public.balamani_audit(actor_id,action,target_id) values(p_actor,p_action,target);
 return jsonb_build_object('ok',true,'id',target);
end;
$$;
revoke all on function public.balamani_is_owner_email(text),public.balamani_actor(uuid),public.balamani_change(uuid,text,jsonb) from public,anon,authenticated;
grant execute on function public.balamani_is_owner_email(text),public.balamani_actor(uuid),public.balamani_change(uuid,text,jsonb) to service_role;
commit;
