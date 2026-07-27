-- Verification cache
--
-- Stores completed verdicts so a pack that has already been verified is not
-- re-verified by the full ten-agent pipeline. Run once in the Supabase SQL
-- editor, after supabase_migration_v2.sql.
--
-- See backend/utils/verification_cache.py for the read/write path.

create table if not exists public.verification_cache (
    cache_key            text primary key,
    medicine_name        text,
    registration_number  text,
    verdict              jsonb       not null,
    overall_verdict      text,
    confidence_score     numeric(4, 3),
    cached_at            timestamptz not null default now(),
    expires_at           timestamptz not null,
    hit_count            integer     not null default 0,
    last_hit_at          timestamptz
);

-- Lookups are always by primary key, but expiry sweeps and recall
-- invalidation scan these columns.
create index if not exists verification_cache_expires_idx
    on public.verification_cache (expires_at);

create index if not exists verification_cache_medicine_idx
    on public.verification_cache using gin (medicine_name gin_trgm_ops);

-- The cache holds no personal data: only pack identity and the verdict for
-- that pack. It is written exclusively by the backend service role, and never
-- read directly by clients.
alter table public.verification_cache enable row level security;

drop policy if exists "service role manages verification cache"
    on public.verification_cache;

create policy "service role manages verification cache"
    on public.verification_cache
    for all
    using (auth.role() = 'service_role')
    with check (auth.role() = 'service_role');

-- Housekeeping: drop expired rows. Schedule with pg_cron, or call from the
-- backend's maintenance task.
create or replace function public.purge_expired_verifications()
returns integer
language plpgsql
as $$
declare
    removed integer;
begin
    delete from public.verification_cache where expires_at < now();
    get diagnostics removed = row_count;
    return removed;
end;
$$;
