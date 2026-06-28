# SIP / FreeSWITCH Hebrew Voice Agents — When Twilio/Vonage Aren't the Answer

**Context:** Most Israeli SMB voice bot engagements default to Twilio or Vonage. This reference covers the case where the customer already has a FreeSWITCH / Asterisk / 3CX / IP-PBX running on their own infrastructure and only accepts **SIP trunk** as the integration boundary. There is no API, no webhook — only SIP.

## When to use this reference

- Customer has an internal PBX (FreeSWITCH, Asterisk, 3CX, Avaya, Cisco, Genesys) on their own server (AWS / on-prem)
- Customer says: "יש לנו מרכזייה, אנחנו רק צריכים שזה ידבר SIP"
- Customer explicitly rejects hosted telephony (Twilio/Vonage) — usually due to compliance, data residency, or because they already pay for the trunks
- The voice agent must reach the customer's existing DID numbers without porting them
- Hebrew TTS / STT quality is critical — OpenAI Realtime fails in Hebrew (this is the most common reason customers ask for alternatives)

**Skip this reference if:** the customer has no PBX, is open to Twilio/Vonage, or has fewer than ~10 concurrent calls. The hosted path is cheaper and faster.

## Architecture (the only shape that works)

```
[Caller dials DID]
   ↓ (PSTN / SIP)
[Customer's FreeSWITCH on AWS / on-prem]
   ↓ (SIP trunk to your server, or to your EC2)
[Your Voice Bot container]
   ┌──────────────────────────────────────┐
   │ 1. SIP media stream (RTP/PCMU)       │
   │ 2. STT — Deepgram / Whisper          │
   │ 3. LLM — GPT-4o-mini / local          │
   │ 4. TTS — ElevenLabs / Cartesia Sonic │
   │ 5. RTP back to FreeSWITCH            │
   └──────────────────────────────────────┘
   ↓ (SIP)
[FreeSWITCH] → [Caller hears reply]
```

## 4 stack options (ranked by fit for FreeSWITCH)

### Option A: Pipecat (recommended, OSS, free software)

**What it is:** Python framework for real-time voice agents. Handles the full pipeline (transport → STT → LLM → TTS) with first-class streaming support.

**Why it fits FreeSWITCH:** Pipecat has built-in transport support for SIP via integration with `siprix` and FreeSWITCH `mod_audio_stream`. The bot container talks SIP directly — no gateway process needed.

**Costs (estimates — verify before committing):**
- Deepgram Nova-3 STT: ~$0.0043/min Hebrew
- GPT-4o-mini LLM: ~$0.15/M tokens (~$0.01/min for short turns)
- ElevenLabs TTS (Hebrew): ~$0.18/1K chars
- Cartesia Sonic TTS (alternative): ~$0.06/1K chars, lower latency
- AWS t3.medium for 50 concurrent calls: ~$30/mo
- **Total: $300-470/mo for 1,000 calls × 3 min**

**Time to PoC:** 2-3 weeks (one engineer)
**Production to first customer:** 30 days
**Best for:** Customers who want full control, on their own AWS, no vendor lock-in.

### Option B: LiveKit Agents (managed cloud, free tier)

**What it is:** LiveKit's voice-agent framework. Real-time media server + Python SDK. Has SIP gateway option.

**Why it fits FreeSWITCH:** LiveKit has a SIP bridge (you point your FreeSWITCH trunk at LiveKit Cloud, or self-host). 10,000 free minutes/month.

**Costs:** $0 below 10K min/mo. Above that, per-usage pricing comparable to Pipecat's components.
**Best for:** Customers who want minimal DevOps, accept a managed cloud dependency.

### Option C: Vocode (OSS, flexible)

**What it is:** Python library for building voice agents. Similar to Pipecat but lower-level — you wire the pipeline yourself.

**Best for:** Engineering teams that want to own every line. More work, more control.
**Time to PoC:** 4-6 weeks.

### Option D: Vapi / Bland / PolyAI (SaaS, turnkey)

**What it is:** Hosted voice agent platforms. You give them a script; they handle STT/LLM/TTS/SIP.

**Why it sometimes fits FreeSWITCH:** Vapi and Bland both support SIP bring-up (you point your PBX at their SIP endpoint). 1-2 weeks to production.

**Costs:** $0.05-0.10/min + model costs. **$450-600/mo for 1,000 calls × 3 min — 30-40% more than Pipecat.**
**Best for:** Customers who need it working this week and accept the cost premium.

## Critical pitfall: don't pick based on cost alone

The right choice depends on:

| Question | Default answer | If different, prefer |
|----------|----------------|----------------------|
| Who runs the FreeSWITCH? | Customer, on their AWS | Pipecat (run alongside) |
| Is the team willing to write Python? | Yes | Pipecat / Vocode |
| Is compliance / data residency critical? | Yes, must stay in Israel | Pipecat / LiveKit self-hosted |
| Will the agent do tool calls (CRM, calendar)? | Yes | Pipecat (best tool-calling UX) |
| Do they need it live in 1 week? | Yes | Vapi / Bland |

## Hebrew STT specifically

OpenAI Realtime is the #1 reason customers ask for alternatives — it sounds robotic in Hebrew and the WER is ~15-20% higher than Deepgram. The replacement ranking for Hebrew:

| STT | Hebrew WER (subjective) | Latency | Cost | Verdict |
|-----|------------------------|---------|------|---------|
| OpenAI Realtime | ~15-18% | 800-1200ms | $0.06/min | **Replace this** |
| Deepgram Nova-3 | ~6-9% | 300-500ms | $0.0043/min | **Best for production Hebrew** |
| AssemblyAI Universal | ~7-10% | 350-550ms | $0.00025/sec | Strong alternative |
| Whisper Large-v3 (self-hosted) | ~8-11% | 600-1000ms (GPU) | Server cost | Best if data must not leave Israel |
| Google Cloud STT (he-IL) | ~10-13% | 400-700ms | $0.016/min | OK fallback |
| ivrit-ai/whisper-large-v3-turbo | ~5-8% | 500-900ms | Server cost | Best open Hebrew model |

## Hebrew TTS specifically

ElevenLabs Multilingual v2 / Flash v2.5 is the 2026 default for Israeli voice agents. Cartesia Sonic is the lower-latency alternative (sub-200ms first byte).

## Latency budget — why this matters more than you'd think

For natural conversation, end-to-end latency must be <800ms. Components:

- STT first-token: 200-400ms (Deepgram streaming)
- LLM first-token: 100-300ms (GPT-4o-mini)
- TTS first-byte: 150-300ms (ElevenLabs Flash / Cartesia Sonic)
- Network + FreeSWITCH: 50-100ms
- **Total target: 600-900ms** (OpenAI Realtime is 1500-2000ms in Hebrew — too slow)

## FreeSWITCH-side configuration (the part customers forget)

For Pipecat or LiveKit to receive a SIP call, the FreeSWITCH dialplan needs:

```xml
<extension name="voice-bot">
  <condition field="destination_number" expression="^(972\\d{9})$">
    <action application="set" data="call_timeout=30"/>
    <action application="set" data="media_bug_answer_req=true"/>
    <action application="bridge" data="sofia/gateway/voice-bot/$1"/>
  </condition>
</extension>
```

And the gateway entry points at your bot container's IP:port (UDP 5060 + RTP range).

## Pre-sales questions for the customer (ask before quoting)

1. "איזו מערכת מרכזייה אתם מריצים? FreeSWITCH, Asterisk, 3CX, משהו אחר?"
2. "היא בענן או על שרת שלכם?"
3. "יש לכם API או דרך אחרת לחבר אליה שירות חיצוני, חוץ מ-SIP trunk?"
4. "כמה שיחות נכנסות ביום בשעות העומס?"
5. "הסוכן הקולי אמור לעשות מה? (FAQ / תזמון / העברה לאדם / פעולות במערכות / שיחה מלאה)"
6. "מי ספק המרכזייה שלכם?" — answers 1+6 together often.

If the answer to 3 is "רק SIP trunk" → this reference is the right path.

## What NOT to do

- ❌ Tell the customer "we'll use Twilio" before asking — they may already have trunks they pay for, and re-porting is a multi-week telecom operation.
- ❌ Default to OpenAI Realtime for Hebrew — it's the problem, not the solution.
- ❌ Recommend a SaaS (Vapi/Bland) without flagging the 30-40% cost premium.
- ❌ Promise <500ms end-to-end without budgeting per-component — most stacks hit 1000-1500ms in Hebrew because TTS Hebrew voices are larger than English.
- ❌ Skip the PoC — Hebrew voice quality is impossible to judge from docs alone. Always do a 5-call pilot before contract.

## Reference

Full research document (50 pages, includes architecture diagrams, code samples, cost tables for all 4 options):
- `[hermes-config-dir]/memories/Hermes/Brain/Project Contexts/iPracticom Voice Agent Research.md`

That document was written for a specific engagement (iPracticom, FreeSWITCH on AWS, 10-50 concurrent calls, Hebrew). The shape generalizes to any FreeSWITCH-based customer. Re-read sections 4-6 (architecture, PoC plan, cost breakdown) for the specific deployment playbook.
