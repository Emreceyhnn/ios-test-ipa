-- 1. Profiles Table
create table if not exists public.profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    email text,
    currency text default 'TRY',
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.profiles enable row level security;
create policy "Users can view own profile" on public.profiles for select using (auth.uid() = id);
create policy "Users can update own profile" on public.profiles for update using (auth.uid() = id);
create policy "Users can insert own profile" on public.profiles for insert with check (auth.uid() = id);

-- 2. Categories Table
create table if not exists public.categories (
    id uuid primary key default gen_random_uuid(),
    user_id uuid references auth.users(id) on delete cascade,
    name text not null,
    icon_symbol text not null default 'folder.fill',
    color_hex text not null default '#3B82F6',
    type text not null check (type in ('expense', 'income')),
    budget_limit numeric(12,2) default 0.00,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.categories enable row level security;
create policy "Users can operate on own categories" on public.categories for all using (auth.uid() = user_id);

-- 3. Transactions Table
create table if not exists public.transactions (
    id uuid primary key default gen_random_uuid(),
    user_id uuid references auth.users(id) on delete cascade not null,
    category_id uuid references public.categories(id) on delete set null,
    amount numeric(12,2) not null,
    type text not null check (type in ('expense', 'income')),
    description text not null,
    receipt_url text,
    date timestamp with time zone default timezone('utc'::text, now()) not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.transactions enable row level security;
create policy "Users can operate on own transactions" on public.transactions for all using (auth.uid() = user_id);

-- 4. Planned Payments (Subscriptions & Bills)
create table if not exists public.planned_payments (
    id uuid primary key default gen_random_uuid(),
    user_id uuid references auth.users(id) on delete cascade not null,
    title text not null,
    amount numeric(12,2) not null,
    due_date timestamp with time zone not null,
    frequency text not null default 'monthly', -- monthly, yearly, weekly
    is_paid boolean default false not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.planned_payments enable row level security;
create policy "Users can operate on own planned payments" on public.planned_payments for all using (auth.uid() = user_id);

-- 5. Savings Goals
create table if not exists public.savings_goals (
    id uuid primary key default gen_random_uuid(),
    user_id uuid references auth.users(id) on delete cascade not null,
    title text not null,
    target_amount numeric(12,2) not null,
    current_amount numeric(12,2) default 0.00 not null,
    deadline timestamp with time zone,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.savings_goals enable row level security;
create policy "Users can operate on own savings goals" on public.savings_goals for all using (auth.uid() = user_id);

-- 6. Group Splits (Split Bill)
create table if not exists public.group_splits (
    id uuid primary key default gen_random_uuid(),
    user_id uuid references auth.users(id) on delete cascade not null,
    title text not null,
    total_amount numeric(12,2) not null,
    participants_json jsonb not null default '[]'::jsonb,
    is_settled boolean default false not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.group_splits enable row level security;
create policy "Users can operate on own group splits" on public.group_splits for all using (auth.uid() = user_id);

-- 7. Health Metrics (Weight, Steps, Calories, Distance, Resting Heart Rate)
create table if not exists public.health_metrics (
    id uuid primary key default gen_random_uuid(),
    user_id uuid references auth.users(id) on delete cascade not null,
    weight numeric(6,2),
    steps integer default 0 not null,
    active_calories numeric(8,2) default 0.00 not null,
    distance_meters numeric(10,2) default 0.00 not null,
    resting_heart_rate numeric(6,2),
    date timestamp with time zone default timezone('utc'::text, now()) not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.health_metrics enable row level security;
create policy "Users can operate on own health metrics" on public.health_metrics for all using (auth.uid() = user_id);
create index if not exists idx_health_metrics_user_date on public.health_metrics (user_id, date desc);
