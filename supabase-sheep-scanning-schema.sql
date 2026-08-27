create extension if not exists pgcrypto;

create table if not exists public.customers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  mobile text,
  email text,
  created_at timestamptz not null default now()
);

create table if not exists public.properties (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.customers(id) on delete cascade,
  name text not null,
  locality text,
  address text,
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists public.jobs (
  id uuid primary key default gen_random_uuid(),
  job_number text unique,
  customer_id uuid not null references public.customers(id) on delete restrict,
  property_id uuid not null references public.properties(id) on delete restrict,
  status text not null default 'enquiry' check (status in ('enquiry','tentative','confirmed','completed','cancelled')),
  ram_in_date date,
  ram_out_date date,
  scan_offset_days integer not null default 80 check (scan_offset_days between 1 and 365),
  ideal_scan_date date generated always as (
    case when ram_out_date is null then null else ram_out_date + scan_offset_days end
  ) stored,
  booked_date date,
  booked_start_time time,
  estimated_head_count integer check (estimated_head_count >= 0),
  rate_per_head numeric(10,2) check (rate_per_head >= 0),
  booking_notes text,
  completed_at timestamptz,
  report_sent_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.mob_results (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs(id) on delete cascade,
  mob_name text,
  breed text,
  total_scanned integer not null default 0 check (total_scanned >= 0),
  empty_count integer not null default 0 check (empty_count >= 0),
  singles_count integer not null default 0 check (singles_count >= 0),
  twins_count integer not null default 0 check (twins_count >= 0),
  triplets_plus_count integer not null default 0 check (triplets_plus_count >= 0),
  scan_notes text,
  created_at timestamptz not null default now(),
  check (empty_count + singles_count + twins_count + triplets_plus_count <= total_scanned)
);

create index if not exists jobs_booked_date_idx on public.jobs(booked_date);
create index if not exists jobs_ideal_scan_date_idx on public.jobs(ideal_scan_date);
create index if not exists properties_customer_id_idx on public.properties(customer_id);
create index if not exists mob_results_job_id_idx on public.mob_results(job_id);

alter table public.customers enable row level security;
alter table public.properties enable row level security;
alter table public.jobs enable row level security;
alter table public.mob_results enable row level security;

create policy "temporary owner access customers" on public.customers for all to authenticated using (true) with check (true);
create policy "temporary owner access properties" on public.properties for all to authenticated using (true) with check (true);
create policy "temporary owner access jobs" on public.jobs for all to authenticated using (true) with check (true);
create policy "temporary owner access mob results" on public.mob_results for all to authenticated using (true) with check (true);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists jobs_set_updated_at on public.jobs;
create trigger jobs_set_updated_at
before update on public.jobs
for each row execute function public.set_updated_at();
