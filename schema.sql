-- ARCH-MAT schema for Supabase. Run once in: Dashboard > SQL Editor.
-- Also in Dashboard > Authentication > Providers > Email: turn OFF "Confirm email".

create extension if not exists pgcrypto;

create table members (
  id uuid primary key default gen_random_uuid(),
  member_id text not null,
  name text not null,
  phone text not null,
  is_admin boolean not null default false,
  user_id uuid unique references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
create unique index members_member_id_ci on members (lower(member_id));

create table materials (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text not null,
  unit text not null default 'Unit',
  colors text[] not null default '{}',
  types text[] not null default '{}',
  lengths text[] not null default '{}'
);

create sequence order_seq start 9022;
create table orders (
  id uuid primary key default gen_random_uuid(),
  code text not null unique default ('ORD-' || nextval('order_seq')),
  member_id uuid not null references members(id),
  status text not null default 'Pending Verification'
    check (status in ('Pending Verification','Verified & Procuring','Ready for Pickup','Completed','Cancelled / Flagged')),
  created_at timestamptz not null default now()
);
create table order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references orders(id) on delete cascade,
  name text not null,
  qty int not null check (qty between 1 and 9999),
  color text, type text, length text, notes text
);

-- helpers
create function is_admin() returns boolean language sql security definer stable set search_path = public as
$$ select exists (select 1 from members where user_id = auth.uid() and is_admin) $$;
create function my_member_id() returns uuid language sql security definer stable set search_path = public as
$$ select id from members where user_id = auth.uid() $$;

-- activation (member picks a PIN the first time; must match the admin-registered phone)
create function can_activate(p_member_id text, p_phone text) returns boolean
language sql security definer stable set search_path = public as
$$ select exists (select 1 from members
   where lower(member_id) = lower(p_member_id) and user_id is null
     and regexp_replace(phone, '\D', '', 'g') = regexp_replace(p_phone, '\D', '', 'g')) $$;
create function claim_member(p_member_id text, p_phone text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Not signed in'; end if;
  update members set user_id = auth.uid()
   where lower(member_id) = lower(p_member_id) and user_id is null
     and regexp_replace(phone, '\D', '', 'g') = regexp_replace(p_phone, '\D', '', 'g');
  if not found then raise exception 'No matching member'; end if;
end $$;
grant execute on function can_activate(text, text) to anon, authenticated;
grant execute on function claim_member(text, text) to authenticated;

-- atomic order creation
create function submit_order(p_items jsonb) returns text
language plpgsql security definer set search_path = public as $$
declare m uuid := my_member_id(); o orders;
begin
  if m is null then raise exception 'Not a member'; end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) not between 1 and 100 then
    raise exception 'Invalid items';
  end if;
  if exists (select 1 from jsonb_array_elements(p_items) i
             where not exists (select 1 from materials mt where mt.name = i->>'name')) then
    raise exception 'Unknown material';
  end if;
  insert into orders (member_id) values (m) returning * into o;
  insert into order_items (order_id, name, qty, color, type, length, notes)
  select o.id, i->>'name', greatest(1, least(9999, (i->>'qty')::int)),
         i->>'color', i->>'type', i->>'length', i->>'notes'
  from jsonb_array_elements(p_items) i;
  return o.code;
end $$;
grant execute on function submit_order(jsonb) to authenticated;

-- row level security
alter table members enable row level security;
alter table materials enable row level security;
alter table orders enable row level security;
alter table order_items enable row level security;

create policy members_read   on members for select to authenticated using (user_id = auth.uid() or is_admin());
create policy members_insert on members for insert to authenticated with check (is_admin());
create policy members_update on members for update to authenticated using (is_admin());
create policy members_delete on members for delete to authenticated using (is_admin());

create policy materials_read  on materials for select to authenticated using (true);
create policy materials_write on materials for all to authenticated using (is_admin()) with check (is_admin());

create policy orders_read on orders for select to authenticated using (member_id = my_member_id() or is_admin());
create policy orders_admin_update on orders for update to authenticated using (is_admin());
create policy orders_cancel_own on orders for update to authenticated
  using (member_id = my_member_id() and status = 'Pending Verification')
  with check (member_id = my_member_id() and status = 'Cancelled / Flagged');
revoke update on orders from authenticated;
grant update (status) on orders to authenticated;

create policy items_read on order_items for select to authenticated
  using (exists (select 1 from orders o where o.id = order_id));

alter publication supabase_realtime add table orders;
