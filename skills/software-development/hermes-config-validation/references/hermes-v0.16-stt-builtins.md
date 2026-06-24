# Hermes v0.16.0 — STT Built-in Providers and Fallback Chain

This is the source-of-truth reference for STT (voice → text) in Hermes v0.16.0. Data from `~/.hermes/hermes-agent/tools/transcription_tools.py` and `agent/transcription_provider.py`.

## Built-in names

From `tools/transcription_tools.py` (around line 234):

```
local, local_command, groq, openai, mistral, xai
```

Plus the `elevenlabs` STT via `scribe_v2` (line 91: `DEFAULT_ELEVENLABS_STT_MODEL = "scribe_v2"`).

The set is kept in sync with `agent.transcription_registry._BUILTIN_NAMES` — a regression test fails if they drift.

## Per-provider config keys

### `local` — `faster-whisper` running in-process

Reads from `tts_config` (well, `stt_config`):

- `stt.local.model` — `tiny` / `base` / `small` / `medium` / `large-v3`. Default is `base` (~150MB download on first use).
- `stt.language` (optional) — ISO code; default `en` (`DEFAULT_LOCAL_STT_LANGUAGE`).

No API key. The model is downloaded on first use via `tools.lazy_deps.ensure("stt.local", prompt=False)`.

**Important:** if the user sets a cloud-only model name (e.g. `whisper-1`, `whisper-large-v3`) in `stt.local.model`, `transcription_tools.py` falls back to the default local model and emits a warning. The check is by membership in `OPENAI_MODELS` or `GROQ_MODELS` (lines 107–108).

### `groq`

Reads from `stt_config`:

- `stt.groq.model` — `whisper-large-v3` / `whisper-large-v3-turbo` / `distil-whisper-large-v3-en` (set membership in `GROQ_MODELS`, line 108)
- `stt.language` (optional, default `en`)

Reads from environment: `GROQ_API_KEY`.

Base URL: `https://api.groq.com/openai/v1` (overridable via `GROQ_BASE_URL` env var).

**Caveat:** `distil-whisper-large-v3-en` is English-only. For Hebrew, use `whisper-large-v3` or `whisper-large-v3-turbo`.

### `openai`

Reads from `stt_config`:

- `stt.openai.model` — `whisper-1` / `gpt-4o-mini-transcribe` / `gpt-4o-transcribe` (set membership in `OPENAI_MODELS`, line 107)

Reads from environment: `VOICE_TOOLS_OPENAI_KEY` first, falls back to `OPENAI_API_KEY`.

Base URL: `https://api.openai.com/v1` (overridable via `STT_OPENAI_BASE_URL` env var).

### `mistral`

Reads from `stt_config`:

- `stt.mistral.model` — `voxtral-mini-latest` / `voxtral-mini-2602`

Reads from environment: `MISTRAL_API_KEY`.

### `xai`

Reads from `stt_config`:

- `stt.xai.model` — `grok-stt`

Reads from environment: `XAI_API_KEY`.

Base URL: `https://api.x.ai/v1` (overridable via `XAI_STT_BASE_URL` env var). Posts as multipart/form-data.

### `local_command` — escape hatch for any local CLI

`stt.provider: local_command` uses `HERMES_LOCAL_STT_COMMAND` env var directly. Template placeholders: `{input_path}`, `{output_dir}`, `{language}`, `{model}`. The command must write a `.txt` (or `.json` / `.srt` / `.vtt`) under `{output_dir}`.

Use this when you need parakeet-asr, whisper.cpp, SenseVoice, doubao-speech, or any other local CLI that doesn't fit the other built-ins.

### `elevenlabs` (Scribe)

ElevenLabs Scribe is a separate built-in reachable by setting `stt.provider: elevenlabs`. Reads from env: `ELEVENLABS_API_KEY`. Default model is `scribe_v2`.

## Fallback chain

The `stt` dispatcher walks the providers in this order when a specific `stt.provider` is not set or fails:

```
local → local_command → groq → openai → mistral → xai → elevenlabs
```

- `local` failing because `faster-whisper` is not installed → tries a local whisper CLI from `COMMON_LOCAL_BIN_DIRS = ("/opt/homebrew/bin", "/usr/local/bin")`, then `HERMES_LOCAL_STT_COMMAND`, then cloud.
- `groq` failing because the key is missing → falls through to `openai`, then `mistral`, etc.
- `mistral` failing because the key/SDK is missing → marked unavailable, skipped in auto-detect.
- All providers unavailable → the voice message is **passed through unchanged** with a note to the user, not an error.

## Per-provider config key map (one-line summary)

| Provider | YAML block | Keys | Env var |
|---|---|---|---|
| `local` | `stt.local.*` | `model` | — |
| `groq` | `stt.groq.*` | `model` | `GROQ_API_KEY` |
| `openai` | `stt.openai.*` | `model` | `VOICE_TOOLS_OPENAI_KEY` (or `OPENAI_API_KEY`) |
| `mistral` | `stt.mistral.*` | `model` | `MISTRAL_API_KEY` |
| `xai` | `stt.xai.*` | `model` | `XAI_API_KEY` |
| `elevenlabs` | (uses env defaults) | — | `ELEVENLABS_API_KEY` |
| `local_command` | (uses env) | — | `HERMES_LOCAL_STT_COMMAND` |

## Hebrew language notes

- `faster-whisper` `base` model handles Hebrew adequately for short, clean voice notes. Production-quality Hebrew needs `small` or larger (1.5GB+ download).
- `groq` `whisper-large-v3` is the cheapest production-quality Hebrew STT. Free tier, ~real-time latency.
- `elevenlabs` Scribe is also strong for Hebrew but is per-minute billed and goes through ElevenLabs (adding the second provider to the stack).
- `distil-whisper-large-v3-en` is English-only — do not use for Hebrew.

## Plugin hook

`agent.transcription_provider.TranscriptionProvider` is the ABC for plugin authors. Required: `name`, `display_name`, `is_available()`, `transcribe()`. Optional: `list_models()`, `default_model()`, `get_setup_schema()`. Plugins live at `~/.hermes/plugins/stt/<name>/` or `<repo>/plugins/stt/<name>/`.
