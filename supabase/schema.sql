-- Run this in Supabase: Dashboard -> SQL Editor -> New query -> Run.
-- Safe to re-run: every statement is written to be idempotent.
--
-- IMPORTANT: this version adds authentication. Rows are now owned by the
-- user who created them, and the old "anyone can do anything" demo
-- policies are replaced. See the cleanup note near the bottom about rows
-- created before auth existed.

-- ---------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------

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
  -- bundled image, or "file:<path>" for a photo the user actually took
  -- (copied into permanent local storage on save).
  image_ref text
);

create table if not exists notifications (
  id uuid primary key default gen_random_uuid(),
  product_id uuid references products (id) on delete cascade,
  title text not null,
  body text not null,
  icon text not null default 'devices_other',
  unread boolean not null default true,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- Columns added after the first version (safe on existing tables)
-- ---------------------------------------------------------------------

alter table products add column if not exists image_ref text;

-- Owner of the row. Nullable so this migration doesn't fail on rows
-- created before auth existed, but the policies below only ever match
-- rows where it equals the logged-in user.
alter table products
  add column if not exists user_id uuid references auth.users (id) on delete cascade;
alter table notifications
  add column if not exists user_id uuid references auth.users (id) on delete cascade;

-- Fields that come out of the Gemini recognition step.
alter table products add column if not exists item_type text not null default 'game';
alter table products add column if not exists platform text not null default '';
alter table products add column if not exists region text not null default '';
alter table products add column if not exists edition text not null default '';
alter table products add column if not exists completeness text not null default '';
-- The search string used against eBay, kept so the price screen can
-- re-run the same search later without guessing it again.
alter table products add column if not exists ebay_query text not null default '';
-- Where price_min/price_max came from: 'eBay', 'MercadoLibre', or
-- 'IA (estimado)' when neither marketplace answered and Gemini's own
-- estimate was used instead.
alter table products add column if not exists price_source text not null default '';

create index if not exists products_user_id_idx on products (user_id);
create index if not exists notifications_user_id_idx on notifications (user_id);

-- ---------------------------------------------------------------------
-- Row level security: each user only sees their own rows
-- ---------------------------------------------------------------------

alter table products enable row level security;
alter table notifications enable row level security;

-- Drop the old open demo policies (no-ops if they were never created).
drop policy if exists "Demo: anyone can read products" on products;
drop policy if exists "Demo: anyone can insert products" on products;
drop policy if exists "Demo: anyone can update products" on products;
drop policy if exists "Demo: anyone can delete products" on products;
drop policy if exists "Demo: anyone can read notifications" on notifications;
drop policy if exists "Demo: anyone can insert notifications" on notifications;
drop policy if exists "Demo: anyone can update notifications" on notifications;

drop policy if exists "Users read own products" on products;
drop policy if exists "Users insert own products" on products;
drop policy if exists "Users update own products" on products;
drop policy if exists "Users delete own products" on products;
drop policy if exists "Users read own notifications" on notifications;
drop policy if exists "Users insert own notifications" on notifications;
drop policy if exists "Users update own notifications" on notifications;
drop policy if exists "Users delete own notifications" on notifications;

create policy "Users read own products" on products
  for select using (auth.uid() = user_id);

create policy "Users insert own products" on products
  for insert with check (auth.uid() = user_id);

create policy "Users update own products" on products
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "Users delete own products" on products
  for delete using (auth.uid() = user_id);

create policy "Users read own notifications" on notifications
  for select using (auth.uid() = user_id);

create policy "Users insert own notifications" on notifications
  for insert with check (auth.uid() = user_id);

create policy "Users update own notifications" on notifications
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "Users delete own notifications" on notifications
  for delete using (auth.uid() = user_id);

-- ---------------------------------------------------------------------
-- Cleanup for pre-auth rows
-- ---------------------------------------------------------------------
-- Rows created before auth have user_id = null, so the policies above
-- make them invisible to everyone - they're dead weight. They were only
-- ever test data, so deleting them is usually what you want. This is
-- left commented out on purpose: uncomment and run it yourself.
--
-- delete from notifications where user_id is null;
-- delete from products where user_id is null;
