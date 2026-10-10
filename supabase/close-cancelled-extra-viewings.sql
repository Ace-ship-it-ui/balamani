-- Close exceptional appointments when their booking is released.
begin;
create or replace function balamani_private.close_released_extra_viewing()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin
 if old.status in ('Pending','Confirmed') and new.status in ('Cancelled','Declined') then
  update public.balamani_viewing_slots s set closed=true
  where s.id=new.slot_id
   and not (
    extract(isodow from s.day) between 1 and 5
    and not balamani_private.malta_public_holiday(s.day)
    and ((s.starts>=time '09:00' and s.ends<=time '12:00')
      or (s.starts>=time '14:00' and s.ends<=time '17:00'))
   )
   and not exists(select 1 from public.balamani_viewing_requests r
    where r.slot_id=s.id and r.status in ('Pending','Confirmed'));
 end if;
 return new;
end;
$$;
revoke all on function balamani_private.close_released_extra_viewing() from public,anon,authenticated;
create or replace trigger balamani_close_released_extra_viewing
after update of status on public.balamani_viewing_requests
for each row execute function balamani_private.close_released_extra_viewing();
-- Repair exceptional slots already released before this fix.
update public.balamani_viewing_slots s set closed=true
where not s.closed
 and not (extract(isodow from s.day) between 1 and 5
  and not balamani_private.malta_public_holiday(s.day)
  and ((s.starts>=time '09:00' and s.ends<=time '12:00')
    or (s.starts>=time '14:00' and s.ends<=time '17:00')))
 and exists(select 1 from public.balamani_viewing_requests r
  where r.slot_id=s.id and r.status in ('Cancelled','Declined'))
 and not exists(select 1 from public.balamani_viewing_requests r
  where r.slot_id=s.id and r.status in ('Pending','Confirmed'));
commit;
