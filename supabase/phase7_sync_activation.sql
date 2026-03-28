-- Phase 7 - EPOS Supabase Sync Activation
-- Local Drift/SQLite remains the source of truth.
-- Supabase stores finalized transaction snapshots only.
-- OPEN transactions are rejected at the remote contract level.

begin;

create table if not exists public.transactions (
  uuid uuid primary key,
  shift_local_id integer null,
  user_local_id integer null,
  table_number integer null,
  status text not null check (status in ('paid', 'cancelled')),
  subtotal_minor integer not null check (subtotal_minor >= 0),
  modifier_total_minor integer not null check (modifier_total_minor >= 0),
  total_amount_minor integer not null check (total_amount_minor >= 0),
  created_at timestamptz not null,
  paid_at timestamptz null,
  updated_at timestamptz not null,
  cancelled_at timestamptz null,
  cancelled_by_local_id integer null,
  kitchen_printed boolean not null default false,
  receipt_printed boolean not null default false,
  synced_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.transaction_lines (
  uuid uuid primary key,
  transaction_uuid uuid not null references public.transactions (uuid) on delete restrict,
  product_local_id integer null,
  product_name text not null,
  unit_price_minor integer not null check (unit_price_minor >= 0),
  quantity integer not null check (quantity > 0),
  line_total_minor integer not null check (line_total_minor >= 0)
);

create table if not exists public.order_modifiers (
  uuid uuid primary key,
  transaction_line_uuid uuid not null references public.transaction_lines (uuid) on delete restrict,
  action text not null check (action in ('remove', 'add')),
  item_name text not null,
  extra_price_minor integer not null default 0 check (extra_price_minor >= 0)
);

create table if not exists public.payments (
  uuid uuid primary key,
  transaction_uuid uuid not null unique references public.transactions (uuid) on delete restrict,
  method text not null check (method in ('cash', 'card')),
  amount_minor integer not null check (amount_minor > 0),
  paid_at timestamptz not null
);

create index if not exists idx_transactions_updated_at
  on public.transactions (updated_at desc);

create index if not exists idx_transactions_synced_at
  on public.transactions (synced_at desc);

create index if not exists idx_transaction_lines_transaction_uuid
  on public.transaction_lines (transaction_uuid);

create index if not exists idx_order_modifiers_transaction_line_uuid
  on public.order_modifiers (transaction_line_uuid);

create index if not exists idx_payments_transaction_uuid
  on public.payments (transaction_uuid);

create or replace function public.apply_transaction_sync_guardrails()
returns trigger
language plpgsql
as $$
begin
  if new.status not in ('paid', 'cancelled') then
    raise exception 'OPEN transactions are not accepted by the sync target.';
  end if;

  if tg_op = 'UPDATE' then
    if old.updated_at > new.updated_at then
      return old;
    end if;

    if old.updated_at = new.updated_at then
      new.kitchen_printed := coalesce(old.kitchen_printed, false) or coalesce(new.kitchen_printed, false);
      new.receipt_printed := coalesce(old.receipt_printed, false) or coalesce(new.receipt_printed, false);
    end if;
  end if;

  new.synced_at := timezone('utc', now());
  return new;
end;
$$;

create or replace function public.sync_transaction_exists(target_uuid uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.transactions
    where uuid = target_uuid
  );
$$;

create or replace function public.sync_paid_transaction_exists(target_uuid uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.transactions
    where uuid = target_uuid
      and status = 'paid'
  );
$$;

create or replace function public.sync_transaction_line_exists(target_uuid uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.transaction_lines
    where uuid = target_uuid
  );
$$;

drop trigger if exists trg_transactions_sync_guardrails on public.transactions;
create trigger trg_transactions_sync_guardrails
before insert or update on public.transactions
for each row
execute function public.apply_transaction_sync_guardrails();

alter table public.transactions enable row level security;
alter table public.transaction_lines enable row level security;
alter table public.order_modifiers enable row level security;
alter table public.payments enable row level security;

revoke all on public.transactions from anon, authenticated;
revoke all on public.transaction_lines from anon, authenticated;
revoke all on public.order_modifiers from anon, authenticated;
revoke all on public.payments from anon, authenticated;

grant usage on schema public to anon, authenticated;
grant insert, update on public.transactions to anon, authenticated;
grant insert, update on public.transaction_lines to anon, authenticated;
grant insert, update on public.order_modifiers to anon, authenticated;
grant insert, update on public.payments to anon, authenticated;

drop policy if exists "transactions_insert_sync" on public.transactions;
create policy "transactions_insert_sync"
on public.transactions
for insert
to anon, authenticated
with check (status in ('paid', 'cancelled'));

drop policy if exists "transactions_update_sync" on public.transactions;
create policy "transactions_update_sync"
on public.transactions
for update
to anon, authenticated
using (true)
with check (status in ('paid', 'cancelled'));

drop policy if exists "transaction_lines_insert_sync" on public.transaction_lines;
create policy "transaction_lines_insert_sync"
on public.transaction_lines
for insert
to anon, authenticated
with check (public.sync_transaction_exists(transaction_uuid));

drop policy if exists "transaction_lines_update_sync" on public.transaction_lines;
create policy "transaction_lines_update_sync"
on public.transaction_lines
for update
to anon, authenticated
using (true)
with check (public.sync_transaction_exists(transaction_uuid));

drop policy if exists "order_modifiers_insert_sync" on public.order_modifiers;
create policy "order_modifiers_insert_sync"
on public.order_modifiers
for insert
to anon, authenticated
with check (public.sync_transaction_line_exists(transaction_line_uuid));

drop policy if exists "order_modifiers_update_sync" on public.order_modifiers;
create policy "order_modifiers_update_sync"
on public.order_modifiers
for update
to anon, authenticated
using (true)
with check (public.sync_transaction_line_exists(transaction_line_uuid));

drop policy if exists "payments_insert_sync" on public.payments;
create policy "payments_insert_sync"
on public.payments
for insert
to anon, authenticated
with check (public.sync_paid_transaction_exists(transaction_uuid));

drop policy if exists "payments_update_sync" on public.payments;
create policy "payments_update_sync"
on public.payments
for update
to anon, authenticated
using (true)
with check (public.sync_paid_transaction_exists(transaction_uuid));

commit;
