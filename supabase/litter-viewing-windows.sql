-- Apply after automatic-viewing-slots.sql, admin-viewing-bookings.sql,
-- and close-cancelled-extra-viewings.sql. Birth + 14 through birth + 55 inclusive.
begin;
create table if not exists balamani_private.viewing_litters (
 id uuid primary key default gen_random_uuid(),
 label text not null check(length(trim(label)) between 1 and 100),
 born_on date not null check(isfinite(born_on)),
 active boolean not null default true,
 created_by uuid not null references public.balamani_members(id),
 created_at timestamptz not null default now()
);
alter table balamani_private.viewing_litters enable row level security;
revoke all on balamani_private.viewing_litters from public,anon,authenticated;
create index if not exists balamani_active_litter_birth on balamani_private.viewing_litters(born_on) where active;
do $$ begin
 if not exists(select 1 from information_schema.columns where table_schema='public'
  and table_name='balamani_viewing_slots' and column_name='availability_override') then
  alter table public.balamani_viewing_slots add column availability_override text
   check(availability_override in ('open','closed'));
  -- Preserve deliberate closures once, before switching to the litter schedule.
  update public.balamani_viewing_slots set availability_override='closed' where closed;
 end if;
end $$;
alter table public.balamani_viewing_slots alter column closed set default true;

create or replace function balamani_private.litter_viewing_day(d date) returns boolean
language sql stable security invoker set search_path='' as $$
 select exists(select 1 from balamani_private.viewing_litters l
  where l.active and d>=l.born_on+14 and d<l.born_on+56);
$$;
create or replace function balamani_private.regular_litter_slot(d date,t time,e time) returns boolean
language sql stable security invoker set search_path='' as $$
 select extract(isodow from d) between 1 and 5
  and not balamani_private.malta_public_holiday(d)
  and ((t>=time '09:00' and e<=time '12:00') or (t>=time '14:00' and e<=time '17:00'))
  and balamani_private.litter_viewing_day(d);
$$;
create or replace function balamani_private.viewing_slot_closed(d date,t time,e time,override_value text) returns boolean
language sql stable security invoker set search_path='' as $$
 select case override_value when 'open' then false when 'closed' then true
  else not balamani_private.regular_litter_slot(d,t,e) end;
$$;
revoke all on function balamani_private.litter_viewing_day(date) from public,anon,authenticated;
revoke all on function balamani_private.regular_litter_slot(date,time,time) from public,anon,authenticated;
revoke all on function balamani_private.viewing_slot_closed(date,time,time,text) from public,anon,authenticated;

create or replace function balamani_private.fill_viewing_slots() returns integer
language plpgsql security invoker set search_path='' as $$
declare added integer; today date:=(now() at time zone 'Europe/Malta')::date;
begin
 perform pg_advisory_xact_lock(734282);
 insert into public.balamani_viewing_slots(day,starts,ends,closed)
 select today+offset_day,start_time,start_time+interval '1 hour',true
 from generate_series(0,89) offset_day
 cross join unnest(array[time '09:00',time '10:00',time '11:00',time '14:00',time '15:00',time '16:00']) start_time
 where extract(isodow from today+offset_day) between 1 and 5
  and not balamani_private.malta_public_holiday(today+offset_day)
  and ((today+offset_day)+start_time) at time zone 'Europe/Malta'>now()
  and not exists(select 1 from public.balamani_viewing_slots s where s.day=today+offset_day
   and s.starts<start_time+interval '1 hour' and s.ends>start_time);
 get diagnostics added=row_count;
 update public.balamani_viewing_slots s
 set closed=balamani_private.viewing_slot_closed(s.day,s.starts,s.ends,s.availability_override)
 where s.closed is distinct from balamani_private.viewing_slot_closed(s.day,s.starts,s.ends,s.availability_override);
 return added;
end $$;
revoke all on function balamani_private.fill_viewing_slots() from public,anon,authenticated;

create or replace function balamani_private.close_released_extra_viewing()
returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if old.status in ('Pending','Confirmed') and new.status in ('Cancelled','Declined') then
  update public.balamani_viewing_slots s set closed=true,availability_override='closed'
  where s.id=new.slot_id and not balamani_private.regular_litter_slot(s.day,s.starts,s.ends)
   and not exists(select 1 from public.balamani_viewing_requests r where r.slot_id=s.id and r.status in ('Pending','Confirmed'));
 end if;
 return new;
end $$;
revoke all on function balamani_private.close_released_extra_viewing() from public,anon,authenticated;

CREATE OR REPLACE FUNCTION public.balamani_viewing_state(p_actor uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO '' AS $$
declare actor jsonb; slots jsonb; requests jsonb; litters jsonb:='[]'::jsonb;
begin
 actor:=public.balamani_actor(p_actor);
 if actor is null then raise exception 'Access denied'; end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',s.id,'day',s.day,'starts',s.starts,'ends',s.ends,
  'closed',balamani_private.viewing_slot_closed(s.day,s.starts,s.ends,s.availability_override),
  'override',case when (actor->>'owner')::boolean then s.availability_override else null end,
  'status',(select r.status from public.balamani_viewing_requests r where r.slot_id=s.id and r.status in ('Pending','Confirmed')),
  'past',(s.day+s.starts) at time zone 'Europe/Malta'<=now()) order by s.day,s.starts),'[]'::jsonb)
 into slots from public.balamani_viewing_slots s where s.day>=(now() at time zone 'Europe/Malta')::date-365;
 select coalesce(jsonb_agg(x.item order by x.created_at desc),'[]'::jsonb) into requests from (
  select r.created_at,jsonb_build_object('id',r.id,'slot_id',r.slot_id,'member_id',r.member_id,'family_name',r.family_name,
   'status',r.status,'day',s.day,'starts',s.starts,'ends',s.ends,'past',(s.day+s.starts) at time zone 'Europe/Malta'<=now()) as item
  from public.balamani_viewing_requests r join public.balamani_viewing_slots s on s.id=r.slot_id
  where (actor->>'owner')::boolean or r.member_id=p_actor order by r.created_at desc limit 500
 ) x;
 if (actor->>'owner')::boolean then
  select coalesce(jsonb_agg(jsonb_build_object('id',l.id,'label',l.label,'born_on',l.born_on,'active',l.active,
   'opens_on',l.born_on+14,'last_day',l.born_on+55) order by l.born_on desc,l.created_at desc),'[]'::jsonb)
  into litters from balamani_private.viewing_litters l;
 end if;
 return jsonb_build_object('slots',slots,'requests',requests,'litters',litters);
end $$;
revoke all on function public.balamani_viewing_state(uuid) from public,anon,authenticated;
grant execute on function public.balamani_viewing_state(uuid) to service_role;

CREATE OR REPLACE FUNCTION public.balamani_viewing_change(p_actor uuid,p_action text,p_data jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $function$
declare
 actor jsonb; slot public.balamani_viewing_slots; booking public.balamani_viewing_requests;
 target uuid; d date; t time; e time; decision text; family text; booking_member uuid; litter_name text; litter_operation text;
begin
 actor:=public.balamani_actor(p_actor);
 if actor is null then raise exception 'Access denied'; end if;
 perform pg_advisory_xact_lock(734282);
 -- Litter settings travel through the existing owner-only viewing creation endpoint.
 if p_action='view_create' and p_data ? 'litter_operation' then
  if not (actor->>'owner')::boolean then raise exception 'Owner access required'; end if;
  litter_operation:=p_data->>'litter_operation';
  if litter_operation='save' then
   d:=(p_data->>'born_on')::date;
   litter_name:=trim(coalesce(p_data->>'label',''));
   if d is null or not isfinite(d) or d>(now() at time zone 'Europe/Malta')::date then raise exception 'Enter the litter birth date, today or earlier'; end if;
   if length(litter_name) not between 1 and 100 then raise exception 'Enter a litter name'; end if;
   if nullif(p_data->>'litter_id','') is null then
    insert into balamani_private.viewing_litters(label,born_on,created_by) values(litter_name,d,p_actor) returning id into target;
   else
    target:=(p_data->>'litter_id')::uuid;
    update balamani_private.viewing_litters set label=litter_name,born_on=d where id=target;
    if not found then raise exception 'Litter not found'; end if;
   end if;
  elsif litter_operation='set_active' then
   if jsonb_typeof(p_data->'active') is distinct from 'boolean' then raise exception 'Choose active or paused'; end if;
   target:=(p_data->>'litter_id')::uuid;
   update balamani_private.viewing_litters set active=(p_data->>'active')::boolean where id=target;
   if not found then raise exception 'Litter not found'; end if;
  else raise exception 'Unknown litter operation'; end if;
  perform balamani_private.fill_viewing_slots();
  insert into public.balamani_audit(actor_id,action,target_id) values(p_actor,'litter_'||litter_operation,target);
  return jsonb_build_object('ok',true,'id',target);
 end if;
 if p_action='view_create' then
  if not (actor->>'owner')::boolean then raise exception 'Owner access required'; end if;
  d:=(p_data->>'day')::date; t:=(p_data->>'starts')::time; e:=(p_data->>'ends')::time;
  if d is null or t is null or e is null or not isfinite(d) or e<=t or (d+t) at time zone 'Europe/Malta'<=now() or d>(now() at time zone 'Europe/Malta')::date+730 then raise exception 'Choose a future viewing time within two years, with an end after its start'; end if;
  if exists(select 1 from public.balamani_viewing_slots where day=d and starts<e and ends>t) then raise exception 'A viewing slot already overlaps those times. Reopen the existing slot or choose another time'; end if;
  insert into public.balamani_viewing_slots(day,starts,ends,closed,availability_override) values(d,t,e,false,'open') returning id into target;
  if nullif(p_data->>'member_id','') is not null then
   booking_member:=(p_data->>'member_id')::uuid;
   if public.balamani_actor(booking_member) is null then raise exception 'Choose an active invited family'; end if;
   family:=trim(coalesce(p_data->>'family_name',''));
   if length(family) not between 1 and 100 then raise exception 'Enter the family name'; end if;
   insert into public.balamani_viewing_requests(slot_id,member_id,family_name,status) values(target,booking_member,family,'Confirmed');
  end if;
 elsif p_action='view_close' then
  if not (actor->>'owner')::boolean then raise exception 'Owner access required'; end if;
  target:=(p_data->>'id')::uuid;
  if p_data->>'mode'='automatic' then
   update public.balamani_viewing_slots s set availability_override=null,
    closed=balamani_private.viewing_slot_closed(s.day,s.starts,s.ends,null) where id=target;
  else
   if jsonb_typeof(p_data->'closed') is distinct from 'boolean' then raise exception 'Choose open or closed'; end if;
   update public.balamani_viewing_slots set closed=(p_data->>'closed')::boolean,
    availability_override=case when (p_data->>'closed')::boolean then 'closed' else 'open' end where id=target;
  end if;
  if not found then raise exception 'Viewing slot not found'; end if;
 elsif p_action='view_request' then
  select * into slot from public.balamani_viewing_slots where id=(p_data->>'slot_id')::uuid;
  if slot.id is null or balamani_private.viewing_slot_closed(slot.day,slot.starts,slot.ends,slot.availability_override) or (slot.day+slot.starts) at time zone 'Europe/Malta'<=now() then raise exception 'This viewing slot is unavailable'; end if;
  if exists(select 1 from public.balamani_viewing_requests where slot_id=slot.id and status in ('Pending','Confirmed')) then raise exception 'This viewing slot has just been taken. Please choose another'; end if;
  family:=trim(coalesce(p_data->>'family_name',''));
  if length(family) not between 1 and 100 then raise exception 'Enter your name for the viewing'; end if;
  booking_member:=p_actor; decision:='Pending';
  if nullif(p_data->>'member_id','') is not null then
   if not (actor->>'owner')::boolean then raise exception 'Owner access required'; end if;
   booking_member:=(p_data->>'member_id')::uuid;
   if public.balamani_actor(booking_member) is null then raise exception 'Choose an active invited family'; end if;
   decision:='Confirmed';
  end if;
  insert into public.balamani_viewing_requests(slot_id,member_id,family_name,status) values(slot.id,booking_member,family,decision) returning id into target;
 elsif p_action='view_decision' then
  if not (actor->>'owner')::boolean then raise exception 'Owner access required'; end if;
  target:=(p_data->>'id')::uuid; decision:=p_data->>'status';
  select * into booking from public.balamani_viewing_requests where id=target for update;
  if booking.id is null then raise exception 'Viewing request not found'; end if;
  if decision is null or decision not in ('Confirmed','Declined','Cancelled') then raise exception 'Invalid decision'; end if;
  if (decision in ('Confirmed','Declined') and booking.status<>'Pending') or (decision='Cancelled' and booking.status not in ('Pending','Confirmed')) then raise exception 'This viewing has already changed. Refresh and try again'; end if;
  if decision='Confirmed' then
   select * into slot from public.balamani_viewing_slots where id=booking.slot_id;
   if balamani_private.viewing_slot_closed(slot.day,slot.starts,slot.ends,slot.availability_override) or (slot.day+slot.starts) at time zone 'Europe/Malta'<=now() then raise exception 'Reopen the slot before approving, and check that the viewing has not passed'; end if;
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
$function$;
-- Preserve service-only access; browsers use the authenticated Edge Function.
revoke all on function public.balamani_viewing_change(uuid,text,jsonb) from public,anon,authenticated;
grant execute on function public.balamani_viewing_change(uuid,text,jsonb) to service_role;

select balamani_private.fill_viewing_slots() as created_slots;
commit;
