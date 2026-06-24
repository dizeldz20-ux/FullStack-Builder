<purpose>
Add Row Level Security (RLS) policies to existing Supabase tables. This is the most security-critical task — every table in Supabase should have RLS enabled, or the data is world-readable through the auto-generated API.
</purpose>

<user-story>
As a the user who has tables in Supabase, I want to enable RLS and write policies that ensure users can only see/modify their own data, so that I don't have a security incident where users can read each other's private information.
</user-story>

<when-to-use>
- "תוסיף RLS policies לטבלאות"
- After creating a new table (should be done BEFORE first SELECT goes to production)
- During security audit (an existing product without RLS = P0 incident)
- When adding new tables to an existing auth-enabled product
</when-to-use>

<context>
None — this task is self-contained.
</context>

<references>
@frameworks/rls-pattern-catalog.md (during step "write_policies" — copy-paste policy templates)
@frameworks/env-vars-and-secrets.md (during step "verify_security" — env var rules)
@frameworks/pitfall-catalog.md (load on demand if anything breaks)
@references/supabase-auth-quick-reference.md
</references>

<steps>

<step name="audit_current_state" priority="first">
**Audit which tables lack RLS. This is the source of the incident.**

```bash
# Find all tables in the public schema
export SUPABASE_ACCESS_TOKEN=$(cat <workspace>/memory/.secrets/supabase.token)
SUPABASE_REF=$(grep NEXT_PUBLIC_SUPABASE_URL .env.local | sed -E 's|.*//([^.]+)\.supabase.co.*|\1|')

# Get list of tables and their RLS status
supabase --project-ref "$SUPABASE_REF" inspect db tables 2>/dev/null | grep -E "table|rowsecurity"
```

Or via SQL (in Supabase Dashboard → SQL Editor):
```sql
SELECT schemaname, tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;
```

**Tables with `rowsecurity = false` are world-readable.** Fix them now.
</step>

<step name="enable_rls">
**For every public table**, enable RLS:

```sql
-- Replace with your actual table names
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE interactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_badges ENABLE ROW LEVEL SECURITY;
```

**After running this, no data is accessible via the API** until you create policies. This is correct — the next step adds them.
</step>

<step name="auto_enable_trigger" priority="first">
**Recommended: install a trigger that auto-enables RLS on every new table.** This prevents future "we forgot" incidents.

```sql
-- One-time setup. Add to your first migration.
CREATE OR REPLACE FUNCTION rls_auto_enable()
RETURNS EVENT_TRIGGER LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog AS $$
DECLARE cmd record;
BEGIN
  FOR cmd IN
    SELECT * FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
      AND schema_name = 'public'
  LOOP
    EXECUTE format('alter table if exists %s enable row level security', cmd.object_identity);
  END LOOP;
END; $$;

CREATE EVENT TRIGGER ensure_rls
  ON ddl_command_end
  WHEN TAG IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
  EXECUTE FUNCTION rls_auto_enable();
```

**Note:** This applies to tables created AFTER the trigger is installed. Run the existing-table `ALTER TABLE` commands manually.
</step>

<step name="write_policies">
**Use the pattern catalog in @frameworks/rls-pattern-catalog.md.** Most common patterns:

### Pattern 1: User owns the row (most common)

```sql
-- users table: id = auth.users.id
CREATE POLICY "Users can view own profile" ON users
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) = id);

CREATE POLICY "Users can update own profile" ON users
  FOR UPDATE TO authenticated
  USING ((SELECT auth.uid()) = id)
  WITH CHECK ((SELECT auth.uid()) = id);

CREATE POLICY "Users can insert own row" ON users
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT auth.uid()) = id);

-- Optional: let users delete their own account
CREATE POLICY "Users can delete own account" ON users
  FOR DELETE TO authenticated
  USING ((SELECT auth.uid()) = id);
```

### Pattern 2: User owns via foreign key

```sql
-- interactions table: user_id references auth.users
CREATE POLICY "Users can view own interactions" ON interactions
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users can insert own interactions" ON interactions
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT auth.uid()) = user_id);
```

### Pattern 3: Public read, authenticated write

```sql
-- clinical_cases table: read by all, write by service role only
CREATE POLICY "Anyone can view active cases" ON clinical_cases
  FOR SELECT TO authenticated, anon
  USING (is_active = true);
-- No INSERT/UPDATE/DELETE policies = blocked for anon/authenticated
-- Service role key bypasses RLS, so admin writes work
```

### Pattern 4: Read by all, modify by owner

```sql
-- posts table: public read, owner can edit
CREATE POLICY "Anyone can view published posts" ON posts
  FOR SELECT TO authenticated, anon
  USING (published = true);

CREATE POLICY "Authors can update own posts" ON posts
  FOR UPDATE TO authenticated
  USING ((SELECT auth.uid()) = author_id)
  WITH CHECK ((SELECT auth.uid()) = author_id);
```

**For each table in your schema, write the right pattern. Do not skip this step.**
</step>

<step name="add_indexes">
RLS performance: `auth.uid()` lookup is slow without indexes.

```sql
-- For every column used in policies:
CREATE INDEX IF NOT EXISTS interactions_user_id_idx ON interactions(user_id);
CREATE INDEX IF NOT EXISTS posts_author_id_idx ON posts(author_id);
CREATE INDEX IF NOT EXISTS chat_history_user_id_idx ON chat_history(user_id);

-- General rule: if a policy uses `WHERE column = auth.uid()`,
-- the column needs an index.
```
</step>

<step name="verify_policies">
**Test that RLS actually blocks unauthorized access.**

```sql
-- Run this in SQL Editor as a non-authenticated user (set role to anon)
SET ROLE anon;

-- Should return 0 rows (because no SELECT policy allows anon)
SELECT COUNT(*) FROM users;

-- Reset role
RESET ROLE;

-- Now test as authenticated (set a specific user)
SET LOCAL role authenticated;
SET LOCAL request.jwt.claim.sub TO '00000000-0000-0000-0000-000000000001';

-- Should return only rows where user_id matches the JWT
SELECT COUNT(*) FROM interactions;

RESET ROLE;
```

Or test from the browser:
1. Open DevTools → Console
2. Run as a logged-in user: `await supabase.from('users').select('*')`
3. Should return ONLY the current user's row
4. Try to query another user's row by ID: should return empty

**If a test returns more rows than expected, the policy is wrong. Fix it before proceeding.**
</step>

<step name="verify_security">
Final security check:

```bash
# 1. No Service Role Key in client code
grep -r "SUPABASE_SECRET_KEY\|sb_secret_\|service_role" --include="*.ts" --include="*.tsx" --include="*.js" \
  app/ components/ lib/ 2>/dev/null
# Should be empty in client-bundled code paths

# 2. All tables have RLS
# (re-run the query from step 1)

# 3. RLS is enforced, not bypassed
# Check that all policies use the (SELECT auth.uid()) subquery pattern
# (faster than direct auth.uid() = ... calls)
```

**If any of these fail, fix before committing.**
</step>

<step name="final_verification">
- [ ] All public tables have `ENABLE ROW LEVEL SECURITY`
- [ ] Each table has policies for the roles that need access
- [ ] Policies use `(SELECT auth.uid())` for performance
- [ ] Indexes exist on all columns used in policies
- [ ] Auto-enable trigger installed (one-time setup)
- [ ] Tested with anon role: no data accessible
- [ ] Tested with authenticated role: only own data accessible
- [ ] No `SUPABASE_SECRET_KEY` in client code
- [ ] No `service_role` references in client-bundled code
- [ ] Service Role is only used in Server Actions / Route Handlers for admin tasks
</step>

</steps>

<output>
## Artifact
RLS is enabled on all public tables. Policies ensure users can only access their own data. The product is no longer world-readable.

## Format
- New SQL file: `supabase/migrations/<timestamp>_rls_policies.sql` (versioned migration)
- Updated: `supabase/config.toml` (if adding custom RLS settings)
- Documentation: each policy gets a comment explaining intent

## Location
Migrations go in `supabase/migrations/`. Apply via:
```bash
supabase db push
# or
supabase migration up
```
</output>

<acceptance-criteria>
- [ ] All public tables have RLS enabled
- [ ] Each table has explicit policies for `anon` and `authenticated` roles
- [ ] Policies use `(SELECT auth.uid())` pattern (not direct `auth.uid()`)
- [ ] Indexes on all columns referenced in policies
- [ ] Auto-enable RLS trigger installed
- [ ] Tested: anon role gets 0 rows from protected tables
- [ ] Tested: authenticated role gets only own data
- [ ] No Service Role Key in client-bundled code
- [ ] Migrations are versioned and committed
</acceptance-criteria>
