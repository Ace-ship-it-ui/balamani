begin;
select pg_advisory_xact_lock(734281);
alter table public.balamani_bookings add column dog_names text[];
update public.balamani_bookings set dog_names=array[dog_name];
alter table public.balamani_bookings alter column dog_names set not null;
alter table public.balamani_bookings add column dog_count integer generated always as (cardinality(dog_names)) stored;
alter table public.balamani_bookings add constraint booking_dog_count check(dog_count between 1 and 4);
create or replace function public.balamani_change(p_actor uuid,p_action text,p_data jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor jsonb; b public.balamani_bookings; a date; z date; target uuid; state text; names text[]; requested_count integer;
begin
 actor:=public.balamani_actor(p_actor);
 if actor is null then raise exception 'Access denied'; end if;
 -- One transaction lock serializes calendar changes and booking decisions.
 perform pg_advisory_xact_lock(734281);
 if p_action='request' then
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
  if length(trim(coalesce(p_data->>'full_name',''))) not between 1 and 100 or length(trim(coalesce(p_data->>'dog_name',''))) not between 1 and 100 then raise exception 'Enter your name and dog name (up to 100 characters each)'; end if;
  update public.balamani_members set full_name=trim(p_data->>'full_name'),dog_name=trim(p_data->>'dog_name') where id=p_actor;
 else raise exception 'Unknown action'; end if;
 insert into public.balamani_audit(actor_id,action,target_id) values(p_actor,p_action,target);
 return jsonb_build_object('ok',true,'id',target);
end;
$$;

create or replace function public.balamani_occupancy() returns jsonb
language sql stable security definer set search_path='' as $$
 with events as (
 select arrival as day, case when status='Confirmed' then dog_count else 0 end as c, case when status='Pending' then dog_count else 0 end as p from public.balamani_bookings where status in ('Pending','Confirmed')
 union all
 select departure+1, case when status='Confirmed' then -dog_count else 0 end, case when status='Pending' then -dog_count else 0 end from public.balamani_bookings where status in ('Pending','Confirmed')
 ), totals as (select day,sum(c) c,sum(p) p from events group by day), spans as (
 select day as start,lead(day) over(order by day)-1 as finish,sum(c) over(order by day) as confirmed,sum(p) over(order by day) as pending from totals
 ) select coalesce(jsonb_agg(jsonb_build_object('start',start,'finish',finish,'confirmed',confirmed,'pending',pending) order by start),'[]'::jsonb) from spans where finish is not null and confirmed+pending>0;
$$;
revoke all on function public.balamani_occupancy() from public,anon,authenticated;
grant execute on function public.balamani_occupancy() to service_role;
commit;
