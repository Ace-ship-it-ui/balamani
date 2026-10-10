begin;
alter table public.balamani_bookings drop constraint if exists balamani_bookings_check;
commit;
