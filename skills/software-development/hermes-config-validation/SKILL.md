---
name: hermes-config-validation
type: standalone
version: 1.0.0
category: development
description: Use when configuring Hermes Agent (TTS, STT, MCP, plugins, personalities, any built-in provider) for a new project or use case, OR when building a non-gateway frontend (web UI, mobile app) on top of Hermes and wondering why "call the Hermes TTS endpoint" does not work — TTS is an internal agent tool, not a public route. Validates config keys against the actual installed Hermes source code (not docs, not old PLAN.md files) and API keys against live providers, before designing or coding. Catches the recurring trap where a documented config key is silently ignored by the runtime, and the related trap where developers assume an HTTP endpoint exists for a tool that is only invoked from inside an agent turn.
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [hermes, config, validation, source-of-truth, tts, stt, providers, voice, setup]
    related_skills: [hermes-agent, systematic-debugging, spike, plan]
---

# Hermes Config Validation

[content retained — see file system for full body]

## Related references

- Always load the references before validating HTTP endpoints — they document port × auth × service mapping, where tokens live, how to add routes correctly, and the smoke-test commands to verify which surface you're talking to. Read the relevant reference BEFORE building any bridge/extension/dashboard that calls Hermes over HTTP.