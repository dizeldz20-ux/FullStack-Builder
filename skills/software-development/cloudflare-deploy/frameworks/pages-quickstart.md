<pages_quickstart>

## Purpose
Step-by-step walkthrough for Cloudflare Pages — static site hosting with optional serverless Functions. Best for SPAs, JAMstack sites, and Next.js static exports.

## When this framework loads
- During `tasks/deploy-static-site.md` → step "deploy_via_mcp"
- When the user asks to deploy a Vite/React/Astro static site
- For SPAs that don't need server-side rendering

---

## § What is Cloudflare Pages?

Cloudflare Pages is a static site hosting service built on top of Workers. It supports:
- Static HTML/CSS/JS (any framework that can output static files)
- Optional serverless Functions (Pages Functions, in `/functions` directory)
- Git-based deploys (auto-deploy on push)
- Custom domains
- Preview deployments per git branch

**Comparison to Workers Static Assets (2026):**
- Pages: more features, git integration, preview deploys, but more opinionated
- Workers Static Assets: simpler, more flexible, but no git integration (use wrangler)

**For the user's products:** Pages for static SPAs, Workers Static Assets for Next.js with Workers.

---

## § Setup options (3 ways)

### Option A: Via MCP (recommended in Hermes sessions)

The MCP for Pages deployment is more limited than for Workers. For Pages Direct Upload, the MCP may not have a direct tool. Use:

```bash
# Fall back to wrangler CLI for Pages deploy
CLOUDFLARE_API_TOKEN=*** <workspace>/memory/.secrets/cloudflare.token) wrangler pages deploy <build-dir> --project-name=<name> --branch=main --commit-dirty=true
```

The output URL is `https://<hash>.<project-name>.pages.dev` (note the hash prefix — different from Workers).

### Option B: Via Cloudflare Dashboard (recommended for first setup)

1. Go to [dash.cloudflare.com](https://dash.cloudflare.com) → Workers & Pages
2. Click "Create" → "Pages" → "Upload assets" (Direct Upload) or "Connect to Git"
3. For Direct Upload: drag & drop the build directory
4. For Git: connect a GitHub/GitLab repo, set build command + output directory

**Git integration is the most common Pages workflow** — push to main, auto-deploy.

### Option C: Via Wrangler CLI (good for CI/CD)

```bash
# Create a new Pages project
wrangler pages project create <project-name>

# Deploy the build output
wrangler pages deploy <build-dir> --project-name=<project-name>
```

---

## § Framework-specific build configs

Cloudflare Pages auto-detects many frameworks. The "Framework preset" in the Dashboard handles the build command + output dir. Common presets:

| Framework | Build command | Output dir |
|---|---|---|
| None (plain HTML) | (none) | `.` |
| Vite | `npm run build` | `dist` |
| Create React App | `npm run build` | `build` |
| Next.js (static) | `npm run build` | `out` |
| Astro (static) | `npm run build` | `dist` |
| Gatsby | `npm run build` | `public` |
| SvelteKit (static) | `npm run build` | `build` |
| Nuxt 3 (static) | `npm run build` | `.output/public` |
| Hugo | `hugo` | `public` |
| Jekyll | `jekyll build` | `_site` |

**For Next.js with static export**, add to `next.config.js`:
```js
module.exports = {
  output: 'export',
  images: { unoptimized: true },
  trailingSlash: true
}
```

Without these, the build will fail or images won't load.

---

## § SPA routing fallback

Single-page apps (React, Vue, Svelte) need a fallback to `index.html` for client-side routes. Cloudflare Pages uses a `_redirects` file in the build output:

```bash
# In the project root, before building:
cat > public/_redirects << 'EOF'
/*    /index.html   200
EOF
```

For Vite, the file goes in `public/_redirects`. For Next.js, the `_redirects` file goes in the `public/` directory (it gets copied to `out/` during static export).

For non-SPA sites (one page per route), don't add `_redirects` — let Pages serve the static files.

---

## § Environment variables

Pages has 2 scopes for env vars:

| Scope | When to use | How to set |
|---|---|---|
| **Production** | Live site | Dashboard → Settings → Environment variables |
| **Preview** | PR previews | Same place, "Preview" tab |

For Vite, the convention is `VITE_*` prefix. For Next.js, `NEXT_PUBLIC_*` (build-time only).

```bash
# Via wrangler CLI:
wrangler pages secret set NEXT_PUBLIC_SUPABASE_URL --project-name=<name>
# (Prompts for the value)
```

**Anti-pattern:** Don't put production secrets in the "Preview" scope. They're exposed on preview URLs that may be visible to outsiders.

---

## § Custom domains

Same as Workers — add the domain in the Pages project settings, Cloudflare auto-provisions SSL.

**Difference from Workers:** Pages can have multiple branches (production + preview), each with its own domain. E.g. `main` → `app.example.com`, `staging` → `staging.example.com`.

---

## § Pages Functions (optional serverless)

For server-side logic without a full Worker, add a `/functions` directory:

```typescript
// functions/api/hello.ts
export const onRequest: PagesFunction = async (context) => {
  return new Response('Hello from Pages Function!')
}
```

Routes: `functions/api/hello.ts` → `/api/hello`. Useful for small serverless bits in an otherwise static site.

For full server-side apps, use Workers or OpenNext instead.

---

## § Common pitfalls

### "Page not found" on SPA routes
- Cause: Missing `_redirects` file
- Fix: Add `/* /index.html 200` to `public/_redirects`

### Images return 404
- Cause: `next/image` optimization not supported in static export
- Fix: Use `images: { unoptimized: true }` in `next.config.js`, or use plain `<img>` tags

### Environment variables are `undefined` in the browser
- Cause: Vars are build-time (Next.js, Vite) — must be set when building, not at runtime
- Fix: Re-build with the vars in the environment: `NEXT_PUBLIC_FOO=bar npm run build`

### "Build command failed"
- Cause: Build script error, missing dependency, wrong framework preset
- Fix: Run the build locally first, fix any errors, then re-deploy

### Preview deploys are slow
- Cause: Pages builds every PR from scratch
- Fix: Use the `wrangler pages deploy` direct upload instead of git integration (faster, manual)

</pages_quickstart>
