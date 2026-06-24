# Hermes v0.16.0 — TTS Built-in Dispatch Functions

This is the source-of-truth reference for what config keys each TTS provider **actually reads**. The data comes from `~/.hermes/hermes-agent/tools/tts_tool.py` in Hermes v0.16.0 (2026.6.5, upstream `63a421d4`).

If a future Hermes release changes a dispatch function, re-grep this file and update the entries below. The skill's "Round 2 — read the dispatch code" discipline is the durable rule; the contents of this file are a snapshot.

## ⚠️ TTS is an internal agent-tool, not a public endpoint

If you are building a web UI on top of Hermes and want voice
output, **do not look for a "Hermes TTS endpoint."** It does not
exist in the public surface.

- `hermes` CLI subcommands do **not** include `tts` /
  `text-to-speech` / `speak`. The TTS dispatch lives in
  `tools/tts_tool.py` and is called **from inside an agent turn**
  when the agent invokes the `tts` tool.
- The Hermes API server on `:8642` (when running) exposes
  OpenAI-compatible `/v1/chat/completions`. It does **not**
  expose a TTS-only route.
- Therefore a thin "browser → backend → Hermes → audio" pipeline
  **cannot be built by calling Hermes for the audio.** The
  pattern that works is:

```
[Browser] → POST /api/voice/turn
              │
              ▼
[Your backend] → ask Hermes (LLM) → [reply text]
              │
              ▼
[Your backend] → call provider directly (ElevenLabs/MiniMax/etc.)
              → return OGG/Opus to browser
```

Call the provider directly from your backend using the same
config keys Hermes would have used (`tts.elevenlabs.voice_id`,
`tts.elevenlabs.model_id`, etc.) but do **not** route through
Hermes for the audio step. Hermes will think; your backend
speaks.

This constraint does **not** apply to Hermes-gateway-driven
voice (Telegram, WhatsApp, etc.) because there the gateway
itself calls the `tts` tool from inside the agent turn.

## Built-in names

From `tools/tts_tool.py::BUILTIN_TTS_PROVIDERS` (around line 350–360):

```
edge, elevenlabs, openai, minimax, gemini, mistral, xai, neutts, kittentts, piper
```

These names are reserved. A `tts.providers.<name>` command-type provider or a `TTSProvider` plugin cannot shadow them — see `agent/tts_provider.py` and the built-in-wins enforcement at registration time.

## Defaults (constants at top of `tts_tool.py`)

| Constant | Value |
|---|---|
| `DEFAULT_PROVIDER` | `"edge"` |
| `DEFAULT_ELEVENLABS_VOICE_ID` | `"pNInz6obpgDQGcFmaJgB"` (Adam) |
| `DEFAULT_ELEVENLABS_MODEL_ID` | `"eleven_multilingual_v2"` |
| `DEFAULT_ELEVENLABS_STREAMING_MODEL_ID` | `"eleven_flash_v2_5"` |
| `DEFAULT_OPENAI_MODEL` | `"gpt-4o-mini-tts"` |
| `DEFAULT_OPENAI_VOICE` | `"alloy"` |
| `DEFAULT_OPENAI_BASE_URL` | `"https://api.openai.com/v1"` |
| `DEFAULT_MINIMAX_MODEL` | `"speech-02-hd"` |
| `DEFAULT_MINIMAX_VOICE_ID` | `"English_expressive_narrator"` |
| `DEFAULT_MINIMAX_BASE_URL` | `"https://api.minimax.io/v1/t2a_v2"` |
| `DEFAULT_MISTRAL_TTS_MODEL` | `"voxtral-mini-tts-2603"` |
| `DEFAULT_MISTRAL_TTS_VOICE_ID` | `"c69964a6-ab8b-4f8a-9465-ec0925096ec8"` (Paul - Neutral) |
| `DEFAULT_XAI_VOICE_ID` | `"eve"` |
| `DEFAULT_XAI_LANGUAGE` | `"en"` |
| `DEFAULT_XAI_SAMPLE_RATE` | `24000` |
| `DEFAULT_XAI_BIT_RATE` | `128000` |
| `DEFAULT_GEMINI_TTS_MODEL` | `"gemini-2.5-flash-preview-tts"` |
| `DEFAULT_GEMINI_TTS_VOICE` | `"Kore"` |
| `DEFAULT_GEMINI_TTS_BASE_URL` | `"https://generativelanguage.googleapis.com/v1beta"` |
| `GEMINI_TTS_SAMPLE_RATE` | `24000` |
| `GEMINI_TTS_CHANNELS` | `1` |
| `GEMINI_TTS_SAMPLE_WIDTH` | `2` (16-bit PCM L16) |

## Per-provider config keys (from the dispatch functions)

### `elevenlabs` — `def _generate_elevenlabs(text, output_path, tts_config)` (line ~934)

Reads from `tts_config`:

- `tts.elevenlabs.voice_id` (default Adam)
- `tts.elevenlabs.model_id` (default `eleven_multilingual_v2`)

Reads from environment: `ELEVENLABS_API_KEY`.

**Does NOT read (documented but silently ignored):**
- `tts.elevenlabs.stability`
- `tts.elevenlabs.similarity_boost`
- `tts.elevenlabs.style`
- `tts.elevenlabs.speaker_boost`
- `tts.elevenlabs.output_format` — output format is determined by the file extension of `output_path` (`.ogg` → `opus_48000_64`, anything else → `mp3_44100_128`)
- `tts.elevenlabs.gateway` (maton/direct) — does not exist; the built-in calls `client = ElevenLabs(api_key=api_key)` with no `base_url` argument. To route through Maton, use a command-type provider or a Python plugin.

Call shape:

```python
client = ElevenLabs(api_key=api_key)
audio_generator = client.text_to_speech.convert(
    text=text, voice_id=voice_id, model_id=model_id, output_format=output_format,
)
# writes chunks to output_path
```

### `openai` — `def _generate_openai_tts(text, output_path, tts_config)` (line ~980)

Reads from `tts_config`:

- `tts.openai.model` (default `gpt-4o-mini-tts`)
- `tts.openai.voice` (default `alloy`)
- `tts.openai.base_url` (default OpenAI; can be overridden to hit any OpenAI-compatible TTS endpoint)
- `tts.openai.speed` (0.25–4.0, default 1.0)

Output format is determined by file extension: `.ogg` → `response_format="opus"`, anything else → `mp3`. Sends an `x-idempotency-key` header per request.

### `xai` — `def _generate_xai_tts(text, output_path, tts_config)` (line ~1105)

Reads from `tts_config`:

- `tts.xai.voice_id` (default `eve`)
- `tts.xai.language` (ISO 639-1, default `en`)
- `tts.xai.sample_rate` (22050 / 24000 / 44100 / 48000)
- `tts.xai.bit_rate` (MP3 only, default 128000)

The dispatch path uses `tools.xai_http.resolve_xai_http_credentials()` for auth (so XAI OAuth or `XAI_API_KEY` both work).

### `minimax` — separate dispatch (see `tools/minimax_audio_tool.py` or `tools/tts_tool.py` later sections)

Reads from `tts_config`:

- `tts.minimax.model` (default `speech-02-hd`)
- `tts.minimax.voice_id`
- `tts.minimax.speed` (0.5–2.0)
- `tts.minimax.vol` (0–10)
- `tts.minimax.pitch` (-12 to +12)

### `gemini` — uses `DEFAULT_GEMINI_TTS_*` constants

Reads from `tts_config`:

- `tts.gemini.model` (default `gemini-2.5-flash-preview-tts`)
- `tts.gemini.voice` (default `Kore`)

Output is raw PCM L16, which Hermes encodes to Opus for Telegram voice bubbles via ffmpeg.

### `mistral` — Voxtral TTS

Reads from `tts_config`:

- `tts.mistral.model` (default `voxtral-mini-tts-2603`)
- `tts.mistral.voice_id` (default Paul - Neutral)

### `edge` — Microsoft Edge TTS

Reads from `tts_config`:

- `tts.edge.voice` (default `en-US-AriaNeural`)
- `tts.edge.speed` (mapped to a `+/-%` rate string)

No API key. Outputs MP3, requires ffmpeg for Opus conversion on Telegram.

## Per-provider text-length caps

From `PROVIDER_MAX_TEXT_LENGTH` (line ~211) and `ELEVENLABS_MODEL_MAX_TEXT_LENGTH` (line ~225):

| Provider | Default cap (chars) | Override key |
|---|---|---|
| `edge` | 5000 | `tts.edge.max_text_length` |
| `openai` | 4096 | `tts.openai.max_text_length` |
| `xai` | 15000 | `tts.xai.max_text_length` |
| `minimax` | 10000 | `tts.minimax.max_text_length` |
| `mistral` | 4000 | `tts.mistral.max_text_length` |
| `gemini` | 5000 | `tts.gemini.max_text_length` |
| `elevenlabs` (fallback) | 10000 | `tts.elevenlabs.max_text_length` |
| `neutts` | 2000 | `tts.neutts.max_text_length` |
| `kittentts` | 2000 | `tts.kittentts.max_text_length` |
| `piper` | 5000 | `tts.piper.max_text_length` |

`elevenlabs` is model-aware (resolution order: explicit override → `ELEVENLABS_MODEL_MAX_TEXT_LENGTH` → fallback):

| `model_id` | Cap (chars) |
|---|---|
| `eleven_v3` | 5000 |
| `eleven_ttv_v3` | 5000 |
| `eleven_multilingual_v2` | 10000 |
| `eleven_multilingual_v1` | 10000 |
| `eleven_english_sts_v2` | 10000 |
| `eleven_english_sts_v1` | 10000 |
| `eleven_flash_v2` | 30000 |
| `eleven_flash_v2_5` | 40000 |

Override resolution (`_resolve_max_text_length`): only positive integer overrides are honored. Zero, negative, boolean, or non-numeric values fall through to the default — a broken config cannot disable truncation entirely.

## Voice-bubble / ffmpeg matrix

Telegram voice bubbles require Opus/OGG. The dispatch function picks the right format based on the **filename extension**, not a config key.

| Provider | Native output | Needs ffmpeg to get Opus? |
|---|---|---|
| `openai` | Opus or MP3 (per file extension) | No |
| `elevenlabs` | Opus or MP3 (per file extension) | No |
| `mistral` | Opus or MP3 (per file extension) | No |
| `edge` | MP3 | **Yes** |
| `minimax` | MP3 | **Yes** |
| `gemini` | Raw PCM L16 | **Yes** (encodes Opus directly) |
| `xai` | MP3 | **Yes** |
| `neutts` | WAV | **Yes** |
| `kittentts` | WAV | **Yes** |
| `piper` | WAV | **Yes** |

Workaround for avoiding the ffmpeg install: switch to `openai`, `elevenlabs`, or `mistral` and write the output to `*.ogg`.
