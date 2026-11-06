-- Speed Medical CRM schema
create extension if not exists pgcrypto;
create table if not exists public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 full_name text,
 role text not null default 'sales_rep' check (role in ('admin','sales_rep','viewer')),
 created_at timestamptz not null default now()
);
create table if not exists public.customers (
 id uuid primary key default gen_random_uuid(), user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 name text not null, type text, area text, address text, maps_url text, phone text,
 first_visit_date date, contact_name text, contact_title text, contact_phone text, whatsapp text,
 best_contact_time text, contacted boolean not null default false, current_supplier text,
 products_purchased text, average_purchase numeric(12,2) default 0, purchase_frequency text,
 next_purchase_date date, budget numeric(12,2) default 0, supplier_issues text, products_to_offer text,
 status text not null default 'عميل جديد', importance text default 'متوسطة', next_step text,
 next_follow_up date, notes text, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index if not exists customers_user_created_idx on public.customers(user_id,created_at desc);
create index if not exists customers_user_phone_idx on public.customers(user_id,phone);
create table if not exists public.customer_contacts (
 id uuid primary key default gen_random_uuid(), user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 customer_id uuid not null references public.customers(id) on delete cascade, name text not null, title text, phone text, whatsapp text, best_contact_time text, notes text, created_at timestamptz not null default now()
);
create table if not exists public.visits (
 id uuid primary key default gen_random_uuid(), user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 customer_id uuid not null references public.customers(id) on delete cascade, visit_date date not null default current_date, visit_time time,
 area text, met_person text, met_purchase_manager boolean default false, result text, products_discussed text,
 quote_presented boolean default false, quote_amount numeric(12,2) default 0, order_received boolean default false,
 order_amount numeric(12,2) default 0, notes text, next_visit_date date, created_at timestamptz not null default now()
);
create index if not exists visits_user_date_idx on public.visits(user_id,visit_date desc);
create table if not exists public.products (
 id uuid primary key default gen_random_uuid(), user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 name text not null, sku text, unit text, unit_price numeric(12,2) default 0, active boolean default true, created_at timestamptz not null default now()
);
create table if not exists public.sales (
 id uuid primary key default gen_random_uuid(), user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 customer_id uuid not null references public.customers(id) on delete restrict, sale_date date not null default current_date,
 total_amount numeric(12,2) not null default 0 check(total_amount>=0), status text not null default 'pending' check(status in ('completed','pending','cancelled')),
 invoice_number text, notes text, created_at timestamptz not null default now()
);
create index if not exists sales_user_date_idx on public.sales(user_id,sale_date desc);
create table if not exists public.sale_items (
 id uuid primary key default gen_random_uuid(), user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 sale_id uuid not null references public.sales(id) on delete cascade, product_id uuid references public.products(id) on delete set null,
 product_name text not null, quantity numeric(12,2) not null default 1, unit_price numeric(12,2) not null default 0, line_total numeric(12,2) generated always as (quantity*unit_price) stored
);
create table if not exists public.follow_ups (
 id uuid primary key default gen_random_uuid(), user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 customer_id uuid not null references public.customers(id) on delete cascade, due_date date not null, next_step text,
 completed boolean not null default false, completed_at timestamptz, notes text, created_at timestamptz not null default now()
);
create index if not exists followups_user_due_idx on public.follow_ups(user_id,due_date);
create table if not exists public.work_schedule (
 id uuid primary key default gen_random_uuid(), user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 weekday smallint not null check(weekday between 0 and 6), areas text[] not null default '{}', start_time time default '16:00', end_time time default '21:00', is_off boolean default false, unique(user_id,weekday)
);
create table if not exists public.monthly_targets (
 id uuid primary key default gen_random_uuid(), user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 month date not null, target_amount numeric(12,2) not null default 40000 check(target_amount>0), unique(user_id,month)
);
create table if not exists public.share_links (
 id uuid primary key default gen_random_uuid(), created_by uuid not null references auth.users(id) on delete cascade,
 token_hash text not null unique, data_type text not null check(data_type in ('customers','visits','sales','monthly_report')),
 filters jsonb not null default '{}', expires_at timestamptz, require_auth boolean not null default false,
 revoked_at timestamptz, created_at timestamptz not null default now(), last_used_at timestamptz
);
create table if not exists public.share_link_permissions (
 id uuid primary key default gen_random_uuid(), share_link_id uuid not null references public.share_links(id) on delete cascade,
 resource_type text not null, record_ids uuid[] default null, allowed_fields text[] not null default '{}',
 can_view boolean not null default true, can_edit boolean not null default false, can_delete boolean not null default false,
 unique(share_link_id,resource_type)
);
create table if not exists public.activity_logs (
 id bigint generated always as identity primary key, user_id uuid not null references auth.users(id) on delete cascade,
 action text not null, entity_type text, entity_id uuid, metadata jsonb default '{}', created_at timestamptz not null default now()
);
create or replace function public.set_updated_at() returns trigger language plpgsql as $$ begin new.updated_at=now(); return new; end $$;
drop trigger if exists customers_updated_at on public.customers;
create trigger customers_updated_at before update on public.customers for each row execute function public.set_updated_at();

-- Enable RLS on every tenant-owned table. Share links are accessed only by Edge Functions (service role).
alter table public.profiles enable row level security;
alter table public.customers enable row level security;
alter table public.customer_contacts enable row level security;
alter table public.visits enable row level security;
alter table public.products enable row level security;
alter table public.sales enable row level security;
alter table public.sale_items enable row level security;
alter table public.follow_ups enable row level security;
alter table public.work_schedule enable row level security;
alter table public.monthly_targets enable row level security;
alter table public.share_links enable row level security;
alter table public.share_link_permissions enable row level security;
alter table public.activity_logs enable row level security;

create policy "profile own read" on public.profiles for select using(id=auth.uid());
create policy "profile own update" on public.profiles for update using(id=auth.uid()) with check(id=auth.uid());
-- User ownership policies
do $$ declare t text; begin
 foreach t in array array['customers','customer_contacts','visits','products','sales','sale_items','follow_ups','work_schedule','monthly_targets','activity_logs'] loop
  execute format('drop policy if exists tenant_select on public.%I',t);
  execute format('create policy tenant_select on public.%I for select using(user_id=auth.uid())',t);
  execute format('drop policy if exists tenant_insert on public.%I',t);
  execute format('create policy tenant_insert on public.%I for insert with check(user_id=auth.uid())',t);
  execute format('drop policy if exists tenant_update on public.%I',t);
  execute format('create policy tenant_update on public.%I for update using(user_id=auth.uid()) with check(user_id=auth.uid())',t);
  execute format('drop policy if exists tenant_delete on public.%I',t);
  execute format('create policy tenant_delete on public.%I for delete using(user_id=auth.uid())',t);
 end loop;
end $$;
-- Share tables deliberately have no client policies. Only trusted Edge Functions using service role may access them.
