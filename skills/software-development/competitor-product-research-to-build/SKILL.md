---
name: competitor-product-research-to-build
version: 1.0.0
description: "Research a 3rd-party product to plan a similar build. Covers 5-page read map, Hebrew deliverable, 5 build principles, MVP plan. Two modes: product (clone for users) and personal (Hermes-integrated). Trigger: 'תחקור את המוצר', 'איך אני בונה דבר כזה', 'research how this product works'. Anti-bot fetch via r.jina.ai proxy (validated 2026-06-24). NOT for pure academic research → deep-research-pro; NOT for security vet of repo to install → agent-repo-security-vetter; NOT for voice-agent security variant → references/voice-agent-mvp-research.md."
author: Hermes Agent (the user workflow)
license: MIT
metadata:
  hermes:
    tags: [research, competitor, build-plan, mvp, architecture, no-code, scraper, extension, saas, product-analysis, personal-build, hermes-integrated, tailscale-bridge, environment-probe, voice-agent, agent-boundary, security-model, install-risk]
    related_skills: [plan, deep-research-pro, spike, subagent-driven-development, requesting-code-review]
    absorbed_from: [voice-agent-mvp-research]
    note: "Voice-agent MVP research is now a labeled subsection below; see references/voice-agent-mvp-research.md for the deep variant methodology."
---

# Competitor Product Research → Build Plan

Use this skill when the user wants a **research deliverable that ends in a build plan**, not pure analysis. Typical ask: "research this product and tell me how I'd build something similar."

This is **research + build-planning**. No code is written in this turn. No installs. No `npm install`. The deliverable is a single Hebrew (or user's language) write-up that:

1. Names the product's actual architecture (not the marketing pitch)
2. Lists the technical internals that make it work
3. Includes a pricing / business model summary
4. Proposes 5 build principles
5. Lays out a 4-week MVP
6. Names what's cut from the MVP and parked in a roadmap
7. Ends with one explicit "what's next" question

The user then picks the next step: verify with a clone, run a spike, start slice 1 of the plan, or stop.

## When to use

- "תחקור את המוצר", "איך זה עובד", "איך אני בונה דבר כזה", "תחקור את האתר הזה"
- "research how this product works", "reverse-engineer the architecture"
- "I want to build something like X but for my use case"
- "clone the idea, not the code"
- "is it feasible for me to build this myself"
- "what would it take to build this from scratch"

## When NOT to use

- The user wants pure academic / topic research (e.g., "what's the state of fusion energy") → use `deep-research-pro`
- The user wants a security/install vet of an open-source repo they will install → use `agent-repo-security-vetter` (security) + `voice-agent-mvp-research` (architecture) — but only if the repo is a voice-agent; for non-voice repos, use `agent-repo-security-vetter` alone
- The user wants to **build** (not research) something they already know how to build → use `plan` or `subagent-driven-development`
- The user wants to **review their own code** → use `requesting-code-review`
- The user wants a **spike** to validate one specific idea before planning → use `spike`

## Two build modes: personal vs product

The "what would it take to build this?" question has two distinct flavors, and the deliverable should match:

**Mode A — Product-mode build** (default). The user wants to build a *thing* for the world / for users / for sale. The 5 reads → 1 deliverable shape applies as written. The build plan proposes a stack, an MVP, and a differentiator list. The user picks the next step.

**Mode B — Personal-mode build** (Hermes-specific, recurring). The user wants to build a *tool* for their own workflow, with **full integration with Hermes as the agent**. Trigger phrases: "תבנה לי ככלי פנימי", "I want this as a personal tool", "integrated with you as the agent", "with full bridge to my computer", "שימוש אישי בלבד", "personal-use only".

Mode B requires an **Environment Probe** BEFORE the 5 reads, because the build plan must respect what the user's machine and Hermes already have:

1. Probe Hermes host: Tailscale peers, SSH keys (`~/.ssh/hermes-laptop/`), MCP servers loaded, browser tools available, Vault layout.
2. Probe the user's machine (if reachable via Tailscale): OS version, installed browsers, Python/Node availability, AppData / `~` writable, registry write access.
3. Confirm the bridge works with one ping (e.g., `ssh [ssh-user]@laptop.tailce2378.ts.net "echo OK"`) before promising a personal bridge in the plan.
4. THEN run the 5 reads.
5. The build plan adds a section: **Hermes Integration Layer** — bridge direction (extension → Hermes, Hermes → extension, or both), Vault sync targets, two-way command surface, license/install path (Developer Mode vs unlisted store).

Mode B also typically forces smaller scope: "personal use" usually means one user, no billing, no team features, no cloud. The MVP shrinks and the differentiators shift from "better than the original" to "more useful for *my* workflow than the original is".

### Environment probe — Tailscale SSH on Windows

The recurring pattern: user says "I have a Tailscale bridge / SSH to my laptop". Before promising the bridge in the plan, probe it. The known Windows + Tailscale + Hermes quirks:

- `tailscale status` shows the user as `dizel.dz20@` (the human account), but the SSH login is `[ssh-user]@` (the Windows account). Default to `[ssh-user]@<hostname>.tail<...>.ts.net`, not the IP and not the human user.
- `scp` to the laptop is usually **blocked** by the SSH config. Transfer files by heredoc: `ssh ... "powershell -NoProfile -Command '<script>'"` or `cat local.ps1 | ssh ... "powershell -Command -"` — but escaping gets ugly fast. For multi-line scripts, write to a temp file on Hermes and use `ssh ... "powershell -Command \"[ScriptBlock]::Create((Get-Content -Raw 'C:\path\to\file.ps1'))\""`.
- The laptop is reachable at the FQDN (`laptop.tail<id>.ts.net`), not just the bare IP. FQDN survives IP changes; IP doesn't.
- For a full probe template that captures OS, browsers, Python/Node, registry write access, and existing Tailscale state, see `templates/hermes-environment-probe.ps1`.

### Environment probe — Hermes host

The recurring pattern: confirm what Hermes itself can do before designing an integration. Standard checks:

- `tailscale status` — peer list and IPs
- `ls ~/.ssh/hermes-laptop/` — should contain `id_ed25519` + `id_ed25519.pub`
- `ls ~/.[vault-runner]/[vault-runner].json ~/.hermes/config.yaml` — confirm config files exist
- `ss -tlnp` — what ports are listening (9443 = Hermes gateway, 8765 = Hermes API)
- `curl -s http://localhost:8765/<known-route>` — confirm the API is up (avoid `-k` insecure flag — just use HTTP for localhost)
- `tailscale ip -4` — the Hermes host's own Tailscale IP

See `references/tailscale-ssh-windows-bridge.md` for the full snippet.

## Core method (5 reads → 1 deliverable)

The deliverable has eight sections, each grounded in a specific read. The order matters: don't speculate about internals until you've read the changelog/blog for technical clues; don't speculate about pricing until you've read the pricing page; don't propose a build before you've read enough to know what the product actually *does* (vs what it *says* it does).

### Read 1 — Landing page (the pitch)

Purpose: understand the high-level claim. What's the product? What does the author say it does? Who's the target user? What use cases are highlighted?

For a **web product**:
- Open the landing page
- Capture: the one-line value prop, the feature grid, the use-case list, the social-proof block (review count, rating), the CTA

For a **Chrome extension** or **mobile app**:
- Same as above, plus: which store is it on, what's the rating, what's the install count

The landing page is marketing copy. It tells you what the author *wants you to think the product is*. Do not write the architecture section from this alone.

### Read 2 — Feature / product deep-dive pages

For every product, there are usually 2-5 sub-pages that go deeper than the landing page. For a Chrome extension with 5 sub-tools, that means 5 sub-pages. For a SaaS with 4 product lines, 4 sub-pages. Read them in this order:

1. The "main feature" page (what the product *does*)
2. The "secondary features" pages (what else it does)
3. The "how it works" / "use cases" page

For each, capture:
- The **headline** (one sentence per feature)
- The **3-step flow** (most product pages have a numbered "how to use" — these are the actual UX)
- The **named techniques** (e.g., "Smart List Detection", "Dynamic Extract", "AI-Powered Detection") — these are the algorithm names

### Read 3 — Pricing page (the business model)

Pricing pages tell you:
- The tier names (Free / Light / Starter / Pro / Max) and what each unlocks
- The unit of measurement (per page, per credit, per seat, per run)
- The local-vs-cloud split (what's free locally vs what requires the cloud)
- The integrations (webhooks, Zapier, n8n, Sheets, etc.)
- The lifetime-vs-subscription split

For a build plan, the pricing page tells you:
- **Which features are commodity** (any user can build in a weekend) vs **which need a backend** (require server infra, ML models, or a credit system)
- **What the unit of monetization is** (per page = a usage counter; per seat = a team concept; per run = a scheduling system)

### Read 4 — Blog + Changelog (the technical deep-dive)

This is the **most important** read. The blog and changelog reveal what the author actually built, in the author's own words. Specifically:

**Blog posts**:
- "How to scrape X" tutorials reveal the *target use cases* and the *patterns* the author supports
- "X vs Y" comparison posts reveal *what features the author considers differentiating* (anything they call out in a comparison is a feature they think matters)
- "Best tools for X" listicles reveal *the competitive landscape* — every other product mentioned is a competitor or an alternative

**Changelog** (gold mine):
- Each release note is a feature that was added or improved
- Pattern: "v2.3 — Better pagination. Detects when page content has changed instead of relying on a fixed delay" → tells you the **algorithm choice** (content-change detection vs fixed delay)
- Pattern: "v2.1 — Dynamic extract. Extracts from lists even if element selectors change" → tells you the **anti-fragility design** (not relying on stable CSS)
- Pattern: "v2.4 — Updated references from visualwebscraper → Ultimate Web Scraper" → tells you the **rebrand history** (acquired? renamed? pivoted?)
- Pattern: "v2.5 — Autoscroll for Google Maps" → tells you the **site-specific fixes** (Google Maps needs scroll-to-load)
- Look for: AI integrations, credit systems, scheduling systems, plugin systems, webhook systems — these are the *hardest features* to build

**Reading order**: latest changelog first (newest = what the author is most proud of), then blog posts that match the use cases you care about.

### Read 5 — Per-tool sub-pages (the implementation map)

For a multi-tool product, each sub-tool page usually has a "How it works" 3-step section. **These 3 steps are the implementation map.** For each step, ask: "what does the underlying code do?"

Example from Ultimate Web Scraper:
- "Step 1: Hover over a list" → content script injects mouseover listener, computes element-group on hover
- "Step 2: Click to select" → clicks trigger selector generation + DOM group query
- "Step 3: Export" → results in IndexedDB, export via PapaParse / SheetJS

The implementation map tells you:
- **Where the listening happens** (content script / background worker / page DOM)
- **Where the computation happens** (in-page JS / background / offscreen worker)
- **Where the storage happens** (localStorage / IndexedDB / cloud)
- **Where the export happens** (popup UI / download / API call)

## Deliverable format (Hebrew for the user)

The output is one chat message in the user's language with this structure. Use bullet lists, not tables (Telegram renders tables poorly). Use clear section headers. Keep total length 80-150 lines of chat — long enough to be useful, short enough to read in 60 seconds.

```markdown
## 🔍 מחקר מעמיק: <Product Name>

### מה זה בעצם
<one paragraph, 3-5 sentences, the headline finding, who made it, who uses it>

## הארכיטקטורה — <N> כלים פנימיים
<bullet list of the sub-tools / sub-products, with one line per tool and the algorithm name>

| כלי | מה הוא עושה | אלגוריתם מרכזי |
(for each: name, what it does, central algorithm)

## איך זה עובד טכנית (מה שהצלחתי להוציא)
<numbered list of the technical internals, with the *named techniques* from the changelog/blog>

**1. <technique name>**
- how it works, what algorithm, what data structure

**2. <technique name>**
...

## תמחור (להקשר)
<bullets: tier names, prices, what each unlocks, unit of measurement>

---

# 🛠️ תוכנית בנייה — כלי עצמאי עבורך

## עקרונות מנחים (5)
<numbered 1-5, each a concrete design rule for the new build>

## Stack מומלץ
<3 paths: full extension, MVP script, CLI — pick the one that fits the user's intent>

## MVP — 4 שבועות
<weekly milestones, each with 2-3 concrete tasks>

## Roadmap אחרי ה-MVP
<3-5 features that the original product has but the MVP cuts>

## הבדלים אפשריים (כדי לא להיות עוד "עוד <thing>")
<3-5 differentiators — ways the new build can be better than the original>

## שאלה לפני שמתחילים
<one explicit question: which path? which stack? which slice first?>
```

### Mode-B addendum: Hermes Integration Layer (personal build only)

When the deliverable is Mode B (personal, Hermes-integrated), add **one additional section** between "Roadmap" and "Differentiators":

```markdown
## 🔗 Hermes Integration Layer (the part that makes it YOUR tool, not another clone)

**Bridge direction**: <extension → Hermes only | Hermes → extension only | two-way>
**Transport**: <Tailscale + SSH native messaging | direct HTTPS to gateway | local IPC>
**Vault sync target**: <path under ~/[hermes-config-dir]/memories/Hermes/Brain/Recipes/...>
**Two-way commands**: <e.g., "I can ask the extension to open URL X" / "extension can ask me to extract all prices">
**Install path**: <Developer Mode load unpacked | unlisted Chrome Web Store | signed CRX sideload>
**License check**: <per-profile key | per-machine | none — any Hermes installation unlocks it>
```

The "What's next" question in Mode B is also different: it's not "which stack?", it's "shall I begin the Environment Probe and Stage 1 (Bridge) today, or park the build as a recipe and start with a different slice?"

## Pitfalls

### ❌ Stop reading after the landing page

The landing page is marketing copy. It tells you what the author *wants you to think the product is*. Do not write the architecture section from this alone. The architecture is in the sub-tool pages, the changelog, and the blog tutorials. **Read at least 5 pages** before writing the architecture section.

### ❌ Quote the marketing claims verbatim

A research deliverable that says "the product uses AI-powered detection" without explaining *what* AI technique, *what* the input/output, *what* the failure mode — is marketing copy with a research label. Always reframe claims into "the author claims X; the technique behind X is Y, implemented via Z."

### ❌ Skip the changelog

The changelog is the **single highest-density source of technical detail** on a product site. Every release note is a feature that was built. Skim 6-12 months of changelog. Look for: AI integrations, credit systems, scheduling, pagination algorithms, anti-fragility features (dynamic selectors, content-change detection), site-specific fixes (Google Maps, Amazon, etc.). Each one is a *deliverable* the author had to build, and a *task* for your MVP.

### ❌ Propose a clone, not a build

A "I'll just clone the source code" plan is not a research deliverable. The point of the research is to understand the *problem space* and propose a *new build* with the user's own constraints (language, stack, scale, time, budget). The original product is reference material, not the target.

### ❌ Confuse "pricing tiers" with "monetization"

Pricing tiers tell you what the author *charges for*. They do not tell you *what unit of cost* the backend has. A "per page" pricing tier usually means a backend with a queue, a worker pool, a credit counter, and a billing system. A "per seat" pricing tier usually means a team concept with a shared workspace, invites, and RBAC. The build plan needs to know *both*.

### ❌ Write a 200-line deliverable when the user asked for a build

The research is a *means* to the build plan. If the research is 200 lines and the build plan is 20 lines, the deliverable is upside-down. Default ratio: **40% research / 50% build plan / 10% next-step question**.

### ❌ Forget the "what's next" question

The deliverable is not done until it ends with **one explicit question** that gives the user a clear next action. Options:
- "Start with MVP in Python (Playwright) or jump straight to the Chrome extension?"
- "Which slice first: group detection engine, or the UI overlay?"
- "Do you want me to verify the architecture by reading the actual source code (need URL), or is the marketing/blog research enough?"

The user has the right to re-plan based on what the research surfaced. Do not auto-continue into build mode.

### ❌ Direct-curl docs sites that use Vercel/Cloudflare anti-bot — wastes 10 minutes on "verifying your browser"

Sites like `supabase.com/docs/...`, `vercel.com/docs/...`, and similar modern docs platforms put a Vercel Security Checkpoint ("We're verifying your browser") in front of every direct curl request. The HTML you get back is **a JavaScript challenge page, not the actual docs**. Symptoms: `curl -sL https://supabase.com/docs/...` returns content like `<p id="header-text">We're verifying your browser</p>` with a `data-astro-cid-...` token, no actual `<article>` or `<main>` content.

**The fix**: use `r.jina.ai/<url>` as the fetch proxy. It runs a real browser under the hood and returns clean Markdown, no JS challenge, no headless browser needed.

```bash
# ❌ Returns Vercel challenge page (not docs)
curl -sL "https://supabase.com/docs/guides/auth/social-login/auth-google"

# ✅ Returns clean Markdown of the same page
curl -sL "https://r.jina.ai/https://supabase.com/docs/guides/auth/social-login/auth-google"
```

The output starts with `Title: ...`, `URL Source: ...`, then `Markdown Content:` followed by the page as Markdown with code blocks preserved (`\`\`\`...\`\`\`` quoting). Concatenate multiple docs into one Markdown corpus:

```bash
for url in \
  "https://supabase.com/docs/guides/auth/social-login/auth-google" \
  "https://supabase.com/docs/guides/auth/social-login/auth-apple" \
  "https://supabase.com/docs/guides/auth/sessions"; do
  curl -sL --max-time 30 "https://r.jina.ai/$url" >> /tmp/all-docs.md
done
```

**Why this works**: jina.ai is a reader-as-a-service — it does the rendering, you get text. Same pattern works for any modern docs site hostile to direct scraping (Vercel, Cloudflare, Netlify docs). Try jina first; escalate to `playwright-mcp` only if jina also fails.

**Don't waste a subagent on it**: `delegate_task` with a research-heavy prompt ("go read 10 docs pages and synthesize") **times out at 600s** because the subagent hits the same wall, then tries playwright, then gets tangled in browser-automation troubleshooting. A 3-line `for url in ...; do curl r.jina.ai/$url; done` loop runs in 15 seconds and gives you the same content as Markdown.

**The lesson**: **fetch-then-read beats read-then-fetch for any research touching docs behind an anti-bot CDN.** Run the curl loop in the main thread, save the Markdown to `/tmp/all-docs.md`, then read it from your own context. Save `delegate_task` for synthesis ("here's a 200KB corpus, extract the X pattern"), not fetch. Validated 2026-06-24 during Supabase Auth research — 6 docs pages fetched in ~12 seconds total, zero timeouts.

### ❌ Skip the Environment Probe in Mode B (personal/Hermes-integrated build)

If the user said "personal tool, integrated with you as the agent", a build plan that proposes an SSH bridge, a Tailscale tunnel, an Edge install, or a registry write — *without first probing the actual environment* — is a fiction. The probe is part of the research. It establishes:
- Is the bridge actually reachable, or is the user *assuming* it works?
- Is the target browser already installed, or does the plan need an "install Chrome" prerequisite?
- Is Python / Node available, or does the plan depend on one being installed?
- Is there an existing `~/.ssh/hermes-laptop/` key, or does the user need to authorize one?

A "personal build" plan that says "I'll SSH to your laptop" when SSH is not actually configured is a 30-minute wasted conversation. Probe first. The probe is ~3 PowerShell commands and a `ssh ... echo OK`.

### ❌ Use the wrong SSH user for Tailscale on Windows

`tailscale status` shows the human account (`dizel.dz20@`), but the actual SSH login is the **Windows local account** — usually `[ssh-user]@` on a single-user Win11 box. Defaulting to the Tailscale-displayed user causes silent `Permission denied` and an hour of debugging. Always use `[ssh-user]@<hostname>.tail<id>.ts.net` on first try; fall back to other Windows local accounts only if that fails.

### ❌ Forget to update the FQDN discovery in the probe

The probe sequence on Hermes MUST include `tailscale status` and capture **the actual FQDN of the laptop** (`laptop.tail<8-char-id>.ts.net`), not the IP. Different Tailscale accounts get different `<id>` strings. Hardcoding the ID into a skill will rot within weeks. Always grep the output of `tailscale status` and store the FQDN as a runtime fact, not a documented constant.

### ❌ Promise a Python bridge when Python isn't installed

If the Environment Probe shows `python: not recognized` (Windows), the bridge host cannot be Python. Switch to Node.js without asking the user — Node is on every modern Windows dev machine, and the Chrome native messaging protocol is portable. The plan should say "Node.js bridge host, path: `C:\Users\administrator\AppData\Local\HermesBridge\bridge.js`" and move on.

### ❌ Use Hermes port 9443 for /api/scrappy/* endpoints

This is the trap that ate ~10 minutes of this session. **Hermes has two HTTP surfaces and they use different auth**:

- `http://localhost:8765/api/*` → `X-Jarvis-Token` header → `JARVIS_HUD_TOKEN` env var. **This is the one the bridge uses.**
- `https://localhost:9443/api/*` → separate JWT-based auth (`{"detail": "Unauthorized"}` response shape) → owned by the Hermes Dashboard proxy, NOT the Jarvis voice/HUD server.

A bridge that targets 9443 will get 401 with `{"detail": "Unauthorized"}` even with the right X-Jarvis-Token. The fix is to point the bridge at **8765, HTTP, with `X-Jarvis-Token`**. Validate this with `curl -s -H "X-Jarvis-Token: $JARVIS_HUD_TOKEN" http://localhost:8765/api/scrappy/health` and expect `{"ok":true,...}`. If you get 401 with `{"detail":...}` body, you're on 9443 — switch.

### ❌ Pass long base64 payloads inline through `powershell -Command`

The `Set-Content -Value ([Convert]::FromBase64String('<big-string>'))` pattern works for ~6kB and breaks around ~10kB because of Windows command-line length limits (~8k chars) and the fact that bash + SSH + powershell triple-quote interactions can corrupt the payload. **For files >6kB, use `scp` instead.** `scp` works fine on this Tailscale SSH config even when `cat` over SSH stdin does not. The scp flow:

```bash
scp -i ~/.ssh/hermes-laptop/id_ed25519 /tmp/bigfile.js \
    [ssh-user]@laptop.tail<id>.ts.net:staging-name.js
ssh -i ... [ssh-user]@laptop.tail<id>.ts.net \
    "powershell -NoProfile -Command \"Move-Item staging-name.js C:\\final\\path\\file.js -Force\""
```

For smaller config files (token JSON, registry fragments), `Set-Content` is fine. For JS bundles / binary blobs, scp.

### ❌ Run a `bridge.cmd` wrapper before testing the bridge in isolation

When developing the native messaging host, **test it as a raw Node.js child first**, before wiring the `.cmd` launcher. The launcher hides stdout from the Chrome Native Messaging stream, so you can't see the bridge's `bridge.ready` handshake in the wrapper. The smoke test pattern that works:

```javascript
// smoke2.js — run ON the laptop, not from Hermes
const { spawn } = require("child_process");
const child = spawn("node", [bridgePath], { stdio: ["pipe", "pipe", "pipe"] });
// ... write 4-byte-length-prefixed JSON to child.stdin, parse stdout frames
```

Spawn `node bridge.js` directly with `stdio: ["pipe","pipe","pipe"]`. Confirm `bridge.ready` arrives in <1s. THEN add the `.cmd` wrapper. Otherwise debugging the bridge in a real Chrome context is painful.

### ❌ Tell the user to "just load unpacked" on Edge 134+

Edge 134+ (mid-2025) **removed the Developer Mode toggle from `edge://extensions` UI**. There is no toggle, no "Load unpacked" button for a user to click. And even when the user reaches a "Load unpacked" dialog through some other path (e.g. `edge://policy` or a pre-Edge-134 version), Edge now requires a **signing private key (`.pem`)** to complete the load — without it, the dialog errors with "Include private key and try again" / "כלל מפתח פרטי ונעל".

If your Mode-B plan says "load unpacked in Developer Mode" on a modern Edge or Chrome, the user will get stuck. The fix is to **install the extension via Group Policy** instead. See `references/edge-extension-install-policy.md` for the full recipe (generate RSA key, add `"key"` to manifest, pack as CRX3, write HKLM Edge policy keys to force-install). This works on any Edge/Chrome version since 2018 and is the officially supported enterprise path.

When the **policy route fails** (most commonly because `file://` update URLs are silently blocked on Edge 134+), fall back to **`--load-extension` via a desktop shortcut**. See `templates/launch-edge-with-extension.ps1`. The shortcut's `Arguments` field takes the absolute path; Edge 149 honors it on launch.

### ❌ Misread a UI dialog in a non-English screenshot and told the user not to enter text there

In the Scrappy-Dood build, the user pasted a screenshot of the Edge "Load unpacked" dialog (in Hebrew), and I confidently misread it as a Microsoft Account sign-in prompt because the dialog had a password-masked field at the top. I told the user "don't enter your password there" — a wrong, scary instruction that wasted 10 minutes of clarification. The dialog was actually asking for the extension's root directory and a private key, both of which are normal extension-install inputs.

**The rule**: when the user pastes a screenshot of a UI you don't recognize, **never pattern-match to a known dialog from memory**. Instead:

- Use `vision_analyze` with a focused question — "read every Hebrew/Arabic/Thai/etc. label and button literally, do not infer meaning from layout" — and base the answer on the literal text.
- If the dialog is in a language you don't read, ask the user for the **page title** in the browser's address bar, or for them to translate the **two largest buttons**. The page title is the most reliable signal.
- If after two reads you still can't identify the dialog, **say so explicitly** and ask for translation — do not paper over uncertainty with a confident guess. A wrong confident answer wastes more user time than a transparent "I can't read this, what does it say?".

This is class-level, not Windows-specific. Applies to any time a user pastes a UI screenshot in a language or platform you don't recognize.

### ❌ Use HKCU for Edge extension policies

Edge's policy tree is **HKLM-only** for extension install. Setting `ExtensionInstallForcelist` under `HKCU\Software\Policies\Microsoft\Edge` is silently ignored — no error, no log line, the policy just doesn't apply. The user reopens Edge, the extension is still not there, and you spend an hour wondering why. Always write Edge policy keys under `HKLM:\SOFTWARE\Policies\Microsoft\Edge\`. Chrome is more flexible (HKCU works there), but for Edge: HKLM or nothing.

## Worked example: Ultimate Web Scraper (June 2026)

The full research deliverable is captured in
`references/ultimate-web-scraper-research.md`. The headline:

- **Product shape**: Chrome extension + cloud platform. 5 sub-tools (List, Web Page, Webpage Text, Image, Email). 80,000+ users. $9-$199/mo cloud pricing with a credit system (1 credit = 1 page).
- **Architecture (inferred from changelog)**: Content script for hover/click, background worker for coordination, IndexedDB for storage, offscreen worker for heavy DOM parsing, cloud platform for scheduled runs and AI features.
- **Named techniques from changelog**:
  - "Group Detection" (find sibling elements with similar structure)
  - "Dynamic Extract" (works even if CSS selectors change — structural similarity)
  - "Smart Pagination" (URL change / Load More / infinite scroll / Google Maps autoscroll)
  - "Content-Change Detection" (pagination triggers on content diff, not fixed delay)
  - "Credit System" (1 page = 1 credit, monthly reset)
  - "OpenAI Integration" (AI Page Unblocker, Data Labeling)
- **Build plan**: 4-week MVP starting with a Group Detection engine in TypeScript, then hover/click UI, then pagination, then export.
- **Differentiators proposed**: Hebrew-first, local-only by default, smart dedup, visual diff between runs.

That research took ~10 page reads (landing, pricing, blog, list-extractor, email-extractor, changelog, 2 deep blog posts) and produced a ~120-line Hebrew deliverable ending with one explicit question about MVP stack choice. No code was written, no install was started.

## Mode-B variant (June 2026 — "Scrappy-Dood")

A second session extended this research into **Mode B**: the user said "תבנה לי את זה ככלי פנימי שיתואם איתך כסוכן הרמס, שימוש אישי בלבד". The deliverable shape changed:

1. **Environment Probe ran first** (3 SSH commands + 1 PowerShell survey). Captured: Tailscale `[agent-vm-ip]` ↔ `[agent-vm-ip]` (laptop), SSH key `~/.ssh/hermes-laptop/id_ed25519`, Win11 Home build 26200, Edge installed, Chrome NOT installed, Node 24, no Python, no PowerShell 7. This is the data the build plan rests on.
2. **The 5 reads ran second** (same as Mode A).
3. **Deliverable added the "Hermes Integration Layer" section**: bridge direction (two-way, Tailscale + SSH native messaging), Vault sync target, two-way command surface, install path (Developer Mode, not Chrome Web Store).
4. **The "what's next" question changed**: from "which stack?" to "shall I begin Stage 1 (Bridge Foundation) now, or park the build as a Vault recipe and start a different slice?"

Key things that would have gone wrong without the probe:
- Plan said "I'll install Chrome" → probe showed Chrome not installed → switched to Edge.
- Plan said "Python bridge" → probe showed no Python → switched to Node.js bridge.
- Plan said "SSH as `dizel.dz20@`" → that user got `Permission denied` → switched to `[ssh-user]@<fqdn>` which worked.

The full Tailscale-SSH-on-Windows quirks (correct SSH user, FQDN, SCP blocked, PowerShell escaping) are in `references/tailscale-ssh-windows-bridge.md`. The probe script is in `templates/hermes-environment-probe.ps1`.

## Voice-agent MVP variant (security-focused research of a third-party voice agent)

The voice-agent case is a recurring variant of this skill: the user asks for a research write-up on a **specific open-source voice-agent project** they are considering installing alongside their existing voice agent. Same Hebrew deliverable shape, but the focus shifts from "build a clone" to **"is this safe to install, what does the agent actually own, where is the boundary"**.

When the user says "תחקור את ה-MVP", "research this voice-agent repo", "what does the agent actually own", "is this safe to install" — load `references/voice-agent-mvp-research.md` for the deep variant methodology. The variant has 6 sections in its deliverable (instead of 8):

1. **Agent boundary map** — where the pipeline ends and the agent begins; what the LLM sees, what it controls, what it cannot reach.
2. **Allowed/forbidden tool list** — explicit inventory of which tools the agent can call (and which are blocked).
3. **Security model** — auth proxy, signed URLs, scoped tokens, vault handling, TTS/STT isolation.
4. **Install risk** — what `git clone && npm install` actually touches, what config files it writes, what it would change in a running Hermes/voice stack.
5. **Comparison vs your existing voice agent** — feature parity, side-by-side architecture diff, "would I run both or replace".
6. **One-line verdict** — safe to install / fork first / don't install / needs more research.

The 5 reads differ slightly from the general competitor variant: instead of "landing page / features / pricing / changelog / sub-tools", the voice-agent reads are: README + ARCHITECTURE → plugin/registration code (the agent boundary) → auth proxy (security) → SETUP doc (install impact) → example sessions (how it's actually used in practice). See `references/voice-agent-mvp-research.md` for the full read map, the apology-signature patterns to detect (the agent claiming "I don't have previous context"), and the install-risks checklist.

When NOT to use this variant: the user wants to **build** a voice agent (use `spike` or `plan`); the user wants to **clone + push + install** a third-party voice agent (use `plan` with the 3-phase "from scratch" pitfall); the user has a specific voice bug to debug (use `[your-voice-product]-live-action-qa` / `elevenlabs-browser-audio-debugging`); the user just wants a security vet with no research (use `agent-repo-security-vetter`).

## Related skills

- `plan` — for the build slice that typically follows this research; the "the user kickoff overlay" is the same shape
- `deep-research-pro` — for pure academic/topic research without a build intent
- `spike` — when the user wants to spike-test one specific idea before full planning
- `subagent-driven-development` — for the actual build after the plan is approved
- `agent-repo-security-vetter` — if the product turns out to be open-source and the user wants to install and read the source
- `[your-voice-product]-product-squad` / `[your-voice-product]-live-action-qa` — for hands-on voice work AFTER the research (build/QA a voice pipeline, not research a third-party one)

## References

- `references/ultimate-web-scraper-research.md` — the full June 2026 research deliverable on the Ultimate Web Scraper Chrome extension, with the 5-page read map, the changelog-mined algorithm list, the 4-week MVP plan, and the differentiator list.
- `references/tailscale-ssh-windows-bridge.md` — Mode-B bridge guide. SSH user `[ssh-user]@` (not the Tailscale-displayed user), FQDN over IP, SCP-blocked workarounds, PowerShell escaping tricks, registry layout for native messaging hosts.
- `references/edge-extension-install-policy.md` — Edge 134+ removed Developer Mode UI and now requires a signing key even for unpacked installs. Use Group Policy `ExtensionInstallForcelist` + a pre-built CRX3 to deploy personal extensions without a Chrome Web Store listing. Covers key generation, manifest `"key"` field, deterministic ID computation, CRX3 packaging, and the policy script.
- `references/voice-agent-mvp-research.md` — the deep variant methodology for security-focused research of a third-party voice-agent open-source project. The 5 reads (README/ARCHITECTURE → plugin/registration → auth proxy → SETUP → example sessions), the 6-section deliverable (agent boundary, tools, security, install risk, comparison, verdict), and the apology-signature patterns. Use this when the user asks "תחקור את ה-MVP" / "research this voice-agent" / "is this safe to install".
- `references/voice-agent-cron-toolset-failure-diagnosis.md` — case study: a real voice-agent MVP research session that surfaced cron-toolset failures. Use as a worked example of the variant's failure-mode capture section.
- `references/voice-agent-[your-org]-jarvis-ai-mvp-analysis.md` — case study: a second real voice-agent MVP research session (the "[your-org] jarvis-ai" project). Use as a second worked example showing how the variant's 6-section deliverable maps to a real repo.
- `references/jina-reader-anti-bot-proxy.md` *(add 2026-06-24)* — the `r.jina.ai/<url>` proxy pattern for reading docs behind Vercel/Cloudflare anti-bot when direct curl returns a "verifying your browser" challenge. Worked bulk-fetch loop with verified URL list. Use whenever a research target is a modern docs site hostile to scraping.

## Templates

- `templates/hermes-environment-probe.ps1` — drop on the Windows laptop, run via SSH, captures OS / browsers / runtimes / Chrome profiles / HKCU write test / Tailscale state in one shot. Use before any Mode-B build plan that proposes a Chrome/Edge extension with a native messaging bridge.
- `templates/pack-crx.js` — dependency-free Node.js CRX3 packer. Signs an MV3 extension directory with an RSA key and emits a `.crx` file. Companion to `install-edge-extension-policy.ps1`.
- `templates/install-edge-extension-policy.ps1` — writes the HKLM Edge policy keys (`ExtensionInstallForcelist` + `ExtensionSettings` + `ExtensionInstallAllowlist`) so Edge force-installs the CRX on next launch. Edit the two variables at the top with the extension ID and the CRX path on the laptop.
- `templates/launch-edge-with-extension.ps1` — creates a desktop `.lnk` + `.bat` + Start Menu entry that launches Edge with `--load-extension` baked into Arguments. Use as a **fallback** when `ExtensionInstallForcelist` + `file://` is silently blocked on Edge 134+, or as the single-user alternative to the policy route. Edit `$extPath` at the top. Run as the user who will use the extension.
