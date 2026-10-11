-- Apply after client-account-controls.sql. Dog profiles and per-dog boarding.
begin;
alter table balamani_private.client_profiles add column if not exists dog_names text[];
CREATE OR REPLACE FUNCTION public.balamani_actor(p_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO '' AS $$
 select jsonb_build_object('id',m.id,'email',u.email,'full_name',m.full_name,'dog_name',m.dog_name,
  'dog_names',coalesce(to_jsonb(p.dog_names),jsonb_build_array(m.dog_name)),
  'first_name',coalesce(p.first_name,''),'surname',coalesce(p.surname,''),'contact_number',coalesce(p.contact_number,''),
  'profile_complete',p.member_id is not null and length(trim(coalesce(m.dog_name,''))) between 1 and 100,
  'owner',exists(select 1 from balamani_private.owners o where o.email=lower(u.email)),
  'kennel_allowed',coalesce(a.kennel_allowed,true),'viewings_allowed',coalesce(a.viewings_allowed,true),
  'booking_allowed',coalesce(a.booking_allowed,true),'access_expires_on',a.expires_on)
 from public.balamani_members m join auth.users u on u.id=m.id
 left join balamani_private.client_profiles p on p.member_id=m.id
 left join balamani_private.account_limits a on a.member_id=m.id
 where m.id=p_id and m.active and u.email_confirmed_at is not null and u.deleted_at is null
  and not coalesce(a.archived,false)
  and (a.expires_on is null or a.expires_on>=(now() at time zone 'Europe/Malta')::date);
$$;
revoke all on function public.balamani_actor(uuid) from public,anon,authenticated;
grant execute on function public.balamani_actor(uuid) to service_role;

CREATE OR REPLACE FUNCTION public.balamani_change(p_actor uuid, p_action text, p_data jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare actor jsonb; b public.balamani_bookings; a date; z date; target uuid; state text; names text[]; requested_count integer; first_name_value text; surname_value text; phone_value text; digits_value text; profile_names text[];
begin
 actor:=public.balamani_actor(p_actor);
 if actor is null then raise exception 'Access denied'; end if;
 -- One transaction lock serializes calendar changes and booking decisions.
 perform pg_advisory_xact_lock(734281);
 actor:=public.balamani_actor(p_actor);
 if actor is null then raise exception 'Access denied'; end if;
 if p_action='request' then
  if not (actor->>'owner')::boolean and (not (actor->>'kennel_allowed')::boolean or not (actor->>'booking_allowed')::boolean) then raise exception 'Your account is restricted from new kennel bookings. Contact Balamani'; end if;
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
  if (select count(distinct lower(n)) from unnest(names) n)<>requested_count then raise exception 'Select each dog only once, using different names'; end if;
  if not (actor->>'owner')::boolean and exists(select 1 from unnest(names) n where not exists(select 1 from jsonb_array_elements_text(actor->'dog_names') saved where lower(saved)=lower(n))) then raise exception 'Choose dogs from your saved details'; end if;
  if exists(select 1 from public.balamani_bookings existing_booking,unnest(existing_booking.dog_names) booked,unnest(names) requested where existing_booking.member_id=p_actor and existing_booking.status in ('Pending','Confirmed') and existing_booking.arrival<=z and existing_booking.departure>=a and lower(booked)=lower(requested)) then raise exception 'One of these dogs already has a pending or confirmed stay on these dates'; end if;
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
  if p_data ? 'dog_names' then
   if jsonb_typeof(p_data->'dog_names')<>'array' then raise exception 'Enter your dog names'; end if;
   if exists(select 1 from jsonb_array_elements(p_data->'dog_names') x where jsonb_typeof(x)<>'string') then raise exception 'Enter your dog names'; end if;
   select array_agg(trim(value)) into profile_names from jsonb_array_elements_text(p_data->'dog_names');
  else
   select array[trim(coalesce(p_data->>'dog_name',''))]||coalesce(p.dog_names[2:cardinality(p.dog_names)],array[]::text[]) into profile_names from (select 1) seed left join balamani_private.client_profiles p on p.member_id=p_actor;
  end if;
  if coalesce(cardinality(profile_names),0) not between 1 and 20 or exists(select 1 from unnest(profile_names) n where length(n) not between 1 and 100) then raise exception 'Enter 1 to 20 dog names (up to 100 characters each)'; end if;
  if (select count(distinct lower(n)) from unnest(profile_names) n)<>cardinality(profile_names) then raise exception 'Use a different name for each dog'; end if;
  p_data:=p_data||jsonb_build_object('dog_name',profile_names[1]);
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
   insert into balamani_private.client_profiles(member_id,first_name,surname,contact_number,dog_names)
    values(p_actor,first_name_value,surname_value,phone_value,profile_names)
    on conflict(member_id) do update set first_name=excluded.first_name,surname=excluded.surname,contact_number=excluded.contact_number,dog_names=excluded.dog_names,updated_at=now();
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



commit;

