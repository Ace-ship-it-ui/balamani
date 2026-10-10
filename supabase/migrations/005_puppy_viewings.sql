begin;
create table public.balamani_viewing_slots (
 id uuid primary key default gen_random_uuid(), day date not null,
 starts time not null, ends time not null check(ends>starts), closed boolean not null default false,
 created_at timestamptz not null default now()
);
create table public.balamani_viewing_requests (
 id uuid primary key default gen_random_uuid(), slot_id uuid not null references public.balamani_viewing_slots(id),
 member_id uuid not null references public.balamani_members(id),
 family_name text not null check(length(trim(family_name)) between 1 and 100),
 status text not null default 'Pending' check(status in ('Pending','Confirmed','Declined','Cancelled')),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create unique index balamani_one_family_per_viewing on public.balamani_viewing_requests(slot_id) where status in ('Pending','Confirmed');
alter table public.balamani_viewing_slots enable row level security;
alter table public.balamani_viewing_requests enable row level security;
revoke all on public.balamani_viewing_slots,public.balamani_viewing_requests from anon,authenticated;
grant all on public.balamani_viewing_slots,public.balamani_viewing_requests to service_role;

create or replace function public.balamani_viewing_state(p_actor uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor jsonb; slots jsonb; requests jsonb;
begin
 actor:=public.balamani_actor(p_actor);
 if actor is null then raise exception 'Access denied'; end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',s.id,'day',s.day,'starts',s.starts,'ends',s.ends,'closed',s.closed,
 'status',(select r.status from public.balamani_viewing_requests r where r.slot_id=s.id and r.status in ('Pending','Confirmed')),
 'past',(s.day+s.starts) at time zone 'Europe/Malta'<=now()) order by s.day,s.starts),'[]'::jsonb) into slots
 from public.balamani_viewing_slots s where s.day >= (now() at time zone 'Europe/Malta')::date-365;
 select coalesce(jsonb_agg(x.item order by x.created_at desc),'[]'::jsonb) into requests from (
 select r.created_at,jsonb_build_object('id',r.id,'slot_id',r.slot_id,'member_id',r.member_id,'family_name',r.family_name,
 'status',r.status,'day',s.day,'starts',s.starts,'ends',s.ends,
 'past',(s.day+s.starts) at time zone 'Europe/Malta'<=now()) as item
 from public.balamani_viewing_requests r join public.balamani_viewing_slots s on s.id=r.slot_id
 where (actor->>'owner')::boolean or r.member_id=p_actor order by r.created_at desc limit 500
 ) x;
 return jsonb_build_object('slots',slots,'requests',requests);
end;
$$;

create or replace function public.balamani_viewing_change(p_actor uuid,p_action text,p_data jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor jsonb; slot public.balamani_viewing_slots; booking public.balamani_viewing_requests;
 target uuid; d date; t time; e time; decision text; family text;
begin
 actor:=public.balamani_actor(p_actor);
 if actor is null then raise exception 'Access denied'; end if;
 -- Independent from the kennel lock and capacity rules.
 perform pg_advisory_xact_lock(734282);
 if p_action='view_create' then
  if not (actor->>'owner')::boolean then raise exception 'Owner access required'; end if;
  d:=(p_data->>'day')::date; t:=(p_data->>'starts')::time; e:=(p_data->>'ends')::time;
  if d is null or t is null or e is null or not isfinite(d) or e<=t or (d+t) at time zone 'Europe/Malta'<=now() or d>(now() at time zone 'Europe/Malta')::date+730 then raise exception 'Choose a future viewing time within two years, with an end after its start'; end if;
  if exists(select 1 from public.balamani_viewing_slots where day=d and starts<e and ends>t) then raise exception 'A viewing slot already overlaps those times. Reopen the existing slot or choose another time'; end if;
  insert into public.balamani_viewing_slots(day,starts,ends) values(d,t,e) returning id into target;
 elsif p_action='view_close' then
  if not (actor->>'owner')::boolean then raise exception 'Owner access required'; end if;
  target:=(p_data->>'id')::uuid;
  if jsonb_typeof(p_data->'closed') is distinct from 'boolean' then raise exception 'Choose open or closed'; end if;
  update public.balamani_viewing_slots set closed=(p_data->>'closed')::boolean where id=target;
  if not found then raise exception 'Viewing slot not found'; end if;
 elsif p_action='view_request' then
  select * into slot from public.balamani_viewing_slots where id=(p_data->>'slot_id')::uuid;
  if slot.id is null or slot.closed or (slot.day+slot.starts) at time zone 'Europe/Malta'<=now() then raise exception 'This viewing slot is unavailable'; end if;
  if exists(select 1 from public.balamani_viewing_requests where slot_id=slot.id and status in ('Pending','Confirmed')) then raise exception 'This viewing slot has just been taken. Please choose another'; end if;
  family:=trim(coalesce(p_data->>'family_name',''));
  if length(family) not between 1 and 100 then raise exception 'Enter your name for the viewing'; end if;
  insert into public.balamani_viewing_requests(slot_id,member_id,family_name) values(slot.id,p_actor,family) returning id into target;
 elsif p_action='view_decision' then
  if not (actor->>'owner')::boolean then raise exception 'Owner access required'; end if;
  target:=(p_data->>'id')::uuid; decision:=p_data->>'status';
  select * into booking from public.balamani_viewing_requests where id=target for update;
  if booking.id is null then raise exception 'Viewing request not found'; end if;
  if decision is null or decision not in ('Confirmed','Declined','Cancelled') then raise exception 'Invalid decision'; end if;
  if (decision in ('Confirmed','Declined') and booking.status<>'Pending') or (decision='Cancelled' and booking.status not in ('Pending','Confirmed')) then raise exception 'This viewing has already changed. Refresh and try again'; end if;
  if decision='Confirmed' then
   select * into slot from public.balamani_viewing_slots where id=booking.slot_id;
   if slot.closed or (slot.day+slot.starts) at time zone 'Europe/Malta'<=now() then raise exception 'Reopen the slot before approving, and check that the viewing has not passed'; end if;
  end if;
  update public.balamani_viewing_requests set status=decision,updated_at=now() where id=target;
 elsif p_action='view_cancel' then
  target:=(p_data->>'id')::uuid;
  update public.balamani_viewing_requests set status='Cancelled',updated_at=now() where id=target and member_id=p_actor and status='Pending';
  if not found then raise exception 'Only your pending viewing requests can be withdrawn'; end if;
 else raise exception 'Unknown viewing action'; end if;
 insert into public.balamani_audit(actor_id,action,target_id) values(p_actor,p_action,target);
 return jsonb_build_object('ok',true,'id',target);
end;
$$;
revoke all on function public.balamani_viewing_state(uuid),public.balamani_viewing_change(uuid,text,jsonb) from public,anon,authenticated;
grant execute on function public.balamani_viewing_state(uuid),public.balamani_viewing_change(uuid,text,jsonb) to service_role;
commit;
