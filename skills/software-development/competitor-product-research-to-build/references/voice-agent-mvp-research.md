---
name: voice-agent-mvp-research
description: Use when the user asks to deep-dive on a third-party voice-agent open-source project (a voice shell over an existing agent) — what the MVP exposes, where the agent boundary lives, what tools the agent can and cannot call, what the security model is, and what an install would touch. Trigger phrases include "תחקור את ה-MVP", "מה הגבולות של הסוכן", "איזה כלים הוא משתמש", "research the agent boundaries", "is this safe to install", "what does the agent actually own", "voice pipeline vs agent". Produces a research deliverable in the user's language (Hebrew for the user) with agent boundary map, allowed/forbidden tool list, security model, install risks, and a one-line verdict.
version: 1.0.0
author: Hermes Agent (the user workflow)
license: MIT
metadata:
  hermes:
    tags: [voice-agent, research, mvp, deep-dive, agent-boundary, security-model, hermes-shell, elvenlabs, stt, tts, plan, install-risk]
    related_skills: [plan, agent-repo-security-vetter, safe-public-repo-push, hermes-config-validation, spike, [your-voice-product]-product-squad, [your-voice-product]-live-action-qa, elevenlabs-browser-audio-debugging]
---

# Voice-Agent MVP Research

Use this skill when the user wants a **research deliverable** (not a
build, not a clone, not a patch) on a third-party open-source
voice-agent project. Typical ask: "research this voice-agent MVP
and tell me where the agent ends and the pipeline begins, what
tools the agent can use, what the install will touch, and whether
it's safe to run alongside my existing voice agents."

This is **research only**. No `npm install`, no `pip install`, no
builds, no test runs. Read code, summarize in Hebrew, surface
risks, propose next step. The user decides whether to install.

## When to use

- "תחקור את ה-MVP של הסוכן", "מה הגבולות של הסוכן", "איזה כלים
  הוא משתמש", "איפה היוצר שם גבולות"
- "research this voice-agent repo end to end"
- "what does the agent actually own vs the pipeline"
- "is this safe to install on my server"
- "compare this voice shell to my existing Ruby / final-voice-agent"
- "show me the security model and the API boundary"
- Before a build/clone-and-install decision on a third-party
  voice-agent project (often paired with `plan` for the
  install slices, or `agent-repo-security-vetter` for the
  pre-push vet)

## When NOT to use

- The user wants to **build** a voice agent, not research one
  → use `spike` or `plan`
- The user wants a **clone + push + install** workflow
  → use `plan` (with the 3-phase "from scratch" pitfall)
- The user wants to **review their own voice agent code**
  → use `requesting-code-review`
- The user has a **specific voice bug** to debug
  → use `[your-voice-product]-live-action-qa` /
    `elevenlabs-browser-audio-debugging`
- The user is **configuring** an existing voice agent
  → use `hermes-config-validation`
- The user just wants to **vet** the repo for safety, no research
  → use `agent-repo-security-vetter`

## Core method (5 reads → 1 deliverable)

The deliverable has six sections, each grounded in a specific
file or read. The order matters: don't speculate about agent
boundaries until you've read the plugin/registration code;
don't speculate about security until you've read the auth
proxy; don't speculate about install impact until you've
read the SETUP doc.

### Read 1 — README + ARCHITECTURE

Purpose: understand the high-level claim. What's the pitch?
What does the author say the agent can/can't do? What's the
target user?

```bash
# 1. README (orientation)
gh repo view <owner>/<repo>
# 2. ARCHITECTURE doc (deep)
gh api repos/<owner>/<repo>/contents/docs/ARCHITECTURE.md --jq '.content' | base64 -d
# 3. Directory layout (one-pass)
gh api repos/<owner>/<repo>/git/trees/main?recursive=1 | jq -r '.tree[].path' | head -100
```

Capture: the agent boundary claim, the architecture diagram,
the directory structure. These tell you what the author
**says** is the boundary.

### Read 2 — main server/pipeline code (the heart)

For a FastAPI/Express/Hono voice pipeline, the heart is the
WebSocket handler and the route table. Read in this order:

1. **Config** (`server/config/*.yaml` or `*.example.yaml`) —
   what providers does the pipeline bind to? Where do
   LLM/STT/TTS keys come from? What's the fallback hierarchy?
2. **Route table** (every `@app.get/post/websocket` /
   `router.get/post`) — what endpoints does the browser call?
   Which proxy to the underlying agent, and which are local?
3. **WebSocket handler** — the realtime protocol. What types
   of messages? Barge-in? Stop? Approval? How does the
   pipeline turn a transcript into an LLM call?
4. **The LLM call** — what API surface does it hit? Sessions?
   /v1/chat/completions? Direct SDK? What's the fallback
   when the agent is down?
5. **The TTS call** — what provider, what model, what
   voice_id, streaming or batch?
6. **The STT path** — local model, GPU sidecar, or cloud?
   What language(s)? What triggers a final transcription?

For each, note the file:line so the user can verify.

### Read 3 — Hermes/agent integration code (THE boundary)

This is the **most important** read. For voice agents built
on top of an existing agent framework (Hermes, LangChain,
custom), find the code that talks to the agent and read it
line by line:

- **Where does the pipeline POST the transcript?** Is it the
  Sessions API, /v1/responses, /v1/chat/completions, or a
  direct SDK call?
- **What headers does it send?** Does the agent's API key
  ever leave the server? Is there a proxy? Is there a
  scoped/downgraded key?
- **What events come back?** Are tool events streamed? Are
  approval events surfaced? Are run ids exposed (stoppable)?
- **What's the allowlist?** Does the browser hit the agent
  directly, or only through a proxy with a hardcoded path
  allowlist? If a proxy, which paths are allowed (GET) vs
  denied (POST)?
- **What does the agent NOT see?** Does the agent see the
  raw mic audio? The TTS audio? The browser cookie? The
  TTS provider key? The STT provider key?

The boundary is the most important question: **does the
agent own the personality, or does the pipeline override
it?** The answer is in the system prompt injection or the
`instructions` field on the LLM call.

### Read 4 — Plugin/tool registration (the agent's capabilities)

If the repo ships a plugin/module that the agent can
register as a tool, read it in full. This is what the agent
**adds** to its existing capability set:

- `hermes-plugin/<name>/tools.py` — handlers (what does
  the tool actually do?)
- `hermes-plugin/<name>/schemas.py` — JSON schema + the
  tool's "description" (this is what makes the model USE
  the tool; forceful description = model uses it often)
- `hermes-plugin/<name>/plugin.yaml` — what toolsets,
  what version
- `hermes-plugin/<name>/__init__.py` — `register(ctx)`
  hook

For each tool, capture:
- **Name** — e.g. `hud_display`, `hud_dismiss`
- **What it does** — one sentence
- **What can be passed in** — params, types, enums
- **What can NOT be passed in** — hardcoded URL prefix
  checks, side-effect restrictions
- **Side effects** — what does the tool change? Network
  calls? State? HUD broadcasts?
- **Why the description matters** — the model uses the
  tool because the description tells it to. Forceful
  descriptions ("ALWAYS use this when...") override prose
  in SOUL.md.

### Read 5 — security model + auth

Look for the hard rules:
- **Browser → server auth** — cookie? token? origin check?
- **Server → agent auth** — does the API key live in env?
  In config? Does it reach the browser?
- **Allowlist proxy** — what paths? what methods?
- **Origin check on WebSocket** — which hosts are allowed?
- **Network bind** — 127.0.0.1 only? 0.0.0.0? Wildcard?
- **Secret filter** — what regexes are applied to the
  transcript/TTS text before it leaves the server?
- **TLS** — self-signed? Behind a tunnel? mDNS for LAN
  only? `LAN-only by design` is a feature, not a bug —
  call it out as a constraint.

### Read 6 — SETUP.md + TROUBLESHOOTING.md (install impact)

For the install question, the SETUP doc tells you exactly
what `pip install` / `npm install` will pull, what ports
will be claimed, what model files will be downloaded, and
what the known failure modes are. Read in full.

## Deliverable format (Hebrew for the user)

The output is one chat message in Hebrew with this structure.
Use bullet lists, not tables (Telegram renders tables poorly).
Use clear section headers. Keep total length 80-150 lines of
chat — long enough to be useful, short enough to read in 60
seconds.

```markdown
## 🎯 תשובה קצרה — הגרעין
<one paragraph, 3-5 sentences, the headline finding>

## 🧭 איפה בדיוק עובר הגבול — <Agent> ↔ <Pipeline>
### שייך ל-<Agent> (לא נוגעים, לא משנים, רק צורכים)
- bullet list of what the agent owns (LLM, memory, skills, tools)

### שייך ל-<Pipeline> (ה-pipeline)
- bullet list of what the pipeline owns (STT, TTS, WebSocket, HUD, auth)

## ✅ מה הסוכן רשאי לעשות (הכלי/ים שמוסיף ה-MVP)
- for each tool: name, what it does, what it accepts, side effects

## 🚫 מה הסוכן אסור לעשות (גבולות שהיוצר צייר)
- privacy filter, scope rules, approval requirements, fallback rules

## 🔐 איפה ה-Auth וה-Proxy שמים גבולות בין <Client> ↔ <Agent>
- cookie/token, allowlist proxy, origin check, secret redaction

## 🧩 תרשים הרשאות — מה רואה מי
- which component sees the mic, the LLM, the API key, the session id, the TTS provider

## 🛠️ מה ה-MVP לא כולל (החתכים שזיהיתי)
- what's cut, missing, or limited (English-only STT, single user, no wake word, etc.)

## 📦 סיכום קובץ-קובץ
- table-like bullet list: file → role → size

## 🎯 מסקנה אישית לקראת ההתקנה אצלך
- the user's existing services, port conflicts, key collisions, model download size
- 1-2 sentence verdict: "מתאים / לא מתאים / מתאים בתנאי ש-X"

## רוצה שאמשיך להתקין?
- close the loop with an explicit question
```

## Pitfalls

### ❌ Stop reading after the README

The README tells you the pitch. The ARCHITECTURE doc tells
you the plan. **Neither tells you what the code actually
does.** The boundary between agent and pipeline is in the
HTTP client, the SSE parser, the WebSocket handler, the
plugin's `__init__.py`. Read those. The agent boundary
section of the deliverable is the most important — if you
write it from the README alone, the user gets marketing
copy, not analysis.

### ❌ Skim the plugin directory

The plugin is **the entire delta** the voice agent adds to
the underlying agent framework. It's usually 50-200 lines
total. Read it in full. Capture: tool names, schemas, what
parameters are allowed, what the tool ACTUALLY does in the
handler (a `hud_display` tool that POSTs to a local URL
is a one-liner; capture that one-liner verbatim with
file:line).

### ❌ Confuse "agent boundary" with "process boundary"

The agent and the pipeline might be in the same Python
process, the same venv, the same loopback HTTP call. That
doesn't mean the agent "owns" the personality. The
personality lives in the system prompt or instructions
field passed to the LLM. If the pipeline injects its own
instructions ("no markdown aloud"), the agent's SOUL.md is
overridden for voice turns. Capture that.

### ❌ Ignore the fallback path

The fallback path is where the "agent" disappears. When
Hermes is down, most voice agents fall back to a direct
LLM call (Anthropic SDK, OpenAI SDK) with no memory, no
tools, no approvals. This is the **soft boundary** of the
agent — when the agent backend is offline, the pipeline
becomes a thin text-to-speech wrapper. Always capture:
- What's the fallback provider?
- What does the fallback lose? (memory? tools? approvals?
  voice personality?)
- What does the user see when fallback kicks in?

### ❌ Miss the install-impact analysis

The research deliverable is incomplete without the
"what happens if I install this" section. The user needs
to know:
- Disk: how much will `pip install` / `npm install` pull?
- Bandwidth: which model files get downloaded on first run?
  How big?
- Ports: which ports does the service claim? Are any
  already in use on the user's server?
- Keys: which env vars does the service need? Does it
  share keys with existing services?
- Services: does it need systemd? launchd? A specific
  init system?
- Interference: does it share a session DB? A config
  file? A port? A model directory?

### ❌ Speculate about security without reading the proxy

The most common mistake: claiming "this is unsafe" because
the README mentions "LAN-only." LAN-only IS the security
model — it's not a missing feature. The proxy code, the
allowlist, the origin check, and the secret filter are
where the actual boundaries are. Read them.

### ❌ Recommend install without naming the slices

If the verdict is "OK to install", name the slices:
1. Prereqs (deps, ports, keys)
2. Config (server.yaml, .env)
3. Service (systemd unit or equivalent)
4. Verify (health check, smoke test, browser load)
The user wants to verify each slice ran, not approve one
big install. Same rule as `plan` skill's "Multi-slice
plans need per-slice approval."

## Worked example: [your-org]/[your-product] (June 2026)

The full research deliverable is captured in
`references/[your-org]-jarvis-ai-mvp-analysis.md`. The
headline:

- **MVP shape**: voice pipeline shell over Hermes Agent.
  No new agent — the brain is Hermes itself, called via
  Sessions API at `127.0.0.1:8642`.
- **Two tools added by the plugin** (`hermes-plugin/hud_display`):
  `hud_display` (open URL as holographic panel) and
  `hud_dismiss` (close all panels). That's it. The agent
  retains all 80+ Hermes skills unchanged.
- **Hard boundaries drawn by the author**:
  - Secret redaction before TTS (4 regex patterns)
  - URL-prefix allowlist on `hud_display` (http/https only)
  - Browser never gets Hermes API key (proxy strips it)
  - Allowlist proxy between browser and Hermes
  - mDNS/LAN-only by design
- **Soft boundary** (fallback): when Hermes is offline, the
  pipeline falls back to direct Anthropic API calls — no
  memory, no tools, no approvals. Effectively becomes a
  TTS wrapper.
- **Install impact** on the user's existing setup:
  - Disk: ~1.5GB (Python deps + Whisper model ~460MB)
  - Port conflicts: 443 (Caddy), 8642 (Hermes gateway) —
    443 needs decision; 8642 is shared (intentional)
  - ElevenLabs key: required (TTS only)
  - Hermes API key: required (loopback, already configured)
  - STT language: English only (`language="en"`)
  - systemd unit needed (macOS launchd in upstream docs)

That research took 6 file reads (1241-line server.py,
87-line plugin, 175-line SETUP.md, 112-line ARCHITECTURE.md,
80-line TROUBLESHOOTING.md, 77-line example.yaml) and
produced the deliverable above. Total time: ~10 minutes
of code reading + 5 minutes of writing. No code was
modified, no install was started, the user got the
research and decided the install slices on their own.

## Related skills

- `plan` — for the 3-phase "clone + push + install" workflow
  that often follows this research
- `agent-repo-security-vetter` — for the red-flag scan
  that should run BEFORE this research if the user is
  about to install
- `hermes-config-validation` — when the user IS installing
  and needs to verify config keys against installed Hermes
  source
- `[your-voice-product]-product-squad` — for the existing voice
  agent work this research typically compares against
- `spike` — when the user wants to spike-test a
  specific voice component, not research a whole repo

## References

- `references/[your-org]-jarvis-ai-mvp-analysis.md` — the
  full June 2026 research deliverable on the Jarvis
  voice shell, with file:line citations, the
  agent-boundary map, the allowlist proxy code, the
  fallback analysis, and the install impact for
  the user's server (port conflicts, deps size, key
  requirements)
- `references/cron-toolset-failure-diagnosis.md` — when a
  cron job that worked yesterday fails today with "no
  web access" or "[SILENT]", this is the first place to
  look. Covers the `enabled_toolsets` wiring trap, the
  `web_search` requires `terminal` rule, the
  self-diagnostic NOTE pattern, and the back-dating
  trick to force an immediate re-run.

**Cross-skill pointer:** the *install phase* (phase 3)
that follows this research is covered by the
`plan` skill at
`references/cross-platform-voice-install-on-linux-vps.md`
— the macOS→Linux substitution table, the
4-line port/service-collision check, the systemd unit
template, the 10-slice install order, the failure
modes, the cloud STT swap (Groq/OpenAI) with
local-Whisper fallback, the HUD 16kHz lock, the
ElevenLabs model selection for Hebrew, and the Groq
`prompt` field for language priming. Load `plan` once
the user has approved the "go install" step.
