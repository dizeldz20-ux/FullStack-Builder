<purpose>
Validate Hermes Agent configuration (TTS, STT, MCP, plugins, personalities) against the actual installed Hermes source code — not docs, not old PLAN.md files — and validate API keys against live providers, before designing or coding any feature that depends on them.
</purpose>

<user-story>
As a developer building a new project or feature on Hermes, I want the agent to catch silent config errors before I write code, so that I don't discover 3 hours in that the documented key is ignored by the runtime, or that the agent's TTS tool has no public HTTP endpoint.
</user-story>

<when-to-use>
- "I want to add [TTS / STT / MCP / plugin / personality] to my project"
- "Why does [feature] not work even though I set the config?"
- "Validate my Hermes config before I start coding"
- User explicitly invokes `/hermes-config-validation`
- Any new project setup that involves Hermes built-in providers
</when-to-use>

<context>
- The current `~/.hermes/config.yaml` (or equivalent)
- The Hermes version (run `hermes --version`)
- The features the user wants to use (TTS, STT, MCP server, plugin, personality, etc.)
- Any API keys the user has stored at `~/.config/<service>/` (NEVER the values — only paths)
</context>

<references>
@../references/hermes-v0.16-tts-builtins.md (TTS provider keys and their actual behavior in v0.16)
@../references/hermes-v0.16-stt-builtins.md (STT provider keys in v0.16)
@../references/hermes-v0.16-api-server-frontend-template.md (when building a non-gateway frontend on top of Hermes)
@../references/hermes-v0.16-api-server-frontend-template.md (HTTP endpoints exposed by Hermes and which require auth)
@../references/live-credential-smoke-pattern.md (how to verify a key works against a live provider)
@../references/secure-public-url.md (when exposing a Hermes-backed service publicly)
@../references/config-merge-three-rule.md (when the user has a config.yaml that needs merging)
@../references/mobile-first-frontend-design.md (when building mobile UIs that depend on Hermes)
</references>

<steps>

<step name="read_current_config" priority="first">
Read the user's current Hermes config. Note the version. Check whether the user is on a version that supports the feature they want.
</step>

<step name="check_config_keys">
For each key the user wants to use, look it up in the corresponding reference file (e.g. `hermes-v0.16-tts-builtins.md`). Compare: is the key in the user's config actually honored by the installed Hermes source? Or is it documented but silently ignored?

If a key is silently ignored, surface it immediately — do not let the user proceed to design.
</step>

<step name="check_endpoint_exposure">
For each Hermes tool the user wants to expose to a frontend (TTS, STT, completion, etc.), check the hermes-config-validation references. Is there an actual HTTP endpoint for this tool, or is it only invokable from inside an agent turn?

If the tool has no public endpoint, surface it. The user is about to write a frontend that calls an endpoint that does not exist.
</step>

<step name="verify_keys_live">
For each API key the user has stored, run the smoke pattern from `live-credential-smoke-pattern.md` — but reference the file path, NEVER the literal value. Confirm each key is live, has the right permissions, and matches the provider Hermes expects.

If a key is stale, missing permissions, or for the wrong provider, surface it with the exact blocker.
</step>

<step name="check_frontend_architecture">
If the user is building a frontend that depends on Hermes, check `hermes-v0.16-api-server-frontend-template.md` and `mobile-first-frontend-design.md`. Confirm the architecture matches Hermes' actual exposed surface — not what the user assumed.
</step>

<step name="report_blockers">
Produce a structured report:
- ✅ Working as expected
- ⚠️ Silently ignored / mismatched config
- ❌ Missing endpoint / wrong provider / stale key

For each ❌, give the exact remediation. For each ⚠️, give the risk and a one-line fix.
</step>

<step name="confirm_safe_to_proceed">
End the report with: "Safe to proceed with [feature]? (yes / no, with X blockers first)". Do NOT let the user proceed if any ❌ is unresolved.
</step>

</steps>

<output>
A validation report containing: Hermes version check, config key validation (✅ / ⚠️ / ❌), endpoint exposure check, live key smoke results, frontend architecture check, and a final "safe to proceed" decision with any blockers.
</output>

<acceptance-criteria>
- [ ] Hermes version is checked before validating any key
- [ ] Every config key the user wants is verified against the actual Hermes source, not docs
- [ ] Every Hermes tool the user wants to expose is checked for an actual HTTP endpoint
- [ ] API keys are verified by referencing `~/.config/<service>/` paths, never the literal value
- [ ] Report uses ✅ / ⚠️ / ❌ with exact remediation for each ❌
- [ ] Final "safe to proceed" decision is explicit and gates any subsequent design / coding
- [ ] The recurring trap (documented key silently ignored, or tool with no public endpoint) is called out by name
</acceptance-criteria>
