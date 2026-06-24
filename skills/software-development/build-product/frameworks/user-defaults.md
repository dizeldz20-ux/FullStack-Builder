# User Defaults — Stack, language, security, deployment

Load this ONCE at the start of every `/build-product` invocation. These are the working defaults — override ONLY when the user explicitly says otherwise.

<references>
Master defaults — see `@user-defaults.md`
@../SKILL.md (build-product entry point)
@../../incremental-hardening-refactor/SKILL.md (for hardening patterns)
@../references/agent-host-layout.md (machine layout — load BEFORE touching files)
</references>

---

## ⛔ The Three Rules (NON-NEGOTIABLE)

These three rules exist because operators have repeatedly asked the same questions in many sessions. **Violating them makes the workflow worse, not better.**

### Rule 1: SEARCH BEFORE YOU ASK

Before asking the user "where is X?" or "what's the path to Y?" — search first:

1. `@../references/agent-host-layout.md` — machine layout (this is the answer 90% of the time)
2. `~/.config/hermes/memories/Hermes/Brain/` — the user's curated memory
3. `~/projects/<workspace>/MEMORY.md`, `AGENTS.md`, `SOUL.md`, `USER.md`, `TOOLS.md` — workspace contracts
4. The project's own `<agent-config>.json` or equivalent — canonical config
5. `~/.config/<service>/` keys (read keys only, never values)

**Only ask the user if ALL of those return nothing.** When you do ask, include what you searched and what you found — that proves you tried.

### Rule 2: KNOW WHICH MACHINE YOU'RE ON BEFORE TOUCHING A FILE

The user typically has two machines:

- **Server** (where the agent runs) — paths start with `/root/...`, `/tmp/...`, or `/home/...`
- **Laptop** (the user's daily driver, often Windows) — paths start with `C:\...` or `C:/...`

Before `read_file`, `write_file`, `patch`, `terminal`, or any file op on a path you didn't write yourself in this session:

1. Does the path start with `/root/`, `/tmp/`, `/home/`, `/var/`? → Server, safe to touch from here.
2. Does the path start with `C:\`, `C:/`, `/c/`, `D:\`? → Laptop. **Do NOT touch from here** — the user must run it, or SSH first (if laptop is online via `tailscale status`).
3. Not sure? → Run `pwd` + `hostname` + `tailscale status` to confirm where you are.

### Rule 3: CONFIRM UNDERSTANDING BEFORE NON-TRIVIAL WORK

For any task that is not a single-step lookup or a one-line change, restate what you understood in ONE sentence and ask the user to confirm. Format:

> **"If I understand correctly: you want [X]. Right?"**

Not "is this clear?" Not "should I proceed?" — those are weak. **Restate what you heard** so the user can correct it cheaply if you misread.

**Trivial work** (skip this rule): single grep, single read, single bash one-liner, fixing a typo, answering a direct question.

---

## Example — How to apply these defaults to a new build

```text
Scenario: "Build me a voice agent that speaks Hebrew"

Defaults that apply (no question needed):
- Language: TypeScript (primary, web stack)
- Framework: Next.js (web)
- TTS provider: ElevenLabs (with `eleven_v3` for natural Hebrew)
- Auth: yes, because multi-user
- Managed HTTPS: yes, because login

Defaults to ask about:
- Frontend: web app vs. embedded in Telegram?
- Database: Postgres vs. SQLite?
- Voice persona: predefined name or custom?

Defaults to skip:
- CLI tooling (not a CLI project)
- Mobile-specific (web-first)
```

The defaults are starting points. The 5-question template in `tasks/new-product.md` Phase 0.2 captures what the defaults cannot.

---

## Language & stack defaults

| Layer | Default | Override only if user says |
|-------|---------|-----------------------------|
| Primary language | TypeScript | "in Python" / "in Go" / "in Rust" |
| Secondary language | Python | (already covered above) |
| Web framework | Next.js | "Vite + React" / "Astro" / "Svelte" |
| Desktop framework | Electron + FastAPI (Python backend) | "Tauri" / "native" |
| Mobile | PWA first, native only if asked | (rarely changes) |
| CLI | Node + commander / Python + typer | (rarely changes) |
| DB | Managed Postgres (Neon) for production; SQLite for local-only | "Supabase" / "PlanetScale" / "MongoDB" |
| Auth | Neon Auth | "Clerk" / "Auth0" / "Supabase Auth" |
| Supabase project | Free tier, EU-West (London) or Asia (Singapore) | Region requirements per user |
| LLM | OpenRouter keys (via Hermes) | "OpenAI direct" / "Anthropic direct" |
| STT | Deepgram (primary), OpenAI Whisper (fallback) | (voice products) |
| TTS | ElevenLabs (most voice products) | (voice products) |

---

## UI defaults

| Aspect | Default |
|--------|---------|
| Layout direction | RTL for Hebrew, LTR for English/code |
| Language | Hebrew-first UI text, English for code/commands |
| Design taste | Anti-slop (use `creative/impeccable` + `creative/taste-skill`) |
| Font (Hebrew) | Heebo / Assistant / Rubik (ask which) |
| Theme | Dark + light, system-detect |
| Accessibility | WCAG AA minimum |
| Mobile-first | Yes (most users use Telegram + phone) |

---

## Security defaults (NON-NEGOTIABLE)

| Rule | Why | What to do instead |
|------|-----|---------------------|
| **Never put secrets in code** | Git history is forever | env vars / secret manager |
| **Never put `DATABASE_URL` / service-role keys in frontend bundles** | Browser bundle is public | Server-side only, proxy through backend |
| **Never use `--headless` Chrome** | Hermes policy | Use `browser_navigate` tool |
| **Never modify `~/.config/hermes/config.yaml`** | Hermes policy | Use first-class tools |
| **Never run `systemctl` / `service` unless explicitly approved** | Red lines | First-class tools only |
| **Admin Console is always separate from user app** | Multi-product convention | `apps/admin-web` ≠ `apps/web` |
| **Backend owns DB/repository access** | Desktop apps are untrusted clients | Always proxy through backend API |
| **Verify by negation** (code present + absent) | Catches partial fixes | After every patch |
| **Reversible > irreversible** | User preference | Use `trash` over `rm` |
| **Supabase: ALWAYS enable RLS before first SELECT** | Tables are world-readable without it | `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` + policies |
| **Supabase: NEVER prefix `SUPABASE_SECRET_KEY` with `NEXT_PUBLIC_`** | Service role bypasses all RLS | Server-only, no public prefix |

### Supabase-specific security

| Scenario | What to use | What to NEVER use |
|---|---|---|
| Env var for client code | `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | `NEXT_PUBLIC_SUPABASE_SECRET_KEY` |
| Env var for server code | `SUPABASE_SECRET_KEY` (no prefix) | Anything in `NEXT_PUBLIC_*` |
| Reading current user (route protection) | `supabase.auth.getClaims()` — fast, no network | `supabase.auth.getSession()` (not validated) |
| Admin operations (server only) | Service role key in Server Actions / Route Handlers | Service role key in Client Components |
| Apple sign-in | Capture `user_metadata.full_name` on first sign-in | Trust that Apple will send the name again later |

**For full Supabase auth patterns and the 10 common pitfalls, load `supabase-auth-patterns` skill.**

---

## Deployment defaults

| Surface | Default hosting | Override if |
|---------|-----------------|-------------|
| User web app | **Cloudflare Workers** (auto-deploy via `cloudflare-deploy` skill) | "Vercel only" / "static only" / "local only" |
| Temp URL | `*.workers.dev` + Cloudflare Access (one-time PIN) | "no protection" (only for production with real auth) |
| Admin console | Separate `apps/admin-web` on its own Cloudflare Worker | (never combine with user app) |
| Desktop app | Electron + electron-builder | "Tauri" / "native" |
| Backend (custom logic) | Cloudflare Worker (API/edge function) | "managed HTTPS" / "Fly.io" / "Render" |
| Database | Neon Postgres (current direction) | Supabase migration still allowed |
| Voice agent backend | Hermes Agent backend (no Vercel dependency) | (voice products) |
| File storage | Supabase Storage (cross-cloud safe) | R2 (only if account has R2 permission) |

### Cloudflare deployment defaults

| Aspect | Default | Why |
|---|---|---|
| **Token location** | `~/projects/<workspace>/memory/.secrets/cloudflare.token` (perms 600) | Same pattern as Supabase / ElevenLabs — never in config |
| **Account ID** | `<your-cloudflare-account-id>` | Get from Cloudflare dashboard |
| **Workers subdomain** | `<your-subdomain>` (set on first deploy) | Free plan supports specific subdomains |
| **Access protection** | Always on for temp URLs | `*.workers.dev` is public by default |
| **Access method** | One-time PIN (built-in) | Zero setup, works immediately |
| **Custom domain** | Only when the user provides one | Free plan supports specific subdomains |
| **R2** | NOT used unless token has permission | Use Supabase Storage instead |
| **Rollback** | 1 command via `wrangler rollback <version-id>` | Every deploy is reversible |

**For full deploy flow**, see `cloudflare-deploy` skill. The build-product orchestrator auto-loads it at Phase 6 (new-product) or Phase 5.5 (build-feature).

---

## Git defaults

| Rule | Why |
|------|-----|
| **Verify focused tests → npm test → build/audit** | Standard pipeline |
| **Make clean commits after green steps** | Bisect-friendly |
| **State exact target remote before push** | Prevent wrong-remote push |
| **No force-push on shared branches** | Team safety |
| **Secret-scan before commit** (`gitleaks` if available) | Catch leaks early |
| **Pre-commit hook = tests + lint + format** | Catch issues before review |

---

## Communication defaults

| Channel | Format |
|---------|--------|
| Telegram | Hebrew, Markdown tables OK, code blocks inline |
| Hermes internal | English, terse, evidence-based |
| Long reports | Save to `.hermes/plans/` or Vault, summarize in chat |
| File artifacts | Save locally, share absolute path |
| 3+ patches | One copy-paste script, not step-by-step |

---

## Workflow defaults

| Aspect | Default |
|--------|---------|
| TDD | RED-GREEN-REFACTOR, vertical slices, never horizontal |
| Plan granularity | 2-5 min per task |
| Commit cadence | After every green step |
| Scope creep | Half-slice rule, then quarter-slice, then 1-line |
| Stuck detection | 15 min on same blocker → mandatory `systematic-debugging` |
| Subagent model | Fresh context per task, 2-stage review |
| Approval gates | Reversible = auto with note; irreversible = explicit ask |
| Code review | `requesting-code-review` before any non-trivial merge |
| Smoke test | Real interaction, not just unit tests |
| Final report | What changed + what remains + exact verify commands |

---

## When in doubt

| If unsure about... | Ask the user | Or default to |
|-------------------|-------------|---------------|
| Stack | "What stack?" | TS/Next.js web, Electron+FastAPI desktop |
| Auth | "Need auth?" | Yes if multi-user; no for local-only |
| Managed backend | "production auth/billing?" | Yes → managed HTTPS backend; No → local-only |
| Design | "Who is the user?" | The user themselves first → Hebrew RTL UI |
| Deploy | "Where to production?" | Managed HTTPS (VPS/Fly/Render/Railway) |

---

## What this file is NOT

- Not a substitute for the user saying what they want
- Not an excuse to skip the "ask if unclear" path
- Not a license to ignore project-specific `AGENTS.md` files

Always read the project's `AGENTS.md` (if exists) before applying these defaults — project rules override these defaults.
