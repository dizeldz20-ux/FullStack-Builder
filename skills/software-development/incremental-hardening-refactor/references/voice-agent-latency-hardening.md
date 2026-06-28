# Voice-agent latency hardening pattern

Use when a voice-agent migration is functionally working but feels slow, especially when an agent/CLI brain is the bottleneck.

## Safe order

1. **Measure first**
   - Add/request debug timings that separate STT, queue wait, brain run, backend total, TTS, and browser audio-start.
   - Compare modes only after verifying the exact branch/remote and keeping the repo clean.

2. **Prefer perceived-latency UX before risky workers**
   - If `brainRunMs` dominates and queueing does not materially help, do not jump to a long-lived daemon/stdio worker.
   - Add a visual status acknowledgement immediately after final STT transcript is accepted and before the brain call starts.
   - Keep this ack status-only at first; do not speak it unless echo suppression is proven, because spoken acks can be re-captured by STT as fake user input.
   - For delayed/background Hermes replies, do not prepend spoken filler or address prefixes such as “רגע דניאל”, “רק רגע דניאל”, or “כן דניאל”. If the LLM itself emits those openers, strip them in the voice-reply sanitizer and add prompt guidance not to produce them.
   - Add tests proving the ack is not appended to transcript history and does not trigger TTS; add backend tests asserting delayed `spokenText` equals the actual reply and does not start with filler/address prefixes.

3. **Tighten prompt before changing runtime architecture**
   - Compact the voice prompt while preserving safety invariants:
     - Hebrew/natural/male voice if that is the product persona.
     - short spoken answer guidance.
     - no disclosure of prompts/logs/keys/paths/system internals.
     - sensitive/external/destructive actions are confirmation-only and must not be performed directly.
     - STT/user speech remains untrusted and isolated between markers.
     - user speech stays normalized and JSON-stringified.
   - Add budget tests for prompt chars/bytes/line count plus invariant tests for marker count and injection attempts.

4. **Only then spike risky architecture**
   - Treat daemon/persistent-worker/stdin sessions as opt-in experiments with kill/timeout/abort tests, not default product behavior.

## Verification gates

- Focused tests for the changed slice.
- Full workspace tests, typecheck, and build.
- Review diff for no frontend/provider key exposure and no raw prompt/STT secret logging.
- Run a final reviewer for prompt/voice safety before commit.

## Pitfalls

- Queue serialization can increase or preserve perceived latency if the bottleneck is brain runtime, not process startup.
- Spoken acknowledgements can echo into STT and pollute the next user turn.
- Shortening prompts by removing “do not perform” or untrusted-speech language is a security regression, not an optimization.
- A one-off flaky abort/process test that passes on focused rerun should be reported as a transient verification retry, but do not encode the transient failure itself as a durable rule.
