-- Apply after litter-viewing-windows.sql. Client contact details stay private.
begin;
create table if not exists balamani_private.client_profiles (
 member_id uuid primary key references public.balamani_members(id),
 first_name text not null check(length(trim(first_name)) between 1 and 50),
 surname text not null check(length(trim(surname)) between 1 and 50),
 contact_number text not null check(length(contact_number) between 7 and 30),
 completed_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
alter table balamani_private.client_profiles enable row level security;
revoke all on balamani_private.client_profiles from public,anon,authenticated;

CREATE OR REPLACE FUNCTION public.balamani_actor(p_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO '' AS $$
 select jsonb_build_object('id',m.id,'email',u.email,'full_name',m.full_name,'dog_name',m.dog_name,
  'first_name',coalesce(p.first_name,''),'surname',coalesce(p.surname,''),'contact_number',coalesce(p.contact_number,''),
  'profile_complete',p.member_id is not null and length(trim(coalesce(m.dog_name,''))) between 1 and 100,
  'owner',exists(select 1 from balamani_private.owners o where o.email=lower(u.email)))
 from public.balamani_members m join auth.users u on u.id=m.id
 left join balamani_private.client_profiles p on p.member_id=m.id
 where m.id=p_id and m.active and u.email_confirmed_at is not null;
$$;
revoke all on function public.balamani_actor(uuid) from public,anon,authenticated;
grant execute on function public.balamani_actor(uuid) to service_role;

CREATE OR REPLACE FUNCTION public.balamani_change(p_actor uuid, p_action text, p_data jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare actor jsonb; b public.balamani_bookings; a date; z date; target uuid; state text; names text[]; requested_count integer; first_name_value text; surname_value text; phone_value text; digits_value text;
begin
 actor:=public.balamani_actor(p_actor);
 if actor is null then raise exception 'Access denied'; end if;
 -- One transaction lock serializes calendar changes and booking decisions.
 perform pg_advisory_xact_lock(734281);
 if p_action='request' then
  if not (actor->>'owner')::boolean and not coalesce((actor->>'profile_complete')::boolean,false) then raise exception 'Complete your name, surname, puppy name and contact number before booking'; end if;
  a:=(p_data->>'arrival')::date; z:=(p_data->>'departure')::date;
  if a is null or z is null or not isfinite(a) or not isfinite(z) or a<current_date or z<a or a>current_date+730 then raise exception 'Choose valid arrival and departure dates; arrival must be within the next two years'; end if;
  if exists(select 1 from public.balamani_blocked_dates where day between a and z) then raise exception 'Your stay includes an unavailable date'; end if;
  if p_data ? 'dog_names' then
   if jsonb_typeof(p_data->'dog_names') <> 'array' then raise exception 'Enter a name for each dog'; end if;
   if exists(select 1 from jsonb_array_elements(p_data->'dog_names') x where jsonb_typeof(x)<>'string') then raise exception 'Enter a name for each dog'; end if;
   select array_agg(trim(value)) into names from jsonb_array_elements_text(p_data->'dog_names');
  else names:=array[trim(coalesce(p_data->>'dog_name',''))]; end if;
  requested_count:=coalesce(cardinality(names),0);
  if requested_count not between 1 and 4 or exists(select 1 from unnest(names) n where length(n) not between 1 and 100) then raise exception 'Choose 1 to 4 dogs and enter each name'; end if;
  if p_data ? 'dog_count' and (p_data->>'dog_count')::integer is distinct from requested_count then raise exception 'Dog count must match the names provided'; end if;
  if exists(
   select 1 from (select a as day union select arrival from public.balamani_bookings where status in ('Pending','Confirmed') and arrival between a and z) points
   where (select coalesce(sum(dog_count),0) from public.balamani_bookings where status in ('Pending','Confirmed') and arrival<=points.day and departure>=points.day)+requested_count>4
  ) then raise exception 'Not enough dog slots for these dates. Maximum 4 dogs per day, including pending requests. Choose fewer dogs or different dates'; end if;
  insert into public.balamani_bookings(member_id,dog_name,dog_names,arrival,departure)
  values(p_actor,names[1],names,a,z) returning id into target;
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
  if (actor->>'owner')::boolean and not (p_data ? 'first_name') then
   if length(trim(coalesce(p_data->>'full_name',''))) not between 1 and 100 or length(trim(coalesce(p_data->>'dog_name',''))) not between 1 and 100 then raise exception 'Enter your name and puppy name'; end if;
   update public.balamani_members set full_name=trim(p_data->>'full_name'),dog_name=trim(p_data->>'dog_name') where id=p_actor;
  else
   first_name_value:=trim(coalesce(p_data->>'first_name',''));
   surname_value:=trim(coalesce(p_data->>'surname',''));
   phone_value:=trim(coalesce(p_data->>'contact_number',''));
   digits_value:=regexp_replace(phone_value,'[^0-9]','','g');
   if length(first_name_value) not between 1 and 50 or length(surname_value) not between 1 and 50 or length(first_name_value||' '||surname_value)>100 then raise exception 'Enter your first name and surname (up to 100 characters together)'; end if;
   if length(trim(coalesce(p_data->>'dog_name',''))) not between 1 and 100 then raise exception 'Enter your puppy name (up to 100 characters)'; end if;
   if length(phone_value) not between 7 and 30 or phone_value !~ '^[+0-9 ().-]+$' or length(digits_value) not between 7 and 15 then raise exception 'Enter a valid contact number, including country code where needed'; end if;
   insert into balamani_private.client_profiles(member_id,first_name,surname,contact_number)
    values(p_actor,first_name_value,surname_value,phone_value)
    on conflict(member_id) do update set first_name=excluded.first_name,surname=excluded.surname,contact_number=excluded.contact_number,updated_at=now();
   update public.balamani_members set full_name=first_name_value||' '||surname_value,dog_name=trim(p_data->>'dog_name') where id=p_actor;
  end if;
  target:=p_actor;
 else raise exception 'Unknown action'; end if;
 insert into public.balamani_audit(actor_id,action,target_id) values(p_actor,p_action,target);
 return jsonb_build_object('ok',true,'id',target);
end;
$function$;
revoke all on function public.balamani_change(uuid,text,jsonb) from public,anon,authenticated;
grant execute on function public.balamani_change(uuid,text,jsonb) to service_role;

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
  if not (actor->>'owner')::boolean and not coalesce((actor->>'profile_complete')::boolean,false) then raise exception 'Complete your name, surname, puppy name and contact number before booking'; end if;
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


CREATE OR REPLACE FUNCTION public.balamani_viewing_state(p_actor uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO '' AS $$
declare actor jsonb; slots jsonb; requests jsonb; litters jsonb:='[]'::jsonb; client_details jsonb:='[]'::jsonb;
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
 if (actor->>'owner')::boolean then
  select coalesce(jsonb_agg(jsonb_build_object('id',m.id,'first_name',p.first_name,'surname',p.surname,'contact_number',p.contact_number)),'[]'::jsonb)
  into client_details from public.balamani_members m join balamani_private.client_profiles p on p.member_id=m.id where m.active;
 end if;
 return jsonb_build_object('slots',slots,'requests',requests,'litters',litters,'client_details',client_details);
end $$;
revoke all on function public.balamani_viewing_state(uuid) from public,anon,authenticated;
grant execute on function public.balamani_viewing_state(uuid) to service_role;


commit;
