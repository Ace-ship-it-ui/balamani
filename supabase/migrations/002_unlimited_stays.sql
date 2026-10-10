begin;
alter table public.balamani_bookings drop constraint if exists balamani_bookings_departure_check;
alter table public.balamani_bookings add constraint balamani_bookings_departure_check check(departure>=arrival);
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
  if a is null or z is null or a<current_date or z<a or a>current_date+730 then raise exception 'Choose valid arrival and departure dates; arrival must be within the next two years'; end if;
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
commit;
