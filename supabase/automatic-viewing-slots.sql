begin;
create extension if not exists pg_cron;
create index if not exists balamani_viewing_slots_day_time on public.balamani_viewing_slots(day,starts,ends);

-- Gregorian computus; Easter minus two days is Malta's Good Friday.
create or replace function balamani_private.malta_public_holiday(d date) returns boolean
language plpgsql immutable strict security invoker set search_path='' as $$
declare y integer:=extract(year from d)::integer; a integer; b integer; c integer;
 dd integer; e integer; f integer; g integer; h integer; i integer; k integer; l integer; m integer; n integer; easter date;
begin
 if to_char(d,'MM-DD')=any(array['01-01','02-10','03-19','03-31','05-01','06-07','06-29','08-15','09-08','09-21','12-08','12-13','12-25']) then return true; end if;
 a:=y%19; b:=y/100; c:=y%100; dd:=b/4; e:=b%4; f:=(b+8)/25; g:=(b-f+1)/3;
 h:=(19*a+b-dd-g+15)%30; i:=c/4; k:=c%4; l:=(32+2*e+2*i-h-k)%7; m:=(a+11*h+22*l)/451;
 n:=h+l-7*m+114;
 easter:=make_date(y,n/31,n%31+1);
 return d=easter-2;
end $$;
revoke all on function balamani_private.malta_public_holiday(date) from public,anon,authenticated;

create or replace function balamani_private.fill_viewing_slots() returns integer
language plpgsql security invoker set search_path='' as $$
declare added integer; today date:=(now() at time zone 'Europe/Malta')::date;
begin
 -- Same lock as manual viewing creation and booking changes.
 perform pg_advisory_xact_lock(734282);
 insert into public.balamani_viewing_slots(day,starts,ends)
 select today+offset_day, start_time, start_time+interval '1 hour'
 from generate_series(0,89) offset_day
 cross join unnest(array[time '09:00',time '10:00',time '11:00',time '14:00',time '15:00',time '16:00']) start_time
 where extract(isodow from today+offset_day) between 1 and 5
 and not balamani_private.malta_public_holiday(today+offset_day)
 and ((today+offset_day)+start_time) at time zone 'Europe/Malta'>now()
 and not exists(select 1 from public.balamani_viewing_slots s
   where s.day=today+offset_day and s.starts<start_time+interval '1 hour' and s.ends>start_time);
 get diagnostics added=row_count;
 return added;
end $$;
revoke all on function balamani_private.fill_viewing_slots() from public,anon,authenticated;
select cron.schedule('balamani-viewing-slots','5 0 * * *','select balamani_private.fill_viewing_slots();');
select balamani_private.fill_viewing_slots() as created_slots;
commit;

