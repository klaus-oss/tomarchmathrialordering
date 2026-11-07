alter table members add column if not exists pin_version int not null default 0;
create or replace function login_email(p_member_id text) returns text
language sql security definer stable set search_path = public as $$
select lower(member_id) || case when pin_version = 0 then '' else '.' || pin_version::text end || '@members.archmat.app'
from members where lower(member_id) = lower(p_member_id)
$$;
create or replace function reset_member_pin(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
if not is_admin() then raise exception 'Admins only'; end if;
update members set user_id = null, pin_version = pin_version + 1 where id = p_id;
end $$;
grant execute on function login_email(text) to anon, authenticated;
grant execute on function reset_member_pin(uuid) to authenticated;
