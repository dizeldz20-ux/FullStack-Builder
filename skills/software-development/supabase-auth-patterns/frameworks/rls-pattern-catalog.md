<rls_pattern_catalog>

## Purpose
Copy-paste RLS policy templates for the most common patterns. Every public table in Supabase should have RLS + policies — these are the recipes.

## When this framework loads
- During `tasks/configure-rls-policies.md` → step "write_policies"
- When adding RLS to a new table
- When reviewing existing RLS policies for correctness

---

## § Pre-flight: Enable RLS

Before any policy, run this for every public table:

```sql
ALTER TABLE <table_name> ENABLE ROW LEVEL SECURITY;
```

**After this, no data is accessible via the API until policies are created.** This is the safe state.

---

## § The 8 Patterns

### Pattern 1: User owns the row directly (id = auth.users.id)

Use when the table's primary key IS the user's UUID (e.g. a `profiles` table keyed by user id).

```sql
-- profiles table: id uuid primary key references auth.users(id)

CREATE POLICY "Users can view own profile" ON profiles
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) = id);

CREATE POLICY "Users can update own profile" ON profiles
  FOR UPDATE TO authenticated
  USING ((SELECT auth.uid()) = id)
  WITH CHECK ((SELECT auth.uid()) = id);

CREATE POLICY "Users can insert own profile" ON profiles
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT auth.uid()) = id);

-- Optional: self-deletion
CREATE POLICY "Users can delete own profile" ON profiles
  FOR DELETE TO authenticated
  USING ((SELECT auth.uid()) = id);
```

**Performance index:**
```sql
-- id is already a primary key, so it's automatically indexed.
-- No additional index needed.
```

---

### Pattern 2: User owns via foreign key (user_id references auth.users)

Use when the table has its own UUID and references users.

```sql
-- interactions table: id uuid, user_id uuid references auth.users(id)

CREATE POLICY "Users can view own interactions" ON interactions
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users can insert own interactions" ON interactions
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT auth.uid()) = user_id);

-- Optional: allow update + delete
CREATE POLICY "Users can update own interactions" ON interactions
  FOR UPDATE TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users can delete own interactions" ON interactions
  FOR DELETE TO authenticated
  USING ((SELECT auth.uid()) = user_id);
```

**Performance index:**
```sql
CREATE INDEX interactions_user_id_idx ON interactions(user_id);
```

**This is the standard ownership pattern (user_id FK to auth.users).** Validated working.

---

### Pattern 3: Public read, no write

Use for content tables (e.g. blog posts, products, courses).

```sql
-- posts table: published boolean, author_id uuid

CREATE POLICY "Anyone can view published posts" ON posts
  FOR SELECT TO authenticated, anon
  USING (published = true);

-- No INSERT/UPDATE/DELETE policies = blocked for anon and authenticated
-- Writes happen via service_role key (admin tasks, Server Actions)
```

**Read-only for users.** Writes only via service role.

---

### Pattern 4: Public read, owner can edit

Use for user-generated content (e.g. blog posts, social posts).

```sql
-- posts table: published boolean, author_id uuid

CREATE POLICY "Anyone can view posts" ON posts
  FOR SELECT TO authenticated, anon
  USING (true);

CREATE POLICY "Authors can update own posts" ON posts
  FOR UPDATE TO authenticated
  USING ((SELECT auth.uid()) = author_id)
  WITH CHECK ((SELECT auth.uid()) = author_id);

CREATE POLICY "Authors can delete own posts" ON posts
  FOR DELETE TO authenticated
  USING ((SELECT auth.uid()) = author_id);

-- INSERT: anyone authenticated can create
CREATE POLICY "Authenticated users can create posts" ON posts
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT auth.uid()) = author_id);
```

**Performance index:**
```sql
CREATE INDEX posts_author_id_idx ON posts(author_id);
```

---

### Pattern 5: Team-based access (multi-tenant)

Use when users belong to teams/orgs.

```sql
-- projects table: id uuid, team_id uuid

-- Add team_id to app_metadata when user joins a team
-- (done via service role, not by the user themselves)

CREATE POLICY "Team members can view team projects" ON projects
  FOR SELECT TO authenticated
  USING (
    team_id IN (
      SELECT (auth.jwt() -> 'app_metadata' -> 'teams')::text[]
    )
  );

CREATE POLICY "Team members can create projects" ON projects
  FOR INSERT TO authenticated
  WITH CHECK (
    team_id IN (
      SELECT (auth.jwt() -> 'app_metadata' -> 'teams')::text[]
    )
  );

-- ... similar for UPDATE/DELETE
```

**Important:** `app_metadata` is set by the server (not user-editable), so users can't escalate their team memberships by editing their JWT.

---

### Pattern 6: Role-based access (admin / user)

```sql
-- posts table with admin-only deletion

CREATE POLICY "Users can view posts" ON posts
  FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "Admins can delete any post" ON posts
  FOR DELETE TO authenticated
  USING (
    (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
  );

-- Users can delete their own posts:
CREATE POLICY "Authors can delete own posts" ON posts
  FOR DELETE TO authenticated
  USING ((SELECT auth.uid()) = author_id);
```

**Multiple DELETE policies = OR logic.** Either the user is admin OR they're the author.

---

### Pattern 7: Time-bounded access (e.g. subscriptions, trials)

```sql
-- premium_content table: only accessible during active subscription

CREATE POLICY "Active subscribers can view premium content" ON premium_content
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM subscriptions
      WHERE subscriptions.user_id = (SELECT auth.uid())
        AND subscriptions.status = 'active'
        AND subscriptions.ends_at > NOW()
    )
  );
```

**Real-world use:** SaaS products with subscription tiers. The `subscriptions` table itself needs its own RLS (pattern 2).

---

### Pattern 8: Public read of count/summary, restricted read of details

```sql
-- articles table: title is public, body is for subscribers only

CREATE POLICY "Anyone can view article titles" ON articles
  FOR SELECT TO anon, authenticated
  USING (true);
  -- Note: column-level security is a separate thing
  -- Either grant SELECT on title only, or use a view

-- Alternative: use a view with security_invoker
CREATE VIEW article_titles WITH (security_invoker = true) AS
  SELECT id, title, slug, published_at FROM articles WHERE published = true;

GRANT SELECT ON article_titles TO anon, authenticated;
```

**Use views** to expose only specific columns to public users. Views bypass RLS by default in Postgres < 15, so use `security_invoker = true` (Postgres 15+).

---

## § Helper Functions Reference

| Function | Returns | Use case |
|---|---|---|
| `auth.uid()` | UUID of the current user | Most common — "user X owns this row" |
| `auth.jwt()` | Full JWT object | Access `app_metadata` (roles, teams) |
| `auth.role()` | `'authenticated'` or `'anon'` | Quick role check (less common — usually use the `TO` clause) |

**Performance tip:** Always wrap `auth.uid()` in a subquery:
```sql
-- ❌ Slow (called for every row):
USING (auth.uid() = user_id)

-- ✅ Fast (called once, cached):
USING ((SELECT auth.uid()) = user_id)
```

---

## § Auto-Enable RLS Trigger (run once)

```sql
-- Add to your first migration: supabase/migrations/00000000000000_rls_trigger.sql

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

**Why:** Future-proof. Every new table automatically gets RLS. If you forget, the trigger catches it.

---

## § Testing Your Policies

```sql
-- Test as anonymous user (no auth)
SET ROLE anon;
SELECT * FROM users;  -- Should return 0 rows
RESET ROLE;

-- Test as a specific authenticated user
SET LOCAL role authenticated;
SET LOCAL request.jwt.claim.sub TO '00000000-0000-0000-0000-000000000001';
SELECT * FROM interactions;  -- Should return only that user's rows
RESET ROLE;
```

Or in the browser, after signing in:
```typescript
// Should return only the current user's row
const { data } = await supabase.from('users').select('*').eq('id', user.id)

// Should return 0 rows (different user's row)
const { data } = await supabase.from('users').select('*').eq('id', 'someone-elses-id')
```

---

## § Common Pitfalls

### Policy too permissive
```sql
-- ❌ Allows ANY authenticated user to see ALL users
CREATE POLICY "Users can view all users" ON users
  FOR SELECT TO authenticated
  USING (true);

-- ✅ Each user can see only their own row
CREATE POLICY "Users can view own profile" ON users
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) = id);
```

### Forgot WITH CHECK on UPDATE
```sql
-- ❌ User can update any row, but only if they match (USING)
-- but then change the user_id to someone else (no WITH CHECK)
CREATE POLICY "Users can update own profile" ON users
  FOR UPDATE TO authenticated
  USING ((SELECT auth.uid()) = id);
-- Missing: WITH CHECK ((SELECT auth.uid()) = id)

-- ✅ User can only update their own row, AND can't change ownership
CREATE POLICY "Users can update own profile" ON users
  FOR UPDATE TO authenticated
  USING ((SELECT auth.uid()) = id)
  WITH CHECK ((SELECT auth.uid()) = id);
```

### No RLS at all
```sql
-- ❌ This is the world-readable disaster
-- (no ALTER TABLE ... ENABLE ROW LEVEL SECURITY)
-- Every user can SELECT every row.

-- ✅ Always:
ALTER TABLE <table> ENABLE ROW LEVEL SECURITY;
```

### `auth.uid()` returns null for anon users
```sql
-- ❌ For anon users, (SELECT auth.uid()) is NULL.
-- This breaks comparisons: NULL = anything is NULL (not true).
-- Result: the policy silently fails and blocks access.

-- ✅ Either:
-- a) Use TO authenticated to scope the policy to logged-in users only
CREATE POLICY ... TO authenticated USING (...);

-- b) Handle NULL explicitly
CREATE POLICY ... USING (auth.uid() IS NOT NULL AND (SELECT auth.uid()) = user_id);
```

### Views bypass RLS
```sql
-- ❌ View created without security_invoker
CREATE VIEW user_stats AS SELECT user_id, COUNT(*) FROM interactions GROUP BY user_id;
-- This view is owned by `postgres` role, which bypasses RLS.
-- All users can see all stats.

-- ✅ Use security_invoker (Postgres 15+)
CREATE VIEW user_stats WITH (security_invoker = true) AS
  SELECT user_id, COUNT(*) FROM interactions GROUP BY user_id;
```

</rls_pattern_catalog>
