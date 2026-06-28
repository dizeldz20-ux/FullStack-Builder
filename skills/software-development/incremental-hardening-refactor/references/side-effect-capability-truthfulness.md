# Side-effect capability truthfulness

Use this when hardening personal-assistant action flows where natural language requests can lead to external side effects such as Telegram, WhatsApp, calendar, email, payments, or file publishing.

## Problem pattern

A sensitive-action detector recognizes an intent and creates a pending confirmation even though no live executor exists, or the request lacks required slots. The user then approves and receives a mock/simulation completion. This is unsafe and misleading, especially when the user explicitly asked for a real action.

## Durable invariant

Sensitive intent recognition is not enough to create a pending action. Create a confirmable pending action only when all are true:

1. The transport/action has a real executor wired in the current runtime.
2. The executor is configured/healthy enough to attempt after approval, or the preview truthfully says health will be checked before send.
3. The target and action are allowlisted for live execution.
4. The pending action carries an explicit executable payload, not just a natural-language summary.
5. Required slots are present; otherwise ask for missing context and do not create `actionId`.

Unsupported or under-specified actions should return truthful status (`not_configured`/`missing_context`) with `requiresConfirmation=false` and no queued notification.

## Implementation playbook

- Add RED tests that prove unsupported transports do not create pending actions, do not call the brain/executor, and do not push simulated completion notifications.
- Put capability gating in the shared action layer and call it from every entrypoint, including legacy routes, so there is no path that preserves the old simulation behavior.
- Make queue/approval fail closed: if the pending action id does not match or the payload is missing/not allowlisted, cancel/return undefined instead of simulating.
- Keep tests aligned with the new invariant. Do not keep old tests that assert “simulation completed” for unsupported transports.
- For user copy, explicitly say nothing was sent and nothing was simulated; offer a draft/copy-paste alternative when useful.

## Report diagnostics

Failure reports for voice/action flows should include safe action context so future debugging does not blame STT/TTS incorrectly:

- `actionState`
- whether a pending action exists
- a short action id suffix only, never the full id
- action notification state

Do not classify a voice issue as provider/STT instability solely because debug text contains the provider name. If transcript messages or Ruby/action state exist, the pipeline reached the assistant and the likely failure moved up to action capability, approval binding, executor health, or TTS.

## Provider rollout pattern

When moving an unsupported transport to live execution, make the first live slice intentionally narrow:

- Prefer a controlled self-send target first (for example Telegram-to-self) before arbitrary recipients, groups, channels, or calendars.
- Gate the executor behind backend-only env/config; frontend/browser state should never contain provider tokens or chat IDs.
- Keep provider API base URLs constrained to the real provider or loopback test servers. This prevents accidental SSRF-style expansion when tests inject a fake endpoint.
- Add tests for both worlds: provider not configured still returns truthful unsupported status; provider configured returns preview only and does not send until bound approval.
- In live smoke, stop at preview/status unless the user explicitly asked for a real send or the target is a controlled self-send endpoint.

## Slot filling and voice output

- Calendar/meeting requests should preserve recent useful context, such as “between 9 and 10,” in bounded conversation state and ask only for the missing slots on a later bare “meeting” request.
- Missing-slot replies should not create `actionId`, should not ask “approve?”, and should state that no event was created.
- For voice assistants, cap long spoken/delayed replies before TTS; background answers should not flood the live voice channel.

## Verification

- Focused action-gating tests pass.
- Full suite/build pass.
- Live smoke exercises each class:
  - unsupported transport returns no confirmation and no action id
  - missing slots returns clarification/status, not approval
  - allowlisted live action still produces a preview and requires explicit approval
  - same-conversation slot carryover works without creating an action
