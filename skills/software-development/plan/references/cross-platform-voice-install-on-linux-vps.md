# Cross-Platform Voice Agent Install on Linux VPS

Worked example: installing **[your-org]/[your-product]** (a voice + HUD
pipeline shell over Hermes Agent, macOS-Apple-Silicon-targeted in
its docs) on the user's Ubuntu 24.04 VPS. Captured June 2026.

This is the **install phase** (phase 3) of the "clone + push +
install" workflow. The clone + push phases are covered by the
main `plan` skill's "3-phase version of 'from scratch'" pitfall.
This reference covers what happens after that, when the user
finally says "go install."

## Why this reference exists

The upstream SETUP.md is for macOS. Following it verbatim on
Linux fails at 4-5 places. The pattern that worked: read the
SETUP doc end-to-end, do a platform diff, do a port collision
check, get consent for the heavy pip install, then run install
slices with the right substitutes. The "right substitutes" are
below.

## Platform-diff substitutions (macOS → Linux)

Every line the upstream SETUP or scripts assumed macOS:

| macOS command | Linux substitute | Why |
|---|---|---|
| `launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/X.plist` | systemd unit at `/etc/systemd/system/X.service` | No launchd on Linux |
| `launchctl kickstart $U/$s` | `systemctl start X` | Same |
| `launchctl bootout $U/$s` | `systemctl stop X` | Same |
| `lsof -ti tcp:$port -sTCP:LISTEN` | `fuser -n tcp $port 2>/dev/null` or `ss -tlnp \| grep ":$port " \| awk '{print $7}' \| grep -oP 'pid=\K[0-9]+' \| head -1` | No lsof by default; fuser is the standard substitute |
| `pkill -9 -if "server\.py"` | Same (works on both) | — |
| `ipconfig getifaddr en0` | `ip -4 addr show eth0 \| awk '/inet /{print $2}' \| cut -d/ -f1` | en0 is the macOS Wi-Fi interface; on Linux pick the right one with `ip` |
| `tls_ports: [443, 8766]` | `[8766]` (only) | Port 443 typically bound by Caddy or nginx on Linux VPS; macOS lets non-root bind low ports but Linux does not |
| `host: 0.0.0.0` (wildcard bind for non-root 443) | `host: 0.0.0.0` is fine, but no need for the macOS-specific wildcard trick | The wildcard-bind-trick-for-non-root-ports is macOS-only |
| `StandardOutPath`/`StandardErrorPath` (in plist) | `journalctl -u X` (systemd captures stdout/stderr) | No equivalent; systemd is better |
| `mDNS .local` (`jarvis.local`) | Avahi, OR use the server's static IP (LAN/Tailscale) | Don't depend on mDNS for a VPS; the IP is more reliable |
| `port 443 wildcard bind` (zero-config for browsers) | Front Caddy with a virtual host, or use a self-signed cert on a non-443 port + `extra_origin_hosts` in server.yaml | The 443 assumption is macOS-friendly but not portable |
| `brew install ...` | `apt install ...` | — |
| TCC permissions, Full Disk Access | Not applicable on Linux | — |

## Pre-install checks (run all 4, paste output in chat)

```bash
# 1. Disk + RAM + CPU — is there room?
df -h / | head -2
free -h
nproc

# 2. Critical deps already present?
which ffmpeg gcc make uv python3.11
dpkg -l 2>/dev/null | grep -E "libasound2-dev|portaudio19-dev|libssl-dev|libgomp1" | head -5

# 3. Port + service collision check
ss -tlnp 2>/dev/null | grep -vE "::1|127.0.0.53" | head -30
for port in 443 8642 8765 8766 8767 9119 9443 18789; do
  pid=$(ss -tlnp 2>/dev/null | grep ":$port " | grep -oP 'pid=\K[0-9]+' | head -1)
  [ -n "$pid" ] && echo "port $port: PID $pid" || echo "port $port: free"
done

# 4. Agent backend (Hermes, etc.) reachable and keys present?
curl -s -o /dev/null -w "Hermes :8642 → HTTP %{http_code}\n" \
  --max-time 3 http://127.0.0.1:8642/health
test -f /root/.hermes/.env && echo "/root/.hermes/.env exists"
```

For the Jarvis-specific case the output is:
- Disk: 105GB free ✓
- 11GB RAM, 6.6GB available ✓
- 6 CPU cores ✓
- All Python build deps present ✓
- Port 443: bound by Caddy (proxy to 9119 dashboard + 8642 Hermes + 18789 [vault-runner] + 8 other routes)
- Port 8642: bound by Hermes (intentional, will be shared)
- Port 8765/8766/9443: free
- Hermes `/health` returns 200, `ELEVENLABS_API_KEY` + `API_SERVER_KEY` already in `~/.hermes/.env`

## The install slice order (8 slices, each verifiable)

1. **System deps** — `apt install libasound2-dev portaudio19-dev
   ffmpeg libgomp1 libssl-dev python3-dev`. Usually all present
   on a Python-friendly VPS; verify with `dpkg -l` first.
2. **Clone** — `git clone https://github.com/<user>/<repo>.git
   /opt/<name>`. Add `upstream` remote pointing to the source
   URL so future updates are one `git fetch upstream && git
   merge upstream/main` away.
3. **Venv** — `uv venv --python python3.11 /opt/<name>/server/.venv`.
   Use uv (fast); falls back to `python3 -m venv` if uv missing.
4. **Deps** — `uv pip install --python .venv/bin/python fastapi
   'uvicorn[standard]' requests pyyaml numpy anthropic RealtimeSTT
   faster-whisper silero-vad websockets psutil torch --index-url
   https://download.pytorch.org/whl/cpu`. **This is the slice
   that needs explicit consent and background execution** (see
   sub-pitfall C in the main plan skill).
5. **Config** — copy `server/config/server.example.yaml` to
   `server.yaml`, edit: change `tls_ports: [443, 8766]` →
   `[8766]`, set `dashboard_proxy.port: 9443`, set voice
   `voice_id` from ElevenLabs. Server stays on 8765 for plain
   ws push-to-talk client.
6. **Certs** — adapt `make-certs.sh` to use `ip addr show eth0`
   instead of `ipconfig getifaddr en0`. Generate self-signed
   cert with the server's external IPs in the SAN
   (e.g. `IP:45.67.221.96,IP:[agent-vm-ip]`).
7. **HUD token** — `python3 -c "import secrets; print('jarvis-' + secrets.token_hex(3))"`
   → `JARVIS_HUD_TOKEN=jarvis-XXXXXX` appended to
   `/root/.hermes/.env`. Restart Hermes gateway so the new
   env var is picked up.
8. **Plugin** — `cp -R hermes-plugin/hud_display ~/.hermes/plugins/`,
   edit the plugin's `schemas.py` to replace `YOUR_HOST` with
   the server's actual hostname/IP, then `hermes plugins enable
   hud_display` and restart the gateway.
9. **Systemd unit** — `/etc/systemd/system/jarvis-voice.service`:
   - `ExecStart=/opt/jarvis/server/.venv/bin/python /opt/jarvis/server/server.py`
   - `EnvironmentFile=/root/.hermes/.env`
   - `WorkingDirectory=/opt/jarvis/server`
   - `Restart=on-failure`
   - `RestartSec=5`
   - `User=root` (the user account, not literally root)
   - `WantedBy=multi-user.target`
10. **Start + verify** — `systemctl daemon-reload && systemctl
    enable --now jarvis-voice && systemctl status jarvis-voice`,
    wait ~40s for Whisper model warm (first run downloads
    ~460MB), then `curl -s http://127.0.0.1:8765/health` and
    the HUD health endpoint, then Playwright-navigate to the
    HUD URL and confirm it renders.

## Common failure modes (learned from the [your-org]/[your-product] session)

- **`dpkg was interrupted, you must manually run 'dpkg --configure -a' to correct the problem`** on a fresh Ubuntu
  container. Fix: `export PATH="/usr/local/sbin:/usr/sbin:/sbin:/usr/bin:/bin:$PATH"; dpkg --configure -a`, then
  retry `apt install`. Common in containerized VPS where
  root's PATH is minimal.
- **`uv pip install` foreground with 300s timeout → "BLOCKED: Command timed out"**. The consent gate, not an error.
  Pre-flight the install size, ask via `clarify`, then run
  in `background=true, notify_on_complete=true` mode.
- **Hermes gateway health 200 but `/api/sessions/{id}/chat/stream` returns 404 immediately**. The session id
  cached in `server/logs/hermes_sessions.json` is stale (DB
  reset, profile switch, gateway restart). The MVP code
  already handles this with a one-shot `force_new` retry —
  do not pre-emptively wipe the state file.
- **`uvicorn` complains about `ssl_certfile`** when `tls_cert` /
  `tls_key` paths in server.yaml don't exist. Fix: run
  `make-certs.sh` first; the `main()` function silently
  falls back to plain HTTP if the cert files are missing.
- **First startup takes 60-90s for torch import + model
  download**. `systemctl status` will show "activating" the
  whole time. Do not interpret this as a hang. Wait, then
  check the journal for "Whisper model loaded" or similar.
- **`uv pip install --index-url https://download.pytorch.org/whl/cpu fastapi torch` → "No solution found: fastapi was not found in the package registry"**. The
  `--index-url` flag *replaces* the default PyPI index, so
  non-torch packages resolve against an empty index. Use
  `--extra-index-url https://download.pytorch.org/whl/cpu`
  (note: **extra** not **index**) so PyPI stays primary and
  PyTorch is the fallback. Same gotcha applies to any
  multi-source dep (e.g. `--index-url` with cu118 for CUDA
  builds). Verified June 2026 on the [your-org]/[your-product]
  install — cost a wasted install and a real "consumed 1
  minute of user trust" before the error was caught.

## Shell-scripting gotchas around the install (June 2026, [your-org]/[your-product])

These three are **silent** and burn 5+ minutes of debugging
each time when writing install automation. None of them
belong in the upstream skill — they are agent-side, not
project-side:

- **Bash history expansion eats `$KEY` / `$TOKEN` in heredocs
  and inline `$(...)`**. Writing
  `KEY=$(grep '^API_SERVER_KEY=' ~/.hermes/.env | cut -d= -f2)`
  inside a heredoc or inline `cat > file <<EOF` will expand
  `!` references in `$KEY` and produce `*** /dev/null` or
  `bash: syntax error near unexpected token` errors. Three
  fixes that work: (a) write the script to a file with
  `write_file` and let the shell run it untouched, (b)
  `set +H` at the top to disable history expansion, (c) the
  simplest: `cat <<'EOF'` (with quotes around EOF) so the
  heredoc body is taken literally. The cross-call pattern
  that *always* works: dump the secret to a temp file in
  one command, then `$(cat /tmp/secret)` from the next:
  `python3 -c "..." > /tmp/jarvis_token` then
  `curl -H "X-Jarvis-Token: $(cat /tmp/jarvis_token)" ...`.
- **Playwright `browser_navigate` to a self-signed cert URL →
  `NET::ERR_CERT_AUTHORITY_INVALID`** and no interactive
  way to accept. For visual verification of a freshly
  installed HUD: use `curl -sk` to fetch the HTML and check
  the `<title>` / response size / a known DOM string, not
  the browser. The browser tool is for trusted certs only.
  (This is a constraint of the browser tool itself, not
  the install — the user has to trust the cert on their
  own device to see it for real.)
- **Reading the auth token from `~/.hermes/.env` with
  `grep ... | cut -d= -f2` in a one-liner** — the value
  can contain shell-special characters. Cleaner pattern:
  use a small Python one-liner to extract and write the
  token to `/tmp/<name>`, then `$(cat /tmp/<name>)` from
  the next shell call. Avoids inline shell expressions
  that may break on edge-case values like `!` in the key.

## What this reference does NOT cover

- The upstream `hermes-plugin/hud_display` installation
  details. The `hermes-config-validation` skill covers plugin
  registration and config-key validation against the installed
  Hermes source. Load that if the plugin fails to load.
- The agent-boundary research (what the MVP exposes to the
  agent, what's private to the pipeline). That's the
  `voice-agent-mvp-research` skill — load it BEFORE phase 1
  of the workflow, not at install time.
- Cross-platform desktop client (push-to-talk) — the
  `client/client.py` works on both macOS and Linux with no
  changes, but a VPS install typically doesn't need it (the
  browser HUD is the client).

## Adding a cloud STT provider (e.g. Groq) with local-Whisper fallback

Once the local install is verified end-to-end, a common next
ask is "swap the STT to something faster / multilingual."
The pattern that works for any voice pipeline that already
has a local STT path (Whisper, Vosk, etc.) is to add a
**cloud STT as primary with auto-fallback to local**. The
five concrete steps, in the order they matter.

### Step 1: Wrap raw PCM in a WAV header (mandatory for any HTTP STT API)

Cloud STT APIs (OpenAI, Groq, Deepgram, AssemblyAI) take a
**containerized** audio format — WAV, MP3, WebM, FLAC — not
raw int16 PCM. The voice pipeline gets PCM off the
WebSocket. Bridge the gap with a 44-byte WAV header:

```python
import struct

def _pcm_to_wav(pcm: bytes, sample_rate: int = 16000,
                channels: int = 1, sample_width: int = 2) -> bytes:
    """Wrap raw int16 LE PCM in a minimal canonical WAV header."""
    data_size = len(pcm)
    return (
        b"RIFF"
        + struct.pack("<I", 36 + data_size)
        + b"WAVE"
        + b"fmt "
        + struct.pack("<IHHIIHH", 16, 1, channels, sample_rate,
                      sample_rate * channels * sample_width,
                      channels * sample_width, 16)
        + b"data"
        + struct.pack("<I", data_size)
        + pcm
    )
```

**Pitfall:** the standard-library `wave` module wants a file
object, not bytes; `pydub` is heavy. The 8-line struct version
above is the right tool. Verified June 2026 on the
[your-org]/[your-product] Groq integration — 64KB of raw PCM
becomes 64KB + 44 bytes, decodes cleanly with `ffprobe`.

### Step 2: Add a provider switch in the existing remote-STT function

Don't fork the pipeline. The MVP already has an
`_remote_stt(audio, remote)` function with the "remote
config block → optional local fallback" shape. Extend it to
recognize the cloud API by URL or by an explicit
`provider:` field, and make sure **any failure returns
`None`** so the caller's main `transcribe()` falls through
to the local Whisper path automatically:

```python
def _remote_stt(self, audio: bytes, remote: dict) -> str | None:
    provider = (remote.get("provider") or "").lower()
    is_cloud = provider in ("groq", "openai") \
        or "groq.com" in (remote.get("url") or "") \
        or "openai.com" in (remote.get("url") or "")
    if is_cloud:
        api_key = os.environ.get(remote.get("token_env",
                                            "GROQ_API_KEY"), "")
        if not api_key:
            return None   # signals fallback to local
        try:
            sample_rate = int(remote.get("sample_rate",
                                self.cfg["stt"].get("sample_rate", 16000)))
            wav = self._pcm_to_wav(audio, sample_rate=sample_rate)
            files = {"file": ("audio.wav", wav, "audio/wav")}
            data = {
                "model": remote.get("model", "whisper-large-v3-turbo"),
                "response_format": "json",
            }
            if remote.get("language"):
                data["language"] = remote["language"]  # "en"|"he"|None=auto
            if remote.get("prompt"):
                data["prompt"] = remote["prompt"]      # context hint
            headers = {"Authorization": f"Bearer {api_key}"}
            r = requests.post(remote["url"], files=files, data=data,
                              headers=headers,
                              timeout=float(remote.get("timeout", 8)))
            if r.ok:
                return (r.json().get("text") or "").strip()
            print(f"[stt.remote] {provider} HTTP {r.status_code}: "
                  f"{r.text[:200]}", flush=True)
        except Exception as exc:
            print(f"[stt.remote] {provider} error: {exc}", flush=True)
        return None   # any failure → main transcribe() falls to local
    # ... legacy raw-octet-stream local GPU worker path ...
```

**Two key shape decisions:**

- **Return `None` on any failure** (no key, HTTP error, JSON
  parse). The caller's `transcribe()` then falls through to
  the local Whisper path automatically — no extra logic
  needed for the fallback to work.
- **Log the error reason** (HTTP code, exception) so the
  user can tell from the journal whether the cloud STT is
  being attempted, succeeding, or silently failing.

### Step 3: Config in `server.yaml` — keep the local model as the fallback

```yaml
stt:
  model: small.en           # LOCAL fallback (used only if remote errors)
  device: cpu
  compute_type: int8
  sample_rate: 16000
  partials: true
  partial_interval: 1.2
  # Primary STT path: Groq hosted Whisper
  remote:
    provider: groq
    name: groq-whisper
    url: https://api.groq.com/openai/v1/audio/transcriptions
    model: whisper-large-v3-turbo
    token_env: GROQ_API_KEY
    timeout: 8
    sample_rate: 16000
    # language: en        # omit for auto-detect, "he" for Hebrew, "en" for English
    # prompt: "Voice commands to a personal assistant, lowercase."
```

**Why keep the local model in the config** even after adding
the cloud path: the existing `transcribe()` function reads
`stt.model` for the local fallback. If you remove it, the
fallback breaks. The cloud and local paths are not
mutually exclusive in the config — they coexist.

### Step 4: Prove the fallback works (the URL-break smoke test)

The non-obvious verification: **deliberately break the
cloud URL and confirm the local path kicks in**. Without
this test, you don't actually know the fallback is wired
correctly — the cloud might be failing silently and the
user thinks they're using the cloud.

```bash
# Save working config
cp server.yaml server.yaml.bak
# Break the URL — point to a path that 404s
sed -i 's|/audio/transcriptions|/THIS-DOES-NOT-EXIST|' server.yaml

systemctl restart jarvis-voice && sleep 5

# Send a fake turn; check that timing shows local model
# (expect stt_model: "small.en" and stt_finalize: ~3-5s on CPU)
/opt/jarvis/server/.venv/bin/python /tmp/jarvis-smoke-stt.py
#   [4/4] done
#   stt_model: small.en                ← fallback worked
#   stt_finalize: 4.6006s              ← CPU Whisper, slow

# Restore
cp server.yaml.bak server.yaml
systemctl restart jarvis-voice && sleep 5

# Re-run; expect cloud model + sub-second STT
/opt/jarvis/server/.venv/bin/python /tmp/jarvis-smoke-stt.py
#   [4/4] done
#   stt_model: remote:groq-whisper     ← cloud is back
#   stt_finalize: 0.2929s              ← ~10x faster
```

If the first run still shows `remote:groq-whisper` with
HTTP 200, the URL is being cached somewhere — check
`uvicorn` workers, env reload, and `systemctl daemon-reload`
to bust the config.

### Step 5: Verify the API key in the same env the service uses

The key has to be in the env the systemd unit sees, not
just in the shell. Three patterns that work, in order of
reliability:

1. **`EnvironmentFile=/root/.hermes/.env`** in the systemd
   unit (cleanest; same source as Hermes itself).
2. **Source the file in a wrapper script** the unit calls.
3. **`Environment="GROQ_API_KEY=***` in the unit itself
   (visible in `systemctl show`; least secure).

**Do not** rely on "the shell that started the service
happened to have the key" — the key is invisible to the
service after a clean restart, and the smoke test passes
because the env was inherited at boot, but the next
restart breaks. Verified failure mode June 2026.

### Performance expectations (cloud vs local)

| Backend | Latency (per utterance) | Multilingual | Cost (per audio hour) |
|---|---|---|---|
| Local `small.en` on CPU | 1.5–5s | English only (model) | free |
| Local `large-v3-turbo` on GPU | ~0.2s | multilingual | free + GPU power |
| Groq `whisper-large-v3-turbo` | **0.28–0.30s** | 100+ languages | ~$0.04/hr |
| OpenAI `whisper-1` | 0.5–1s | multilingual | $0.36/hr |

Cloud STT breaks even with a GPU sidecar at ~30 hours of
voice per month (Groq) or never (OpenAI). For a personal
voice agent used a few hours a day, Groq is the right
default; keep the local Whisper as the offline fallback.

### Gotchas specific to the [your-org]/[your-product] patch (June 2026)

These three emerged from the actual Groq integration and
are **not** in the upstream project:

- **`patch` tool can mangle f-string secrets.** When the
  diff contains `f"Bearer {api_key}"` and `api_key` happens
  to look like a sensitive pattern, the patch-rendering
  layer may replace it with `***REDACTED***` (literal
  asterisks), producing a `SyntaxError: unterminated string
  literal` on the next `python -c "ast.parse(...)"`. Always
  `read_file` the patched region and grep for `REDACTED`
  before restarting the service. If hit, re-patch the line
  with the literal `api_key` token, not the rendered form.
- **Bash history expansion (`!`) in heredoc bodies.** If the
  test script for the smoke test contains a literal `!` (or
  if `!` appears in a `Bearer` token, which it shouldn't,
  but does in some provider formats), `cat <<EOF` (without
  quotes) will try to expand it and fail. Use `cat <<'EOF'`
  or write the script via `write_file` instead of `cat <<EOF`.
- **Self-signed cert refusal from the browser tool.** When
  visual-verifying a freshly-installed HUD, the Playwright
  `browser_navigate` to a self-signed HTTPS URL fails with
  `NET::ERR_CERT_AUTHORITY_INVALID` and there is no
  interactive "Proceed anyway." For the install phase, use
  `curl -sk` to fetch the HTML and check the `<title>` and
  response size, not the browser. The browser is for trusted
  certs only.

## Browser-side audio contract: HUD's 16 kHz lock (jarvis-specific)

`[your-org]/[your-product]`'s `server/hud/index.html` is a
single-file vanilla-JS HUD. The `AudioContext` sample rate
is hardcoded to **16000 Hz** in BOTH directions. This is
not a configurable knob — it is a property of the
AudioContext itself and the worklet code. The relevant
places in the HUD:

- **Input (mic → server)**: line 521,
  `new AudioContext({sampleRate: 16000})` and the
  `pcm16k` AudioWorklet processor at line 546 with a
  box-filter downsampler that targets 16 kHz on the way
  out. Browser also calls `getUserMedia({audio: {sampleRate:
  16000, ...}})` at line 578.
- **Output (TTS → speakers)**: line 535,
  `audioCtx.createBuffer(1, f32.length, 16000)` decodes
  TTS PCM at 16 kHz. If the TTS provider returns 22050 or
  24000 Hz, the browser plays it back at 16 kHz sample
  rate, which sounds **slower and lower in pitch** (~37%
  slowdown for 22050→16000).

**Implication for TTS config:** `voice.output_format` in
`server.yaml` MUST be `pcm_16000` regardless of which
ElevenLabs model is selected, even though `eleven_v3`
and `eleven_multilingual_v2` happily produce 22050/24000
Hz. The correct setting is `pcm_16000`. If you find
yourself typing `pcm_22050` "because the ElevenLabs docs
recommend it for `eleven_v3`," STOP — the HUD will play
it back at the wrong speed. This was almost shipped in the
June 2026 install and was caught only by reading
`hud/index.html` after the `pcm_22050` change.

**Implication for STT config:** the HUD also expects the
mic to deliver 16 kHz. The browser will downsample
internally, so cloud STT providers should be told
`sample_rate: 16000` to match. Groq and OpenAI both
auto-detect the rate from the WAV header, so this is
advisory rather than required, but explicit is better.

## ElevenLabs model selection for Hebrew (and other non-English)

Three relevant models, in order of quality for Hebrew /
multilingual:

| Model | Hebrew quality | Cost (~per 100 chars) | Notes |
|---|---|---|---|
| `eleven_flash_v2_5` | **No** (English only) | ~0.5 credits | Cheapest, fastest. The upstream MVP default. Will mangle Hebrew. |
| `eleven_multilingual_v2` | Good | ~1 credit | Proven multilingual, 29 languages including Hebrew. |
| `eleven_v3` | **Best** (most expressive, intonation, emotion) | ~1 credit | 70+ languages, most expressive. The right choice for Hebrew TTS. |

The decision: if the user speaks only English,
`eleven_flash_v2_5` is fine. For Hebrew (or any other
non-English), pick `eleven_v3` (or `eleven_multilingual_v2`
if `eleven_v3` is too expensive). The June 2026 install
on the user's server uses `eleven_v3` with voice
`pNInz6obpgDQGcFmaJgB` (Adam) and produces natural Hebrew
speech at ~3.9s for a 2-sentence reply.

**Do NOT** keep `eleven_flash_v2_5` in the config "to save
money" once the user has asked for Hebrew — the TTS will
fail silently or produce gibberish. Switch the model at
the same time as the language.

## Groq STT `prompt` field for language priming

The Groq Whisper API accepts a `prompt` field that primes
the model with context. For multilingual use this is
**much** more effective than relying on `language` alone:

```yaml
stt:
  remote:
    provider: groq
    language: he
    prompt: "שיחה עברית עם עוזר אישי קולי בשם Jarvis. המשתמש מדבר בעברית טבעית, משפטים קצרים, ללא markdown."
```

Why it helps:
- **Sets the expected script + dialect** — without the
  prompt, Whisper-large-v3-turbo on a Hebrew utterance
  sometimes outputs English transliteration or mixed
  scripts.
- **Constrains style** — the prompt can ask for
  short, conversational replies (relevant for STT bias
  toward terse phrasings, less relevant for the LLM).
- **Improves named-entity recognition** — names,
  product names, and code-switched words (English tech
  terms inside Hebrew sentences) are recognized more
  reliably when primed with a prompt that mentions them.

The prompt should be in the same language the user is
expected to speak. For mixed Hebrew/English, write it in
Hebrew but mention that English terms may appear
("משתמש עלול להחליף לאנגלית למונחים טכניים").
