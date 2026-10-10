-- Durable single-use invitation tickets. Raw credentials are never stored.
begin;
create table if not exists balamani_private.invitations (
 token_hash text primary key check(token_hash ~ '^[0-9a-f]{64}$'),
 member_id uuid not null references public.balamani_members(id),
 created_at timestamptz not null default now(),
 consumed_at timestamptz, revoked_at timestamptz
);
alter table balamani_private.invitations enable row level security;
revoke all on balamani_private.invitations from public,anon,authenticated;
create index if not exists balamani_invitations_member on balamani_private.invitations(member_id);
create or replace function public.balamani_invitation_issue(p_member uuid,p_hash text) returns void
language plpgsql security definer set search_path='' as $$
begin
 perform 1 from public.balamani_members where id=p_member and active for update;
 if not found then raise exception 'Account unavailable'; end if;
 update balamani_private.invitations set revoked_at=now()
 where member_id=p_member and consumed_at is null and revoked_at is null;
 insert into balamani_private.invitations(token_hash,member_id) values(p_hash,p_member);
end $$;
create or replace function public.balamani_invitation_consume(p_hash text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare target uuid; result jsonb;
begin
 -- Atomic update prevents simultaneous redemption and replay.
 update balamani_private.invitations i set consumed_at=now()
 where i.token_hash=p_hash and i.consumed_at is null and i.revoked_at is null
 and exists(select 1 from public.balamani_members m join auth.users u on u.id=m.id
 where m.id=i.member_id and m.active and lower(u.email)=m.email)
 returning i.member_id into target;
 if target is null then return null; end if;
 select jsonb_build_object('id',m.id,'email',m.email) into result
 from public.balamani_members m where m.id=target;
 return result;
end $$;
revoke all on function public.balamani_invitation_issue(uuid,text),public.balamani_invitation_consume(text) from public,anon,authenticated;
grant execute on function public.balamani_invitation_issue(uuid,text),public.balamani_invitation_consume(text) to service_role;
commit;
