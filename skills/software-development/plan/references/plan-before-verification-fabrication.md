# Worked example: Plan-before-verification fabrication

**Captured:** 2026-06-16
**Domain:** Agentic OS `/pipeline` (Node.js/Next.js + Hermes bridge + Vault)
**Skills involved:** `plan` (the planning that produced the bad plan), `subagent-driven-development` (the would-be executor), `superpowers:executing-plans` (the safety net that caught it)
**Cost without the safety net:** the entire working pipeline would have been overwritten by an incompatible reimplementation

---

## The request

User reported that the `/pipeline` tab on their laptop at `http://[agent-vm-ip]:3001` showed 0 items across 4 columns, even though the API at `/api/pipeline` returned 9 items in 5 stages. They asked for a plan to fix the tab so that "shape" actually produces a real, itemized design spec (not a static template).

## What the plan claimed (the fabrication)

The agent wrote a 419-line plan that asserted the following about the live system:

1. **"Create `src/app/api/pipeline/shape/route.ts`"** — claiming the file did not exist.
2. **"Create `src/app/api/pipeline/build/route.ts`"** — claiming the file did not exist.
3. **"Create `src/lib/pipeline/itemStore.ts`"** — proposing a new directory layout that would collide with the existing `src/lib/pipeline.ts`.
4. **"Shape should call `agy.exe --print-timeout 300s --print '<prompt>'`"** — proposing to shell out to the local antigravity binary.
5. **"Build should `fetch` directly to `fcc /v1/messages`"** — proposing a direct call bypassing the bridge.
6. **"Import `fccAdminStatus` from `@/lib/fcc`"** — proposing to use a runtime model reader.
7. **"Store `designSpec` as a structured JSON object `{summary, components, criteria}`"** — proposing a JSON schema.
8. **"Do not install `js-yaml`"** — explicitly forbidding a dependency the live code already used.
9. **"`C:[user-home]/AppData/Local/agy/bin/agy.exe`"** — proposing a hard-coded binary path.

## What the live system actually looked like (verified after)

The user and a Claude Code subagent then verified every claim, in the same conversation. **Every single structural claim in the plan was wrong:**

| Plan said | Reality (verified) |
|---|---|
| `shape/route.ts` does not exist | Already exists, delegates to `src/lib/pipeline.ts` |
| `build/route.ts` does not exist | Already exists, delegates to `src/lib/pipeline.ts` |
| Need to create `src/lib/pipeline/itemStore.ts` | `src/lib/pipeline.ts` is a single module exporting `readItem` / `writeItem` / `classifyIdea` / `draftDesignSpec` / `buildArtifact`. Creating a `pipeline/` directory would collide. |
| Shape calls `agy.exe` | Shape calls the **Hermes bridge** at `/v1/chat/completions`. `agy.exe` is never invoked. |
| Build calls `fcc /v1/messages` directly | Build calls the **Hermes bridge**, then writes the artifact to a `free-claude-code` project and surfaces it at `/api/freeclaude/preview/...`. There is no `public/builds/` directory. |
| Import `fccAdminStatus` | `fccAdminStatus` is **not exported** (`fcc.ts:322`). The plan would not have compiled. |
| `designSpec` is JSON `{summary, components, criteria}` | `designSpec` is a **markdown string** with `## 1. Concept ... ## 9. ...` headings. `PipelineView.tsx:399-534` is the renderer that parses those headings into cards. A JSON refactor would silently break the UI. |
| Do not install `js-yaml` | `js-yaml` is already a dependency of `pipeline.ts`. |
| `C:/Users/.../agy/bin/agy.exe` | **Correct** — verified via `where agy.exe`. But irrelevant, because `agy.exe` is not in the shape flow. |

## What Claude Code did when it received the plan

The user handed the plan to Claude Code. Claude loaded `superpowers:executing-plans`, ran the plan's claims against the live repo, and returned a structured critique:

> "The plan is fundamentally wrong about the current state. There is a complete working pipeline system: `shape/route.ts` and `build/route.ts` already exist and use the `@/lib/pipeline` module with `classifyIdea`, `draftDesignSpec`, `buildArtifact`. The plan would have caused me to overwrite working code with a completely different architecture (`agy.exe` for shape, direct `fetch` to `fcc` for build)."

Claude refused to execute and asked the user to clarify the actual problem before proceeding.

## The actual problem (not what the plan addressed)

After the fabrication was caught, the real root cause was found by reading the live `pipeline.ts` and the live Vault:

- `classifyIdea` puts the JSON contract in the **system prompt** of an LLM call.
- The LLM in question is the Hermes bridge, which is a conversational agent (`minimax/minimax-m2.5`) that **ignores format contracts in system prompts** and answers in prose.
- `classifyIdea` falls back to `{route: "escalate", confidence: 0.5, tags: []}` when the LLM answer is unparseable — that is exactly the signature found in the Vault for `test-idea-from-hermes-probe.md`.
- `draftDesignSpec` only runs when `route === "project"`. Because the fallback route is `escalate`, the Design Spec is never generated, and the UI shows an empty state.

The real fix was a **2-file scoped change to `classifyIdea` and `draftDesignSpec`**: move the format contract from the system prompt to the user turn, raise the token budget, and add an explicit "no code/HTML in spec" rule. No new files, no view edits, no module restructuring.

## What the planner should have done (in the same turn as writing the plan)

1. `git ls-files src/app/api/pipeline` → confirmed `shape/route.ts` and `build/route.ts` already exist. **Stop. The plan's premise is false.**
2. `read_file src/lib/pipeline.ts:1-50` → confirmed `readItem`, `writeItem`, `classifyIdea`, `draftDesignSpec`, `buildArtifact` are all already exported. **Stop. No new `itemStore.ts` needed.**
3. `grep "agy\|fcc" src/lib/pipeline.ts` → confirmed the bridge is the only call site. **Stop. `agy.exe` and direct `fcc` are not in the flow.**
4. `read_file src/lib/fcc.ts:320-330` → confirmed `fccAdminStatus` is **not exported**. **Stop. The plan would not compile.**
5. `read_file src/components/PipelineView.tsx:399-534` → confirmed `DesignSpecView` parses `## N. <name>` markdown. **Stop. JSON designSpec is wrong.**
6. `cat "LOCAL MEMORY VUALT/AGENT OS MEMORY/Agentic OS/Pipeline/items/test-idea-from-hermes-probe.md"` → confirmed the fallback signature in production data. **Now the actual root cause is visible.**

If any of steps 1-5 had been run, the plan would have been a 30-line "adjust two prompts" fix, not a 419-line reimplementation.

## The meta-lesson

**The agent's confidence in the plan came from a stale memory of the local VM copy of the repo.** The laptop (where the system actually runs) was ahead of the VM by 4 new tabs and an entire pipeline module. The agent never checked the laptop directly. The plan was a confident, detailed **fabrication**.

The user caught this only because they had the discipline to make the downstream implementer (Claude Code) load `superpowers:executing-plans` and run a critical-review pass. Without that safety net, the agent would have written a plan, declared it done, and the laptop would have been broken by a parallel-but-incompatible reimplementation.

## The rules that should have fired

1. **`plan` skill** → "Plan that modifies code MUST verify the current state of that code first" (the pitfall this reference supports).
2. **`subagent-driven-development` skill** → "Scope lock before execution" — the implementer must re-verify the plan's structural claims against the live system, not trust the plan.
3. **`[your-product]-architecture-debug` skill** → already documented: "All future `/pipeline` work must start by reading the laptop files, not by assuming the local VM copy is authoritative."

## How to use this reference

When a planner in the future writes a plan that proposes to create files or import symbols, the first question to ask is: **"Did the planner read the live file, or did it remember it?"** If the latter, the plan is suspect. The minimum verification set is `read_file` on every file the plan claims to create or modify, plus `grep "export"` on every symbol the plan claims to import. No exceptions.

This is not a "best practice." It is a hard rule. Plans based on memory have caused a confirmed data loss in the wild.
