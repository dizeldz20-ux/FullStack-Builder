<purpose>
Deploy a full Next.js 15 app (with App Router, server components, API routes) to Cloudflare Workers using the OpenNext or Workers Static Assets pattern. Sets up the wrangler config, env vars, secrets, and Cloudflare Access protection.
</purpose>

<user-story>
As the user who built a Next.js 15 product with Supabase auth, I want one command to deploy the whole thing (frontend + API + auth) to Cloudflare Workers, get a temp URL, and have it password-protected, so I can share a working demo with a client or tester.
</user-story>

<when-to-use>
- "תעלה לי את ה-Next.js app"
- "deploy my Next.js product to Cloudflare"
- "תעלה את המוצר שלי"

**Default for most modern the user products** — Next.js 15 + App Router + Supabase = this is the most common deploy path.

NOT for: pure static sites (use `deploy-static-site.md`), single Worker scripts (use `deploy-worker-script.md`).
</when-to-use>

<context>
@frameworks/env-inventory-cf.md
@../supabase-auth-patterns/SKILL.md (if the app uses Supabase auth — load this first)
</context>

<references>
@frameworks/workers-quickstart.md (during step "setup_wrangler")
@frameworks/env-vars-and-secrets-cf.md (during step "configure_env")
@frameworks/cloudflare-access-patterns.md (during step "protect_with_access")
@frameworks/deployment-security-checklist.md (always before final report)
@references/cloudflare-deploy-quick-ref.md
@../supabase-auth-patterns/frameworks/env-vars-and-secrets.md (for Next.js + Supabase env var rules)
</references>

<steps>

<step name="verify_prerequisites">
1. Next.js 15+ project with App Router
2. `package.json` has `next: "^15.0.0"` (or later)
3. `next.config.js` (or `.ts` or `.mjs`) exists
4. The app builds locally: `npm run build` succeeds
5. If the app uses Supabase: `@supabase/ssr` installed, `proxy.ts` at root, `lib/supabase/{client,server}.ts` exist
6. Workers + Pages available (read env-inventory-cf.md)

If `npm run build` fails locally, **stop and fix the build first**. Don't deploy a broken build.
</step>

<step name="choose_deployment_pattern">
Cloudflare has 3 ways to deploy Next.js. Choose based on the app:

| Pattern | Best for | Trade-offs |
|---|---|---|
| **Workers Static Assets** (recommended) | Modern Next.js 15 with App Router, mostly static + ISR | Static export, some features (SSR with cookies) need extra config |
| **OpenNext for Cloudflare** | Full Next.js (SSR, API routes, middleware, all features) | More setup, but full Next.js compatibility |
| **Cloudflare Pages + Functions** | Apps built around Pages paradigm (older approach) | Limited vs Workers Static Assets |

**For 90% of the user's products:** Workers Static Assets is the right choice. The setup is in `next.config.js`:

```js
// next.config.js
export default {
  output: 'export',  // Static export (default for Workers Static Assets)
  images: { unoptimized: true },  // Workers Static Assets doesn't support next/image optimization
  trailingSlash: true,  // Required for Workers Static Assets routing
}
```

**For full SSR (API routes, server actions, dynamic rendering):** Use OpenNext. Setup is more involved but you get full Next.js.

**This task covers Workers Static Assets first** (most common), with a footnote for OpenNext setup.
</step>

<step name="setup_wrangler" priority="last">
Create `wrangler.jsonc` at the project root:

```jsonc
{
  "name": "<project-name>",
  "compatibility_date": "2026-06-01",
  "compatibility_flags": ["nodejs_compat"],
  "assets": {
    "directory": "./out",
    "binding": "ASSETS"
  }
}
```

If you used `next build` (without export), the output is in `.next/` not `out/`. For Workers Static Assets, you need to set `output: 'export'` in `next.config.js` and rebuild.

For OpenNext, the setup is more complex (uses `@opennextjs/cloudflare` adapter). See `@frameworks/workers-quickstart.md` for details.
</step>

<step name="build_static_export" priority="last">
For Workers Static Assets:

```bash
# 1. Add to next.config.js:
#    output: 'export'
#    images: { unoptimized: true }
#    trailingSlash: true

# 2. Build
npm run build
# Output goes to ./out/

# 3. Verify
ls out/index.html  # Should exist
```

**If the build fails on dynamic routes / API routes / cookies:** Workers Static Assets doesn't support them. Either:
- Switch to OpenNext (full SSR)
- Or convert those routes to client-side (loses server benefits)

For the user's products, the common pattern is: **static export + Supabase for dynamic data** (queries from the client side). This works with Workers Static Assets.
</step>

<step name="first_deploy_subdomain_setup">
If this is the first Worker in the account, set the subdomain first (one-time):

```bash
curl -X PUT "https://api.cloudflare.com/client/v4/accounts/<your-cloudflare-account-id>/workers/subdomain" \
  -H "Authorization: Bearer *** -H "Content-Type: application/json" \
  --data '{"subdomain": "<chosen-subdomain>"}'
```

Subdomain naming: pick something short and memorable. Once set, it's hard to change.
</step>

<step name="deploy_via_mcp" priority="last">
**Workers Static Assets deployment:**

```python
# Use the MCP to deploy the build output as a Worker with assets
mcp_cloudflare_worker_put(
  name="<project-name>",
  script="""
export default {
  async fetch(request, env) {
    // For Workers Static Assets, the assets binding serves the static files
    return env.ASSETS.fetch(request);
  }
};
""",
  compatibility_date="2026-06-01"
)
```

**For OpenNext (full SSR):**

```bash
# Use OpenNext's deploy command
npx opennextjs-cloudflare build
npx opennextjs-cloudflare deploy
```

**Via wrangler CLI (works for both):**

```bash
cd /path/to/nextjs-project
CLOUDFLARE_API_TOKEN=$(cat <workspace>/memory/.secrets/cloudflare.token) wrangler deploy
```

The output URL is `https://<project-name>.<subdomain>.workers.dev`.
</step>

<step name="configure_env" priority="last">
Next.js apps have TWO sets of env vars:

1. **Build-time** (baked into the bundle): `NEXT_PUBLIC_*` (Vite) or `NEXT_PUBLIC_*` (Next.js) — must be set when running `npm run build`, not at deploy time.
2. **Runtime** (read from `env` in the Worker): non-prefixed vars — set via `wrangler secret` or env vars after deploy.

**For Workers Static Assets (static export):**
- All env vars are **build-time**. You must pass them as env vars when running `npm run build`:
  ```bash
  NEXT_PUBLIC_SUPABASE_URL=https://<ref>.supabase.co \
  NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=sb_publishable_... \
  npm run build
  ```
- No runtime env vars. Anything sensitive (Supabase Service Role Key) **must NOT be in the build** — it would be public.

**For OpenNext (SSR):**
- `NEXT_PUBLIC_*` are still build-time (same as above)
- Other vars (like `SUPABASE_SECRET_KEY`, `DATABASE_URL`) are runtime — set via `wrangler secret put`:
  ```bash
  echo "*** wrangler secret put SUPABASE_SECRET_KEY
  ```

**The critical rule:** The Service Role Key (`sb_secret_...`) goes in **runtime secrets only**, never `NEXT_PUBLIC_*`. If it's in `NEXT_PUBLIC_*`, it's in the client bundle and anyone can read it.

For full rules, see `@../supabase-auth-patterns/frameworks/env-vars-and-secrets.md`.
</step>

<step name="verify_deployment">
1. Visit the URL in a browser
2. Check that the home page renders (200, not 404 or 500)
3. Check that Supabase queries work (if you have data)
4. Check the browser console for errors
5. Test one user interaction (sign up, click a button, etc.)

If something's broken:
- **404 on routes**: `trailingSlash: true` in `next.config.js`, rebuild
- **Images not loading**: `images: { unoptimized: true }` in `next.config.js`, rebuild
- **Supabase errors**: check `NEXT_PUBLIC_SUPABASE_URL` is set at build time
- **500 errors**: check `mcp_cloudflare_workers_analytics_search` for error logs
</step>

<step name="protect_with_access" priority="last">
**NON-NEGOTIABLE.** Follow `@frameworks/cloudflare-access-patterns.md`.

**For Next.js apps with Supabase auth:** there's a tension — the user is signing in via Supabase (their own email + password) AND the URL is protected by Cloudflare Access (one-time PIN). Two layers of auth. Is that right?

**Answer:** Yes, for a **temp URL demo**. Cloudflare Access protects the URL itself (no one can reach the app without a PIN), Supabase auth protects the user's data (no one can see another user's data). They serve different purposes.

**For production:** you'd remove Cloudflare Access and rely on Supabase auth alone (the app is public, the data is per-user).

**For the user's temp URLs:** keep both. The PIN is a one-time setup; the Supabase auth is the actual login.
</step>

<step name="final_verification">
- [ ] Next.js build succeeded (no errors)
- [ ] Static export generated (`out/` directory exists with `index.html`)
- [ ] Worker deployed (URL responds 200)
- [ ] All `NEXT_PUBLIC_*` env vars set at build time
- [ ] No secrets in the build bundle (grep for `sb_secret_`, service role, etc.)
- [ ] Supabase queries work (if applicable)
- [ ] Cloudflare Access protection active
- [ ] the user received: URL + access email + deployment ID + Supabase test credentials
</step>

</steps>

<output>
## Artifact
- A live Next.js app at `https://<project-name>.<subdomain>.workers.dev`
- Protected by Cloudflare Access
- All env vars configured (build-time + runtime)
- Documented deployment record

## Format
- New: `wrangler.jsonc`
- Updated: `next.config.js` (with `output: 'export'`, `images: { unoptimized: true }`, `trailingSlash: true`)
- New: `./out/` (build output, usually gitignored)
- Deployment record at `.hermes/cf-deploy/<project-name>-<timestamp>.md`
</output>

<acceptance-criteria>
- [ ] `next build` succeeds (with `output: 'export'`)
- [ ] `out/index.html` exists
- [ ] Worker deployed to Workers + Static Assets
- [ ] URL returns 200
- [ ] All public env vars (`NEXT_PUBLIC_*`) are in the build
- [ ] No `SUPABASE_SECRET_KEY` or `sb_secret_` in the build bundle
- [ ] Cloudflare Access protection active
- [ ] If Supabase is used: RLS is enabled on all tables (validated via the supabase-auth-patterns skill)
- [ ] the user received: URL + access email + deployment ID
</acceptance-criteria>
