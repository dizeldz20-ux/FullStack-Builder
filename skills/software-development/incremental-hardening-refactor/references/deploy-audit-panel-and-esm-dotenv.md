# Deploy Audit Panel + ESM dotenv Hoisting

Two patterns that keep recurring on the Ruby voice agent (and any
small Express + React deploy behind a public tunnel):

## 1. ESM dotenv hoisting pitfall

**Symptom:** `process.env.<KEY>` reads as `undefined` inside service
modules, even though the `.env` file contains the key and the
`server.ts` logs `[env] loaded N keys from <path>`. Health and
manifest routes that read env at *request* time work; services
that read env at *module-import* time (e.g. `elevenLabsConfigured()`
called from a top-level `const`) report the key as missing.

**Root cause:** In ESM under `tsx` (and any transpiler that hoists
imports), top-level `import` statements are evaluated **before**
top-level code in the same file. So even if you write:

```ts
import { config } from 'dotenv'
config()                              // ← never runs before the import below
import { elevenLabsConfigured } from './services/elevenlabsTts.js'  // ← runs FIRST
```

the `elevenLabsConfigured()` call (or any other `process.env.*`
read happening at module top level) runs **before** `config()`.

**Fix:** Two complementary changes.

1. Force the env read at request time inside route handlers, not at
   module top level. Move every `const HAS_KEY = checkKey()` into
   the request handler so it runs after ESM has fully evaluated the
   module graph:

   ```ts
   manifestRouter.get('/manifest', (_req, res) => {
     const HAS_ELEVENLABS_KEY = Boolean(process.env.ELEVENLABS_API_KEY)  // ← request time
     ...
   })
   ```

2. If you have a service that genuinely needs the env at import
   time (e.g. to decide whether to register routes at all), load
   dotenv with an explicit path *before* the first import that
   needs it, and remove any other import above the `config()` call:

   ```ts
   import { config } from 'dotenv'
   import { fileURLToPath } from 'node:url'
   import { dirname, join } from 'node:path'
   const __dirname = dirname(fileURLToPath(import.meta.url))
   const result = config({ path: join(__dirname, '..', '.env') })
   console.log(`[env] loaded ${Object.keys(result.parsed ?? {}).length} keys`)
   // ... only then the imports that read process.env
   import { createApp } from './app.js'
   ```

   Even this is fragile; prefer option 1 (read at request time)
   for any value that's a boolean/health probe, and only use
   option 2 for values that must gate module-level setup.

**Debugging recipe when you suspect this:** add a `console.log`
right after the `config()` call in `server.ts`. If the log shows
the env was loaded but the downstream service still reports the
key as missing, you have the hoisting problem, not a missing
`.env`.

## 2. "🧾 מה רץ" deploy-audit panel

After every tunnel/secure-tunnel deploy, the user asks the same
question: "stack, latencies, tools, boundaries". Bake this into
the UI as a small panel so the answer is one click away, not a
new conversation.

**Backend (Express):** add a `GET /api/manifest` route that
returns:

```json
{
  "service": "...",
  "version": "...",
  "runtime": { "node": "v...", "uptimeSec": 123, "bridgeMode": "hermes", "hermesTimeoutMs": 4500 },
  "secrets": { "ELEVENLABS_API_KEY": "present|missing", "AGENT_ID": "...", "VOICE_ID": "...", "MODEL_ID": "..." },
  "stack": { "backend": "...", "frontend": "...", "brain": "...", "voice": "..." },
  "tools": [
    { "name": "...", "kind": "live|disabled|stub", "route": "POST /api/...", "note": "..." },
    ...
  ],
  "boundaries": [
    "No multi-user: ...",
    "Auth: Basic Auth gate on the Vite dev server (frontend). ..."
  ],
  "endpoints": [ "GET /api/health", ... ]
}
```

Field rules:

- `secrets` returns **booleans or short IDs only**, never the
  secret value itself. `ELEVENLABS_API_KEY: 'present'` is fine;
  `ELEVENLABS_API_KEY: 'sk_...'` is not.
- `tools[].kind` is `live` (real upstream), `stub` (returns canned
  data), or `disabled` (route present, not wired). Use these three
  words; don't invent new ones.
- `boundaries` lists the things the MVP explicitly chose **not** to
  ship, in plain English. Reviewers need to know what was deferred
  on purpose, not just what's present.
- Read all `process.env` at **request time**, not module top
  level — see pitfall 1 above.

**Frontend (React):** add a small modal triggered by a "🧾 מה רץ"
button in the header. Sections, in order:

1. **Latencies** (live, via the same tunnel the user is on):
   4 small tiles, each fires a real `fetch` on mount and shows
   the ms + HTTP status. Common targets: `health`, `manifest`,
   `voice/flow`, `ask-ruby`. Use POST for routes that are not
   GET-safe (e.g. `voice/flow` is POST-only — a GET returns 404
   and looks like a real bug in the panel).
2. **Stack**: one line per layer.
3. **Tools**: count by kind, list each with a colored `live` /
   `disabled` / `stub` chip and the route + a one-line note.
4. **Secrets (booleans only)**: 2-column grid, same chip colors.
5. **Boundaries (deliberate, not bugs)**: bullet list, 6–10 lines.
6. **Endpoints**: collapsible `<details>` with the full route list
   (20+ entries is fine, just collapse by default).

Why a panel and not docs: the panel is **live** — latencies,
uptime, and tool kind are read on click. Docs go stale; a
`/api/manifest` endpoint cannot.

## 3. Playwright `setExtraHTTPHeaders` quirk

When using the Playwright MCP browser against an auth-gated URL
(Basic Auth, Bearer token, etc.), the browser blocks 401 before
the page renders. To get past it for a verification screenshot:

```js
// via browser_run_code_unsafe, since browser_navigate alone
// does not support setting headers per request
const b64 = 'cnVieTpydWJ5NDI5MQ=='  // base64('ruby:ruby4291') — hardcode
await page.context().setExtraHTTPHeaders({ 'Authorization': 'Basic ' + b64 })
await page.goto('https://<tunnel>/')
```

Pitfalls:

- `btoa` and `Buffer` are **not defined** in the Playwright
  unsafe-code sandbox context; hardcode the base64 string or use
  a precomputed constant.
- `setExtraHTTPHeaders` also applies to cross-origin font
  requests (Google Fonts in RTL Tailwind). Expect console errors
  about `Access-Control-Allow-Headers` for fonts — these are
  cosmetic, the page still renders.
- Chrome 146+ removed `user:pass@host` URL syntax. Do not try to
  navigate to `https://ruby:ruby4291@host/` — the browser will
  reject it before any header is sent.

## 4. Common port trap (recurring on the voice agent repo)

The voice-agent repo has both `src/` (root, often empty or docs)
and `backend/src/` (the real server). The `server.ts` that
listens on 8787 and 3030 lives under `backend/src/`. From the
repo root, `npx tsx src/server.ts` fails with
`ERR_MODULE_NOT_FOUND`. Always `cd backend` before starting
the backend process, and verify the port came up with
`ss -tlnp | grep <port>` before continuing.

The two ports are different services: 8787 is the voice/TTS/STT
backend; 3030 is the Hermes Ruby brain. Both can run
side-by-side from the same `backend/src/server.ts` with
`PORT=...`. Killing one does not kill the other.

## 5. Tunnel auth + frontend flow

The voice agent ships with a Vite plugin (`authGate`) that
gates the dev server behind Basic Auth using
`/root/<repo>/.ruby-auth.json` (`{"user":"...","password":"..."}`).

- The Vite gate also covers `/api/*` paths (the proxy is inside
  the gated dev server).
- The backend has **no** Basic Auth of its own; the Vite gate is
  the only gate. This is fine for a personal deploy because
  `cloudflared --url` strips `Authorization` headers, so backend
  Basic Auth would be decorative anyway. Document this in
  `boundaries` so reviewers know the threat model.
- For a production deploy, add backend Basic Auth (or a
  session-cookie check) in the same slice that introduces the
  production ingress; do not assume the Vite gate survives a
  switch to nginx/Cloudflare Access.
