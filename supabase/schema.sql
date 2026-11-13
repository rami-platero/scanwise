-- Run this in Supabase: Dashboard -> SQL Editor -> New query -> Run.

create table if not exists products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  brand text not null,
  category text not null,
  model text not null default '',
  confidence double precision not null default 0,
  price_min double precision not null default 0,
  price_max double precision not null default 0,
  scanned_at timestamptz not null default now(),
  icon text not null default 'devices_other',
  description text not null default '',
  -- Where to find this product's picture. Either "asset:<path>" for a
  -- curated cover bundled with the app, or "file:<path>" for a photo
  -- the user actually took (copied into permanent local storage on
  -- save - see product_service.dart). Null if there's no picture at all.
  image_ref text
);

-- Running this again on a table that already exists (e.g. you ran this
-- schema before image_ref was added): this line adds the column without
-- touching anything else.
alter table products add column if not exists image_ref text;

create table if not exists notifications (
  id uuid primary key default gen_random_uuid(),
  product_id uuid references products (id) on delete cascade,
  title text not null,
  body text not null,
  icon text not null default 'devices_other',
  unread boolean not null default true,
  created_at timestamptz not null default now()
);

-- RLS: for today's demo, public read/write is enabled using the anon /
-- publishable key, since there is no login yet. This is NOT production
-- ready; once auth is added, these policies get replaced with ones that
-- filter by the row's owner.
alter table products enable row level security;
alter table notifications enable row level security;

create policy "Demo: anyone can read products" on products
  for select using (true);

create policy "Demo: anyone can insert products" on products
  for insert with check (true);

create policy "Demo: anyone can update products" on products
  for update using (true);

create policy "Demo: anyone can delete products" on products
  for delete using (true);

create policy "Demo: anyone can read notifications" on notifications
  for select using (true);

create policy "Demo: anyone can insert notifications" on notifications
  for insert with check (true);

create policy "Demo: anyone can update notifications" on notifications
  for update using (true);
