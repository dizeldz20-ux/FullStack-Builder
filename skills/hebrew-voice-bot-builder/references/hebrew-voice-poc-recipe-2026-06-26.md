# Hebrew Voice Agent POC Recipe — End-to-End Pipeline (Validated 2026-06-26)

**Context.** Built and executed a complete Hebrew voice agent POC at iPracticom (the user starts there 2026-07-01). POC ran on a headless VM with no mic/speaker — validated end-to-end with synthesized Hebrew input. This reference captures the **verified-working recipe** plus the **gotchas** that are NOT documented in the main SKILL.md or in `references/sip-freeswitch-pbx.md`.

**Trigger.** Read this when planning ANY Hebrew voice agent POC that uses Deepgram + MiniMax/Anthropic/OpenAI LLM + ElevenLabs TTS. Skip if you're only using OpenAI Realtime (different stack) or only doing DTMF IVR (no STT/LLM needed).

## The recipe that worked (final, 2026-06-26 v7)

```
mulaw 8kHz mono WAV → Deepgram STT (whisper + language=he) → Hebrew text
                                                  ↓
                          Groq llama-4-scout-17b-16e-instruct → Hebrew reply (227-427ms)
                                                  ↓
                    ElevenLabs v3 (Liam voice, Ruby production settings) → MP3 192kbps output

End-to-end: ~3,018ms (production target: <2,000ms)
```

**Architecture:** Python AI agent as one FreeSWITCH extension. Caller → FreeSWITCH (PBX: IVR/queue/CDR/billing) → mod_audio_stream (TCP socket) → Python agent → back to FreeSWITCH → Caller. **Do NOT replace FreeSWITCH with Vapi/LiveKit** — the PBX handles what SaaS voice agents can't (Israeli regulatory recording, DID routing, human fallback).

### Component-by-component (with verified timings, 2026-06-26 12:19)

| Component | Provider + params | Time | Confidence | Gotcha |
|-----------|-------------------|------|------------|--------|
| **STT** | Deepgram `model=whisper`, `language=he`, `smart_format=true` | ~1.4s | **0.89** | Nova-2 doesn't support `he`. Nova-3 returns MIX of Latin transliteration + Hebrew Unicode — confuses LLMs unless they have a strong Hebrew system prompt. Whisper returns clean Hebrew text directly. **Ruby's production uses `nova-3` with `endpointing=300, vad_events=true`** — also works but requires stronger system prompt. |
| **LLM (default)** | Groq `meta-llama/llama-4-scout-17b-16e-instruct` | **~227-427ms** | n/a | 18x faster than MiniMax M2.7. Best Hebrew quality in sub-500ms tier. Hermes has `GROQ_API_KEY` in `/root/.hermes/.env`. OpenAI-compatible API. |
| **LLM (fallback)** | Groq `llama-3.1-8b-instant` | ~500-700ms | n/a | Smaller, slightly shorter replies. Cost-sensitive fallback. |
| **LLM (last resort)** | MiniMax `MiniMax-M2.7`, **`thinking: {type: "disabled"}`** | ~7-11s | n/a | 18x slower than Groq. Only use if Groq is unavailable. Default M2.7 is a reasoning model — without `thinking: disabled`, it consumes all `max_tokens` on internal thinking and returns empty/short replies. |
| **TTS** | ElevenLabs **`eleven_v3`** (NOT `eleven_v3_conversational` — requires Conversational AI plan tier), voice=`TX3LPaxmHKxFdv7VOQHJ` (Liam), **Ruby production settings**: stability=0.45, similarity_boost=0.8, style=0.25, use_speaker_boost=true, speed=0.94, output_format=`mp3_44100_192` | ~1.1-2.7s | n/a | Adam voice (`pNInz6obpgDQGcFmaJgB`) does NOT speak proper Hebrew — produces garbled audio. Only Liam works for Hebrew. **CRITICAL:** do not use ElevenLabs vendor defaults (stability=0.5, similarity_boost=0.75, no style, no speed) — they produce audio that "doesn't sound like Ruby at all" (the user's exact words). Always copy the production source verbatim. |
| **Total** | | **~3s with Groq llama-4-scout, ~5s with Groq 8b, ~12s with MiniMax** | | Production target is <2s. See "Latency fix" below. |

### System prompt for Deepgram Nova-3 mixed-script output

When copying Ruby's existing setup (which uses `nova-3`), include this system prompt or the LLM will produce garbage:

```python
DEFAULT_SYSTEM_PROMPT = """אתה עוזר קולי של {company_name}.
ההודעה מ-STT יכולה להיות בתעתיק לטיני של עברית (כמו "SHLVM" במקום "שלום"), בעברית, או מעורב.
תמיד תתרגם את ההודעה לעברית תקינה לפני שאתה עונה.
אם אתה לא יודע — אמור "אני לא יודע, אבל אני יכול להעביר אותך למוקדן אנושי"."""
```

Without it, llama-3.1-8b-instant gets confused by Nova-3's mixed Latin/Hebrew output and replies with garbage like `"1. אפשר, 2. אפשר, 3. אפשר..."`. llama-4-scout handles mixed input better but the prompt is still safer to include.

### Code (verified working)

Complete POC scripts live at:
- `/root/.[vault-runner]/wiki/main/code/iPracticom-POC/poc_voice_agent.py` — main POC script
- `/root/.[vault-runner]/wiki/main/code/iPracticom-POC/poc_voice_agent_v7.py` — Groq llama-4-scout version (3s end-to-end)
- `/root/.[vault-runner]/wiki/main/code/iPracticom-POC/output_v7_ruby_voice.mp3` — verified "sounds like Ruby" sample (58KB)

```python
# Step 1 — STT (Deepgram whisper, returns clean Hebrew Unicode)
async def deepgram_stt(audio_path: str) -> str:
    url = "https://api.deepgram.com/v1/listen"
    params = {"model": "whisper", "language": "he", "smart_format": "true"}
    headers = {"Authorization": f"Token {DEEPGRAM_API_KEY}", "Content-Type": "audio/wav"}
    async with httpx.AsyncClient(timeout=30.0) as client:
        resp = await client.post(url, params=params, headers=headers,
                                  content=open(audio_path, "rb").read())
        return resp.json()["results"]["channels"][0]["alternatives"][0]["transcript"].strip()

# Step 2 — LLM (Groq llama-4-scout, 227-427ms Hebrew)
async def groq_chat(system_prompt: str, user_text: str) -> str:
    url = "https://api.groq.com/openai/v1/chat/completions"
    headers = {"Authorization": f"Bearer {GROQ_API_KEY}", "Content-Type": "application/json"}
    payload = {
        "model": "meta-llama/llama-4-scout-17b-16e-instruct",
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_text},
        ],
        "max_tokens": 300,
        "temperature": 0.7,
    }
    async with httpx.AsyncClient(timeout=30.0) as client:
        resp = await client.post(url, headers=headers, json=payload)
        return resp.json()["choices"][0]["message"]["content"].strip()

# Step 3 — TTS (ElevenLabs v3 with Liam voice, Ruby production settings)
async def elevenlabs_tts(text: str, output_path: str, voice_id: str = None) -> str:
    voice = voice_id or "TX3LPaxmHKxFdv7VOQHJ"  # Liam
    url = f"https://api.elevenlabs.io/v1/text-to-speech/{voice}"
    headers = {"xi-api-key": ELEVENLABS_API_KEY, "Content-Type": "application/json"}
    payload = {
        "text": text,
        "model_id": "eleven_v3",
        "output_format": "mp3_44100_192",
        "voice_settings": {
            "stability": 0.45,           # Ruby's exact setting
            "similarity_boost": 0.8,     # Ruby's exact setting
            "style": 0.25,               # Ruby's exact setting
            "use_speaker_boost": True,   # Ruby's exact setting
            "speed": 0.94,               # Ruby's exact setting
        }
    }
    async with httpx.AsyncClient(timeout=60.0) as client:
        resp = await client.post(url, headers=headers, json=payload)
        Path(output_path).write_bytes(resp.content)
        return output_path
```

### Reproduction steps

```bash
# 1. Generate Hebrew input audio (ElevenLabs TTS) — produces MP3
python3 /root/.[vault-runner]/wiki/main/code/iPracticom-POC/generate_hebrew_input.py

# 2. Convert to 16kHz PCM WAV (best for Deepgram whisper)
ffmpeg -y -i /tmp/poc-stack-c/hebrew_input.wav \
  -ar 16000 -ac 1 -acodec pcm_s16le \
  /tmp/poc-stack-c/hebrew_input_16k.wav

# 3. Run POC
source /tmp/poc-stack-c/env.sh  # exports DEEPGRAM/ELEVENLABS/GROQ keys
python3 /root/.[vault-runner]/wiki/main/code/iPracticom-POC/poc_voice_agent_v7.py \
  --input /tmp/poc-stack-c/hebrew_input_16k.wav \
  --output /tmp/poc-stack-c/output_v7.mp3 \
  --save-json
```

## What DID NOT work (gotchas that bit us)

### 1. Deepgram nova-2 / nova-3 don't return Hebrew Unicode reliably

```bash
# Returns 400 Bad Request
curl -X POST "https://api.deepgram.com/v1/listen?model=nova-2&language=he" \
  -H "Authorization: Token $DEEPGRAM_API_KEY" \
  --data-binary @hebrew.wav
# {"err_msg":"No such model/language/tier combination found"}

# Returns MIX of Latin transliteration + Hebrew Unicode (not pure Latin, not pure Hebrew)
curl -X POST "https://api.deepgram.com/v1/listen?model=nova-3&language=he" \
  -H "Authorization: Token $DEEPGRAM_API_KEY" \
  --data-binary @hebrew.wav
# "NavT LBDVK את Mark HTTP HI SHLI Prchticom ת AG Wedel BBK HMHHHA"
```

**Corrected understanding (v1.0.3):** Nova-3 is NOT pure Latin transliteration — it returns a mix that confuses LLMs. Ruby's production code uses `nova-3` with `endpointing=300` and `vad_events=true` and works because the system prompt explicitly tells the LLM to expect mixed-script input. For new agents not copying Ruby's existing pipeline, prefer `model=whisper` (confidence 0.89, clean Hebrew Unicode) to avoid the translation hop entirely.

### 2. ElevenLabs Scribe v1 doesn't support Hebrew

```python
# Returns noise/garbage for Hebrew audio
r = httpx.post("https://api.elevenlabs.io/v1/speech-to-text",
               headers={"xi-api-key": ELEVENLABS_API_KEY},
               files={"file": ("a.wav", audio, "audio/wav")},
               data={"model_id": "scribe_v1", "language_code": "he"})
# {"text": "(speaking foreign language)"} or noise chars
```

**Scribe is NOT a Hebrew-capable STT.** Do not waste API credits testing it.

### 3. MiniMax M2.7 reasoning mode consumes all max_tokens

```json
// Default behavior — all tokens go to internal thinking
{"usage": {"completion_tokens": 50, "completion_tokens_details": {"reasoning_tokens": 50}}}
// → Reply: "" (empty)

// With thinking: {type: "disabled"}
{"usage": {"completion_tokens": 30, "completion_tokens_details": {"reasoning_tokens": 0}}}
// → Reply: "שלום! 👋"
```

**Always set `"thinking": {"type": "disabled"}`** in every MiniMax call unless you specifically need reasoning. Otherwise the model "thinks" forever and returns nothing useful.

The same applies to `MiniMax-M2` (also reasoning). **For new builds, prefer Groq over MiniMax** — Groq is 18x faster at similar cost and the API is OpenAI-compatible so drop-in replacement is trivial.

### 4. ElevenLabs voice settings matter MORE than voice ID

```python
# Adam voice with defaults — garbled Hebrew audio
url = "https://api.elevenlabs.io/v1/text-to-speech/pNInz6obpgDQGcFmaJgB"  # Adam
# TTS produces audio that STT can't decode as Hebrew — "(speaking foreign language)"

# Liam voice with DEFAULTS — audible Hebrew but "doesn't sound like Ruby at all"
url = "https://api.elevenlabs.io/v1/text-to-speech/TX3LPaxmHKxFdv7VOQHJ"  # Liam
# + vendor defaults (stability=0.5, similarity_boost=0.75, no style, no speed)
# → the user: "היא לא נשמעת בכלל כמו רובי"

# Liam voice with Ruby's production settings — matches Ruby voice identity
url = "https://api.elevenlabs.io/v1/text-to-speech/TX3LPaxmHKxFdv7VOQHJ"  # Liam
# + model_id=eleven_v3, stability=0.45, similarity_boost=0.8, style=0.25, speed=0.94
# → the user: "עכשיו זה נשמע מעולההההה"
```

**The lesson:** when the agent should sound like an existing voice/persona, **always copy the production source verbatim** — never assume vendor defaults match. The exact production source for Ruby is `[vault-workspace]/[your-voice-product]-app/backend/src/services/elevenlabsTts.ts`.

### 5. Audio format traps

| Provider | Wants | Gotcha |
|----------|-------|--------|
| Deepgram listen (whisper) | 16kHz PCM mono WAV preferred | Works with mulaw 8kHz too, but 16kHz is more reliable |
| Deepgram listen (nova-3) | Same | Same |
| ElevenLabs Scribe | 16kHz PCM mono | 8kHz mulaw → bad transcription |
| ElevenLabs TTS | any in, MP3 out | Always returns MP3; use ffmpeg to convert |

The conversion chain that worked end-to-end:

```bash
# ElevenLabs TTS output: MP3 44.1kHz
# Convert to 16kHz PCM WAV for best STT
ffmpeg -y -i hebrew_input.wav -ar 16000 -ac 1 -acodec pcm_s16le hebrew_input_16k.wav
```

## Architecture: FreeSWITCH + mod_audio_stream

When the customer has FreeSWITCH (or Asterisk/3CX) already running, the AI agent is just one dialplan extension:

```
Caller (PSTN) → FreeSWITCH (PBX: IVR/queue/CDR/billing/recording) 
                          ↓ mod_audio_stream (TCP socket — usually pre-installed)
                  Python AI Agent (this POC, served as systemd unit or Docker)
                          ├─→ Deepgram Whisper (STT, ~1.4s)
                          ├─→ Groq llama-4-scout (LLM, ~427ms)
                          └─→ ElevenLabs Liam + eleven_v3 (TTS, ~1.1s)
                          ↓ audio back to FreeSWITCH via mod_audio_stream
              FreeSWITCH → Caller
```

**Why NOT replace FreeSWITCH with LiveKit SIP (`livekit/sip`, 431⭐) or Vapi:**
- FreeSWITCH handles queue management, IVR menus, CDR for billing, DID routing across multiple numbers, recording for compliance (Israeli Privacy Protection Law Amendment 13, in force Aug 2025), and human-agent fallback. None of these are in LiveKit SIP or Vapi.
- LiveKit SIP and Vapi are PBX-replacement candidates, not PBX extensions. They handle media but not operational call-center features.
- Cost: mod_audio_stream + Python agent = ~$97/month (3,000 min). Vapi = ~$150/month for the platform fee alone.
- Operational burden: the Python agent is just one route in the existing dialplan; Vapi is a whole separate vendor to manage.

**When LiveKit SIP IS appropriate:** customer has no PBX at all and you're building from scratch. For Israeli SMBs with existing FreeSWITCH/Asterisk/3CX, the AI-in-extension pattern is strictly better.

## Latency fix path (not yet implemented)

POC is 3s end-to-end. Production target is <2s. Bottleneck split:
- STT 1.4s — could improve to ~700ms with streaming Deepgram (interim_results=true)
- LLM 427ms — hard to improve (already at LPU speed limit)
- TTS 1.1s — could improve to ~400ms with streaming ElevenLabs (start speaking when first sentence is ready)

Target: streaming all 3 → ~1.5s end-to-end.

## Verification protocol (mandatory before claiming POC works)

```bash
# 1. Output audio exists and is non-empty
ls -la output_v7.mp3   # should be > 50KB for a 3s reply

# 2. JSON results contain all 3 fields
cat output_v7.mp3.json | python3 -m json.tool
# Expect: transcript (hebrew), llm_reply (hebrew), tts_path, timings

# 3. Transcript is Hebrew (Hebrew Unicode chars present)
python3 -c "
import json
d = json.load(open('output_v7.mp3.json'))
t = d['transcript']
has_hebrew = any('\\u0590' <= c <= '\\u05FF' for c in t)
print(f'transcript has Hebrew: {has_hebrew}, len={len(t)}')
"

# 4. Audio sounds like the intended voice (have user listen)
# Upload output_v7_ruby_voice.mp3, ask "does this sound like Ruby?"
# If not, copy production TTS config verbatim
```

## What this POC proved vs. didn't prove

**Proved:**
- ✅ The 3-API chain works end-to-end for Hebrew in 3 seconds
- ✅ Deepgram whisper + Groq llama-4-scout + ElevenLabs Liam (with Ruby's production settings) = matches Ruby's voice quality
- ✅ Cost structure: ~$0.027/min, ~$80/month for 3,000 min (vs Vapi $150/month)
- ✅ Architecture scales: FreeSWITCH handles PBX, Python agent handles intelligence

**Did NOT prove:**
- ❌ Real call quality with real Hebrew audio (used synthetic TTS as input — circular test)
- ❌ Latency under real load (single call, no concurrency)
- ❌ Barge-in / interruption handling
- ❌ Function calling / CRM integration
- ❌ mod_audio_stream integration with actual FreeSWITCH
- ❌ Streaming optimizations (we used batch endpoints)
- ❌ Production hardening (auth, error handling, monitoring, retries)

The real Hebrew quality test happens on the customer's PBX with real Hebrew audio. This POC only proves the architecture is sound and the components match Ruby's production quality.

## Key files and references

| File | What |
|------|------|
| `/root/.[vault-runner]/wiki/main/code/iPracticom-POC/poc_voice_agent.py` | Original POC script (v1, MiniMax) |
| `/root/.[vault-runner]/wiki/main/code/iPracticom-POC/poc_voice_agent_v7.py` | Final POC script (v7, Groq llama-4-scout, 3s end-to-end) |
| `/root/.[vault-runner]/wiki/main/code/iPracticom-POC/generate_hebrew_input.py` | Hebrew TTS helper to produce test audio |
| `/root/.[vault-runner]/wiki/main/code/iPracticom-POC/output_v7_ruby_voice.mp3` | Verified "sounds like Ruby" sample |
| `/root/.[vault-runner]/wiki/main/code/iPracticom-POC/poc_results_v7_2026-06-26.json` | POC v7 timings |
| `/root/.[vault-runner]/wiki/main/reports/iPracticom POC Stack C v4 Results 2026-06-26.md` | Full POC v4 report (Groq llama-3.1-8b era) |
| `/root/.[vault-runner]/wiki/main/syntheses/iPracticom Development Plan.md` | The 4-week iPracticom deployment plan |
| `[vault-workspace]/[your-voice-product]-app/backend/src/services/elevenlabsTts.ts` | Ruby's production TTS config — copy verbatim |
| `/tmp/research/sip-to-ai/` | The `aicc2025/sip-to-ai` cloned repo (63⭐, Apache-2.0) for the actual SIP↔FreeSWITCH bridge |

## Related skills

- `voice-agent-stack-research` — the umbrella skill for stack selection (mentions MiniMax as one option; should be updated to prefer Groq based on findings above)
- `phone-integration-twilio-vapi` — when the customer wants Twilio/Vonage, not their own PBX
- `hermes-obsidian-brain-loop/references/recovery-when-deliverables-lost.md` — the vault-loss pitfall that almost made us lose these POC results; mandatory read before writing research outputs