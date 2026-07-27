-- ============================================================================
--  RLS hardening for `users`
--
--  Run this in the Supabase SQL editor after supabase_migration.sql.
--
--  Why this exists
--  ---------------
--  supabase_migration.sql enables RLS on `users` and writes own-row policies
--  for `scan_results` and `adr_reports`, but never adds a SELECT policy for
--  `users` itself. A table with RLS enabled and no SELECT policy should return
--  nothing — but if a permissive read policy was ever added by hand (or RLS
--  was left off), the whole table becomes readable by the anon key, which by
--  design ships inside the client app.
--
--  That matters because `users` holds email, display_name, photo_url and
--  device_token. A leaked device_token lets a third party push notifications
--  to that user.
--
--  This migration is idempotent — safe to run more than once.
-- ============================================================================

ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Drop any pre-existing permissive policies before re-creating tight ones.
DROP POLICY IF EXISTS "Users can view own row"   ON users;
DROP POLICY IF EXISTS "Users can update own row" ON users;
DROP POLICY IF EXISTS "Users can insert own row" ON users;
DROP POLICY IF EXISTS "Public read access"       ON users;
DROP POLICY IF EXISTS "Enable read access for all users" ON users;

-- Own-row only. Matches the pattern already used by scan_results/adr_reports:
-- the Firebase UID arrives as the `sub` claim of the request JWT.
CREATE POLICY "Users can view own row" ON users
    FOR SELECT USING (id = current_setting('request.jwt.claims', true)::json->>'sub');

CREATE POLICY "Users can insert own row" ON users
    FOR INSERT WITH CHECK (id = current_setting('request.jwt.claims', true)::json->>'sub');

CREATE POLICY "Users can update own row" ON users
    FOR UPDATE USING (id = current_setting('request.jwt.claims', true)::json->>'sub');

-- No DELETE policy: account deletion goes through the backend's service-role
-- key, which bypasses RLS. Clients must not be able to delete rows directly.

-- ---------------------------------------------------------------------------
-- Verify. Expected after running this:
--   anon key      -> 0 rows
--   service_role  -> every row
-- ---------------------------------------------------------------------------
-- SELECT tablename, policyname, cmd
--   FROM pg_policies WHERE tablename = 'users' ORDER BY policyname;
--
-- SELECT relname, relrowsecurity
--   FROM pg_class WHERE relname = 'users';
