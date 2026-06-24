<workers_quickstart>

## Purpose
Step-by-step walkthrough for creating and deploying a Cloudflare Worker. Covers Wrangler CLI setup, the `wrangler.jsonc` config, and the difference between deploying via Wrangler, MCP, and the Dashboard.

## When this framework loads
- During `tasks/deploy-worker-script.md` → step "deploy_via_mcp"
- During `tasks/deploy-nextjs-fullstack.md` → step "setup_wrangler"
- When the user asks to create a new Worker from scratch

---

## § What is a Worker?

A Cloudflare Worker is a JavaScript/TypeScript function that runs on Cloudflare's edge network (300+ cities worldwide). It can:
- Serve HTTP responses (like a serverless API)
- Modify requests/responses
- Run on a schedule (cron triggers)
- React to events from other Cloudflare services (KV, R2, D1, Queues)

**The runtime:** V8 isolates (not Node.js by default). For Node.js APIs, add `"compatibility_flags": ["nodejs_compat"]` to `wrangler.jsonc`.

**Limits (free tier, 2026-06-24):**
- 100,000 requests/day
- 10ms CPU time per request
- 1MB script size
- 25MB KV value size

---

## § Setup options (3 ways)

### Option A: Via MCP (recommended in Hermes sessions)

The Cloudflare MCP is loaded in this session. Use:

```python
mcp_cloudflare_worker_put(
  name="<project-name>",
  script="""
export default {
  async fetch(request, env, ctx) {
    return new Response('Hello from Cloudflare!', { status: 200 });
  }
}
""",
  compatibility_date="2026-06-01"
)
```

This deploys the Worker. The URL is `https://<project-name>.<subdomain>.workers.dev`.

### Option B: Via Wrangler CLI (recommended for local dev)

```bash
# Install wrangler (locally to the project)
npm install -D wrangler

# Create wrangler.jsonc
cat > wrangler.jsonc << 'EOF'
{
  "name": "<project-name>",
  "main": "src/index.ts",
  "compatibility_date": "2026-06-01",
  "compatibility_flags": ["nodejs_compat"]
}
EOF

# Login with the API token (non-interactive)
CLOUDFLARE_API_TOKEN=*** <workspace>/memory/.secrets/cloudflare.token) wrangler login

# Deploy
CLOUDFLARE_API_TOKEN=*** wrangler deploy
```

### Option C: Via Cloudflare Dashboard

1. Go to [dash.cloudflare.com](https://dash.cloudflare.com) → Workers & Pages
2. Click "Create" → "Create Worker"
3. Edit the code in the browser
4. Click "Deploy"

The dashboard version is for quick experiments, not real development.

---

## § The wrangler.jsonc config (most important file)

Minimum required fields:

```jsonc
{
  "name": "<project-name>",            // kebab-case, unique in account
  "main": "src/index.ts",                // entry point
  "compatibility_date": "2026-06-01",    // pin to a specific V8 version
  "compatibility_flags": ["nodejs_compat"]  // enable Node.js APIs
}
```

Common additions:

```jsonc
{
  // ... above fields ...
  
  // Plain env vars (visible in dashboard)
  "vars": {
    "ENVIRONMENT": "production",
    "API_BASE_URL": "https://api.example.com"
  },
  
  // KV namespaces
  "kv_namespaces": [
    {
      "binding": "MY_KV",
      "id": "<kv-namespace-id>"
    }
  ],
  
  // R2 buckets (requires R2 permission on the token)
  "r2_buckets": [
    {
      "binding": "MY_BUCKET",
      "bucket_name": "my-bucket"
    }
  ],
  
  // Cron triggers
  "triggers": {
    "crons": ["0 */6 * * *"]  // every 6 hours
  },
  
  // Custom domain
  "routes": [
    {
      "pattern": "app.example.com",
      "custom_domain": true
    }
  ]
}
```

---

## § The Worker code structure

### Module Worker (recommended, modern)

```typescript
// src/index.ts
export interface Env {
  // Plain env vars
  ENVIRONMENT: string
  API_BASE_URL: string
  
  // Secrets
  SUPABASE_SECRET_KEY: string
  
  // Bindings
  MY_KV: KVNamespace
}

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    // Read a plain var
    const envName = env.ENVIRONMENT  // "production"
    
    // Read a secret
    const supabaseKey = env.SUPABASE_SECRET_KEY  // decrypted at runtime
    
    // Use a KV namespace
    const value = await env.MY_KV.get('key')
    
    // Return a response
    return new Response(JSON.stringify({ env: envName }), {
      headers: { 'Content-Type': 'application/json' }
    })
  },
  
  // Cron trigger handler
  async scheduled(event: ScheduledEvent, env: Env, ctx: ExecutionContext) {
    ctx.waitUntil(doPeriodicTask(env))
  }
}
```

### Service Worker (legacy, ES module syntax only)

```javascript
// src/index.js
export default {
  async fetch(request, env, ctx) {
    return new Response('Hello!')
  }
}
```

**Always use Module Worker syntax** for new code. The Service Worker syntax is legacy and lacks TypeScript support.

---

## § Local development

```bash
# Start a local dev server
CLOUDFLARE_API_TOKEN=*** wrangler dev

# The Worker is available at http://localhost:8787
# Changes to src/ hot-reload automatically
```

For KV / R2 / D1 in local dev, you need to configure local persistence. See the wrangler docs for details.

---

## § First-time setup: the workers.dev subdomain

When you deploy a Worker for the first time, Cloudflare asks you to choose a `*.workers.dev` subdomain. This is a one-time setup per account.

**Via API:**

```bash
# Check if subdomain is set
curl "https://api.cloudflare.com/client/v4/accounts/<your-cloudflare-account-id>/workers/subdomain" \
  -H "Authorization: Bearer *** <workspace>/memory/.secrets/cloudflare.token)"

# If 404, set it
curl -X PUT "https://api.cloudflare.com/client/v4/accounts/<your-cloudflare-account-id>/workers/subdomain" \
  -H "Authorization: Bearer *** -H "Content-Type: application/json" \
  --data '{"subdomain": "<chosen-name>"}'
```

The chosen name becomes the prefix for all `*.workers.dev` URLs in the account. E.g. if you choose `<your-subdomain>`, the Worker URL is `https://<project-name>.<your-subdomain>.workers.dev`.

**Naming tips:**
- Keep it short (3-15 chars)
- Memorable (you'll be sharing these URLs)
- Doesn't need to match the project (it's per-account, not per-project)

---

## § Deployment options (after the first one)

For subsequent deploys, you can:
1. **`wrangler deploy`** — deploys the current code (CLI)
2. **`mcp_cloudflare_worker_put`** — deploys via MCP (use `script` param)
3. **Cloudflare Dashboard** — edit and deploy in the browser
4. **Git integration** — auto-deploy on git push (set up in Dashboard)

For the user's workflow, **wrangler deploy** from the project directory is the standard.

---

## § Common pitfalls

### "Subdomain not configured"
- Cause: First Worker in the account, no subdomain set
- Fix: Set the subdomain via API (see above) or Dashboard

### "Worker exceeded CPU time limit"
- Cause: Worker took >10ms (free) or >50ms (paid) of CPU time
- Fix: Optimize the code, add caching, or upgrade to paid plan

### "Script size exceeds 1MB"
- Cause: Too many dependencies bundled
- Fix: Code-split, remove unused deps, or use Worker Loaders for large code

### "Module not found" at deploy time
- Cause: Missing dependency in `package.json` or wrong `main` path in `wrangler.jsonc`
- Fix: Run `npm install` and verify the `main` path exists

### Changes don't take effect
- Cause: Browser cache, or the wrong Worker version is deployed
- Fix: Hard refresh (Cmd+Shift+R), check `wrangler versions list` (or `mcp_cloudflare_version_list`)

</workers_quickstart>
