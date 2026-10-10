-- Owner bookings use the existing service-only API and booking lock.
begin;
CREATE OR REPLACE FUNCTION public.balamani_viewing_change(p_actor uuid,p_action text,p_data jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $function$
declare
 actor jsonb; slot public.balamani_viewing_slots; booking public.balamani_viewing_requests;
 target uuid; d date; t time; e time; decision text; family text; booking_member uuid;
begin
 actor:=public.balamani_actor(p_actor);
 if actor is null then raise exception 'Access denied'; end if;
 perform pg_advisory_xact_lock(734282);
 if p_action='view_create' then
  if not (actor->>'owner')::boolean then raise exception 'Owner access required'; end if;
  d:=(p_data->>'day')::date; t:=(p_data->>'starts')::time; e:=(p_data->>'ends')::time;
  if d is null or t is null or e is null or not isfinite(d) or e<=t or (d+t) at time zone 'Europe/Malta'<=now() or d>(now() at time zone 'Europe/Malta')::date+730 then raise exception 'Choose a future viewing time within two years, with an end after its start'; end if;
  if exists(select 1 from public.balamani_viewing_slots where day=d and starts<e and ends>t) then raise exception 'A viewing slot already overlaps those times. Reopen the existing slot or choose another time'; end if;
  insert into public.balamani_viewing_slots(day,starts,ends) values(d,t,e) returning id into target;
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
  if jsonb_typeof(p_data->'closed') is distinct from 'boolean' then raise exception 'Choose open or closed'; end if;
  update public.balamani_viewing_slots set closed=(p_data->>'closed')::boolean where id=target;
  if not found then raise exception 'Viewing slot not found'; end if;
 elsif p_action='view_request' then
  select * into slot from public.balamani_viewing_slots where id=(p_data->>'slot_id')::uuid;
  if slot.id is null or slot.closed or (slot.day+slot.starts) at time zone 'Europe/Malta'<=now() then raise exception 'This viewing slot is unavailable'; end if;
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
$function$;
-- Preserve service-only access; browsers use the authenticated Edge Function.
revoke all on function public.balamani_viewing_change(uuid,text,jsonb) from public,anon,authenticated;
grant execute on function public.balamani_viewing_change(uuid,text,jsonb) to service_role;
commit;
