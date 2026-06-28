# [your-org]/[your-product] — MVP Analysis (June 2026)

**Source:** https://github.com/[your-org]/[your-product]
**Commit analyzed:** `f013db7` "Holographic media panels + agent hud_display plugin; stability hardening (FD limits, port-safe stop, race-locked warm, stream closes); GPU STT deps; docs"
**License:** MIT
**Files:** ~25 source files, 1241-line core server, 87-line plugin, 367 lines of docs
**Research date:** 2026-06-12
**Researcher:** Hermes Agent
**Verdict (one line):** Voice pipeline shell over Hermes Agent. Safe to vet for install on a LAN-only server. NOT safe for production, English-only STT, requires port 443+8765+8642.

## 1. The 30-second pitch

"Iron-Man-style voice assistant and command center built on top of
[Hermes Agent](https://github.com/NousResearch/hermes-agent). Talk to
a real agent through a glowing arc-reactor HUD in any browser on
your LAN, or a push-to-talk client. Local Whisper STT, ElevenLabs
TTS, agent-summoned media panels, runs on your own hardware."

The author's own architecture diagram from the README:

```
 Browser HUD (any LAN device)          Host machine (tested on macOS / Apple Silicon)
 ── https/wss :443 ──────────┐   ┌──────────────────────────────────────┐
   mic · speaker · panels    ├──►│ voice pipeline server (this repo)    │
                             │   │  STT: faster-whisper (local, free)   │   ┌─────────────────┐
 Push-to-talk client         │   │  TTS: ElevenLabs Flash (streaming)   ├──►│ Hermes Agent     │
 ── ws :8765 ────────────────┘   │  HUD + auth + dashboard TLS proxy    │   │  API :8642 (lo)  │
                                 └──────────────────────────────────────┘   │  memory · tools  │
                                                                             │  skills · cron   │
                                                                             └─────────────────┘
```

Note the asymmetry: **one brain, many faces.** The pipeline is
additive; the agent is unchanged.

## 2. Agent boundary map

### What the agent (Hermes) owns — never touched by the pipeline

- **LLM provider** (whatever Hermes is configured to use; the
  pipeline only reads the API key from env, never the SDK)
- **All 80+ Hermes skills** (terminal, file edit, web search, etc.)
- **Persistent memory** (Hermes session DB, key `jarvis:user:main`)
- **Tool execution** (the pipeline forwards `tool.started` events
  to the HUD as a status, doesn't run tools itself)
- **Approvals** (Hermes decides when to ask; the pipeline just
  passes the card to the HUD and forwards the user's decision)
- **Personality / system prompt** (the user's `~/.hermes/SOUL.md`;
  pipeline injects an additional `instructions` field on top,
  see §3)
- **Cron, kanban, dashboards** (the pipeline proxies the dashboard
  over TLS so the HUD can iframe it; doesn't generate the data)

### What the pipeline ([your-product]) owns

- **STT** — `faster-whisper` local, `small.en` model, ~460MB
  downloaded on first run. GPU sidecar (`worker/stt_server.py`)
  optional, `large-v3-turbo` at ~0.2s/utterance with automatic
  local fallback when GPU machine is off.
- **TTS** — ElevenLabs `eleven_flash_v2_5` streaming, default
  voice chosen by user via `voice_id` in `server.yaml`. ~0.5
  credits/char.
- **WebSocket protocol** — `start` / `stop` / `stop_run` /
  `approval_decision` + binary int16 PCM. Barge-in cancels the
  active turn AND posts `stop_run` to Hermes.
- **HUD** — single-file `hud/index.html` in vanilla JS, no build
  step, served at `/hud/` over TLS.
- **Auth gateway** — JARVIS_HUD_TOKEN cookie, entered once per
  device. Set in `~/.hermes/.env`.
- **Dashboard TLS proxy** — separate uvicorn app on `:9443`
  reverse-proxies the Hermes dashboard, stripping
  X-Frame-Options/CSP so the HUD can iframe it.
- **Allowlist proxy** — `/api/hermes/*` only forwards to a
  hardcoded set of Hermes paths (see §4).
- **Secret filter** — 4 regex patterns redact API-shaped strings
  before TTS (see §4).
- **Machines panel** — local psutil stats + remote worker
  pollers (psutil/nvidia-smi via `worker/worker_stats.py`).

### What's borderline

- **Personality override** — the pipeline injects
  `hermes.instructions` into the session-level instructions
  (see `server.yaml:20-25` and the `_clean_for_tts` filter at
  `server.py:603-616`). The user's `SOUL.md` is still the base,
  but voice turns get an extra "no markdown aloud" / "no secrets
  aloud" / "speak numbers as words" layer.
- **Interrupt-aware barge-in memory** — when the user cuts off
  the agent mid-sentence, the pipeline records the last spoken
  sentence and prefixes the next turn's input with
  `[note: your previous spoken reply was cut off by the user
  after you said: "..."]`. This is the only "memory" the
  pipeline owns; everything else goes through Hermes.

## 3. What the agent can / cannot do (the actual tool surface)

The MVP adds **exactly two tools** to the Hermes agent, both
shipped in `hermes-plugin/hud_display/`:

### `hud_display` (file: `hermes-plugin/hud_display/tools.py:28-37`)

```python
def hud_display(args: dict, **kwargs) -> str:
    src = (args.get("src") or "").strip()
    if not src.startswith(("http://", "https://")):
        return json.dumps({"error": "src must be a full http(s) URL"})
    return _post({
        "media": args.get("media", "iframe"),
        "src": src,
        "title": (args.get("title") or "INCOMING FEED")[:48],
        "position": args.get("position", "center"),
    })
```

- **What it accepts:** `media` (video/iframe/image enum),
  `src` (http/https URL only), `title` (≤48 chars),
  `position` (center/left/right)
- **What it does:** POSTs to `http://127.0.0.1:8765/api/summon`,
  which broadcasts a `summon_panel` event to every WebSocket
  client (i.e. every open HUD tab).
- **What it CANNOT do:** no `file://` URLs, no `javascript:`,
  no `data:`, no local paths. The HTTP/HTTPS prefix is a
  hard guard.
- **Why the description matters:** the schema
  (`hermes-plugin/hud_display/schemas.py:11-21`) opens with
  "ALWAYS use this when the user asks to show, display, pull
  up, open, or put any media or webpage 'on screen'." Per
  the author's comment: "prose in SOUL.md cannot out-compete
  an attractive tool schema (the model kept opening pages in
  its own invisible browser); a real tool with an explicit
  description wins immediately."

### `hud_dismiss` (file: `hermes-plugin/hud_display/tools.py:40-41`)

```python
def hud_dismiss(args: dict, **kwargs) -> str:
    return _post({"action": "dismiss"})
```

- **What it does:** broadcasts `dismiss_panels` to all HUDs,
  clearing the screen.
- **What it accepts:** nothing (empty schema).

### What the agent does NOT gain

- No terminal access change (Hermes's own `terminal` tool still
  fires the approval flow).
- No file system access change.
- No web fetch change (the agent's own browser tool still
  opens pages invisibly — the plugin's description is
  specifically fighting against this default behavior).
- No new skills or tool plugins beyond the two above.

## 4. Hard boundaries drawn by the author

### Privacy filter before TTS (`server.py:93-98`)

```python
SECRET_RES = [
    re.compile(r"\b(?:api[_-]?key|secret|password|passwd|token|bearer|authorization)\b\s*[:=]\s*\S+", re.IGNORECASE),
    re.compile(r"\b(?:sk|pk|key|tok|ghp|xox[abp])[-_][A-Za-z0-9_\-]{12,}\b"),
    re.compile(r"\b[A-Za-z0-9+/_\-]{36,}\b"),          # long opaque blobs
    re.compile(r"-----BEGIN [A-Z ]+-----.*?-----END [A-Z ]+-----", re.DOTALL),
]
```

Anything matching these patterns in the agent's reply is
replaced with `" redacted "` before the text goes to
ElevenLabs. Plus a second filter
(`_clean_for_tts` at `server.py:603-616`) strips
`<think>` blocks, code blocks, markdown formatting, and
`http://` URLs. Defense in depth: the agent's instructions
say "don't speak secrets", the regex enforces it.

### Allowlist proxy between browser and Hermes
(`server.py:718-731`)

```python
ALLOWED_GET_PATHS = {
    "/health", "/health/detailed", "/v1/capabilities",
    "/v1/skills", "/v1/toolsets", "/api/jobs", "/api/sessions",
}

def _proxy_allowed(method: str, path: str) -> bool:
    if method == "GET":
        return path in ALLOWED_GET_PATHS or (
            path.startswith("/api/sessions/") and path.endswith("/messages")
        )
    if method == "POST":
        return path == "/v1/responses"
    return False
```

- The browser **cannot** directly call any other Hermes
  endpoint. Only the listed GETs + `POST /v1/responses`.
- Even the session data the HUD reads is limited to
  `/api/sessions/{id}/messages` — it can't list ALL sessions
  or hit the admin endpoints.
- The proxy is the only path from browser to Hermes. The
  API key is added by the server, not the browser.

### Origin check on WebSocket (`server.py:700-712`)

```python
ALLOWED_ORIGIN_HOSTS = {"jarvis.local", "jarvis", "localhost", "127.0.0.1"}
```

Browsers must hit the WebSocket from one of these origins
(configurable via `security.extra_origin_hosts`). Native
clients (Python PTT, e2e tests) skip the origin check
because they don't send an `Origin` header.

### Network bind (`server.yaml:53-58`)

- Plain `ws://` on `:8765` for the PTT client
- TLS `https://`/`wss://` on `:443` AND `:8766` for the HUD
- TLS dashboard proxy on `:9443`
- The README notes "wildcard bind (required for non-root port
  443 on macOS)" — this is a macOS-specific constraint.

### What's NOT in the security model

- No rate limiting on `/api/*` endpoints.
- No CSRF tokens (cookie auth is origin-checked instead).
- No audit log of who hit what (Hermes's own logs cover
  agent calls, not HUD calls).
- TLS is self-signed (`scripts/make-certs.sh`) — users have
  to manually trust `cert.pem` on every device.
- LAN-only by design; the README explicitly says "do not
  port-forward this to the internet."

## 5. The soft boundary (fallback path)

When the Hermes API is unreachable, the pipeline falls back
to a direct Anthropic API call. See
`stream_llm_events_sync` at `server.py:365-410`:

```python
try:
    # ... try Hermes sessions API ...
except Exception as exc:
    fb = (self.cfg.get("hermes") or {}).get("fallback_provider", "anthropic")
    if not fb:
        raise
    yield ("text", "Agent backend offline. Running in basic mode. ")
    provider = fb
```

What the user sees when fallback kicks in:
- Spoken: "Agent backend offline. Running in basic mode."
- The pipeline now calls Anthropic (or whatever
  `fallback_provider` is) directly with the same system
  prompt.
- **Lost in fallback:** memory (no session), tools (no
  Hermes tools available), approvals (no approval flow
  on direct Anthropic calls), `hud_display` plugin
  (the plugin is loaded by Hermes, not by the pipeline).

In fallback mode, Jarvis is effectively a thin
ElevenLabs wrapper around Claude with no memory, no tools,
and no personality continuity. **This is the soft boundary
of the agent.**

## 6. Install impact (specifically for the user's server)

| Concern | Value | Notes |
|---|---|---|
| Disk (deps) | ~1.0GB | `faster-whisper`, `silero-vad`, `RealtimeSTT`, `torch`, `fastapi`, `uvicorn`, `pyyaml`, `numpy`, `anthropic`, `requests`, `psutil`, `websockets`. All pip-installable. |
| Disk (model) | ~460MB | Whisper `small.en` downloaded on first STT run. |
| Disk (total) | ~1.5GB | Plus ~100MB for the ElevenLabs audio cache. |
| Bandwidth (first run) | ~600MB | All deps + model. |
| Port: 443 | **CONFLICT** | Caddy is already on `:443` (verified via `ss -tlnp`). Will need to either kill Caddy, change Jarvis to a different port, or add a vhost. |
| Port: 8642 | shared (intentional) | Hermes gateway is already on `:8642`. The pipeline calls it loopback-only, so this is fine, but both services must be up. |
| Port: 8765 | free | PTT client port. |
| Port: 8766 | free | TLS HUD alt port. |
| Port: 9443 | free | Dashboard TLS proxy. |
| Key: ELEVENLABS_API_KEY | required (TTS) | In `~/.hermes/.env`. |
| Key: API_SERVER_KEY | required (Hermes) | Already configured for existing voice agents. **Same key shared** with the rest of Hermes. |
| Key: ANTHROPIC_API_KEY | required (fallback) | Already configured. |
| Token: JARVIS_HUD_TOKEN | required (HUD auth) | New token, add to `~/.hermes/.env`. Format: `jarvis-<6 hex>`. |
| Service: systemd | NEW (Linux) | The upstream docs only have macOS launchd plists. Need to write a `jarvis-voice.service` unit. |
| Service: port 443 binding | needs root or CAP_NET_BIND_SERVICE | macOS allows wildcard for non-root low ports; Linux does not. The example.yaml comment notes this is a macOS hack. |
| Interference: Hermes session DB | shares | The pipeline persists `logs/hermes_sessions.json` keyed by conversation name (`jarvis-main`). Other agents' sessions live in Hermes's DB, not in the pipeline's state. |
| Interference: other voice agents | shares port 8642 | The pipeline only calls `127.0.0.1:8642`; the other voice agents do the same. No port collision on 8765/8766/9443. |
| STT language | **English only** | `language="en"` hardcoded at `server.py:309`. Hebrew would require a code change (swap to `ivrit.ai` Whisper or similar). |
| Browser | any modern | Safari/Chrome/Firefox. Mobile works (Add to Home Screen). mDNS-based LAN discovery (`jarvis.local`). |

## 7. Verdict

**Sandbox only** (or read-only research — that's what this
session was).

- The MVP is technically solid and the security model is
  reasonable for a LAN-only setup. The allowlist proxy,
  origin check, secret redaction, and plugin URL-prefix
  guards are all hard rules the author put thought into.
- The two-tool delta to Hermes is small and well-bounded.
  The agent doesn't gain terminal/file/network access it
  didn't already have.
- The fallback path is the real risk: a user who gets used
  to voice + tools + memory will silently lose all three
  when Hermes goes down, and the pipeline will say "running
  in basic mode" and keep going as if nothing happened.
- The English-only STT is a blocker for the user's existing
  Hebrew voice agents. A Hebrew STT swap is feasible but
  needs source change.
- Port 443 collision with Caddy needs a decision before
  install.

**For the install decision, name the slices:**

1. **Prereqs**: Python 3.11+ (have it), ~1.5GB disk, decide
   port 443 strategy (kill Caddy, move Jarvis to alt port,
   or vhost)
2. **Repo + config**: clone (already done at
   `dizeldz20-ux/Jarvis`), create `server/config/server.yaml`
   from example, pick ElevenLabs voice_id, set
   `hermes.conversation=jarvis-main`
3. **Service**: write `jarvis-voice.service` systemd unit
   (template in §8), bind to non-443 port, run as non-root
4. **Verify**: `curl` health check, browser load + cert
   trust, whisper model warm (~40s), typed chat smoke
5. **Smoke**: `scripts/jarvis-smoke.sh` for end-to-end
   audio turn (macOS only — Linux needs the analog)

## 8. Useful artifacts captured

- The full `server.py` is 1241 lines, all 1241 read.
- The `hermes-plugin/hud_display/` is 96 lines total
  (schemas.py 46 + tools.py 41 + __init__.py 9 + plugin.yaml
  6). Worth copying as a template for any "voice shell adds
  a tool to Hermes" pattern.
- The allowlist proxy at `server.py:718-751` is the right
  shape for any "browser → Hermes" wrapper.
- The privacy filter regex at `server.py:93-98` is reusable
  for any TTS-in-front-of-PIF project.
- The session persistence pattern (`logs/hermes_sessions.json`
  keyed by conversation name) is the simplest way to share
  the same Hermes session across voice + typed chat + PTT
  client.

## 9. The "what would I do differently" notes

If the user installs this, the install/operate changes I'd
suggest:

1. **Move STT to a GPU sidecar immediately.** The local
   `small.en` Whisper is ~0.3-0.5s per utterance on CPU;
   `large-v3-turbo` on a GPU box is ~0.2s with much better
   accuracy. Worth the second machine.
2. **Add Hebrew STT** (the upstream's English-only is a
   blocker for this user). Options: `ivrit.ai` Whisper
   fine-tune, or the `faster-whisper` he/i18n models. Both
   need a one-line code change at `server.py:309`.
3. **Set `language="auto"` for partial transcripts** (the
   final-transcription language is hardcoded, but the
   live `partials` could detect Hebrew from the first
   second and switch).
4. **Wrap the `scripts/jarvis-*.sh` in a Linux port.**
   The upstream scripts are macOS-only (use
   `lsof` + `pkill`, not `ss` + `pkill`; use
   `launchctl`, not `systemctl`).
5. **Replace the in-memory `_ELEVEN_CACHE` with a
   persistent cache.** Currently the ElevenLabs quota is
   cached in process memory; restart loses it. A JSON
   file with a TTL would be a 20-line patch.
6. **Add `/api/hermes/capabilities` to the allowlist
   only for the dashboard view.** Currently the dashboard
   iframe is proxied wholesale; the explicit
   capability-list call would let the HUD show a clean
   summary without exposing the full session tree.
