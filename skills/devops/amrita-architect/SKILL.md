---
name: amrita-architect
type: standalone
version: 1.0.0
category: development
description: Refine ambiguous ideas inside Hermes Kanban tasks into execution-ready specifications. Use when a Kanban card, product idea, feature request, or messy project concept needs task-embedded requirements discovery, up to three focused clarification questions, blocking for user answers, and a final markdown spec using Hermes Kanban tools rather than a separate tracker.
---

# Amrita Architect

Use this skill to turn a vague Kanban task or product idea into an execution-ready specification without replacing Hermes' global behavior.

## Core stance

- Treat Amrita as a **Kanban workflow**, not a global system prompt.
- Use existing Hermes Kanban lifecycle tools as the source of truth.
- Do not create or rely on a separate `task_embedded_tracker` JSON file.
- Ask **up to 3** high-value clarification questions when critical information is missing. Do not invent filler questions to reach 3.
- Generate the final deliverable only when the task is sufficiently specified or the user explicitly asks to proceed with assumptions.

## Kanban procedure

When running as a Kanban worker:

1. Load task context with `kanban_show` before reasoning from the card.
2. Inspect title, description, comments, labels, links, current status, and assigned scope.
3. Keep state in Kanban comments/metadata, not private files.
4. If user input is required, add a concise comment and call `kanban_block` with the exact unanswered questions.
5. If the spec is ready, call `kanban_complete` with the final markdown deliverable and any structured metadata the tool supports.
6. Create or link follow-up implementation tasks only when the user/task scope allows it.

If not running inside a Kanban worker, still use the same refinement method, but do not claim board updates happened.

## Clarification loop

Track these buckets internally:

- Resolved specifications: decisions clear enough to execute.
- Active gaps: missing decisions that materially affect UX, architecture, security, cost, or scope.
- Assumptions: defaults used to keep progress moving.

When gaps remain, respond with:

```markdown
## Progress
[1–2 sentences reflecting what is understood.]

## Current Gap
- [The operational vector being resolved now.]

## Questions
1. [Focused question]
2. [Focused question]
3. [Focused question]
```

Rules:

- Ask no more than 3 questions.
- Ask fewer if fewer are genuinely needed.
- Do not ask compound questions.
- Prefer concrete choices when ambiguity is high.
- Stop after the questions unless a tool update is required by Kanban lifecycle.

## Ready-to-spec threshold

Before finalizing, ensure these are clear or explicitly assumed:

- Objective and success criteria
- User/persona/operator
- Primary workflow
- In scope and out of scope
- Data, privacy, security, and permission constraints
- Interfaces and integrations
- Edge cases and failure modes
- Acceptance criteria and QA checks
- Implementation slices or follow-up tasks

## Final deliverable template

```markdown
# [Task Name] — Execution Specification

## Objective

## Scope
### In Scope
### Out of Scope

## Users / Actors

## Core Workflows

## Functional Requirements

## Non-Functional Requirements

## Data, Privacy, and Security

## Integrations / Interfaces

## Edge Cases and Failure Modes

## Acceptance Criteria

## Implementation Slices

## Open Risks / Assumptions

## Suggested Kanban Follow-Ups
```

## Safety and anti-patterns

Do not:

- Replace Hermes' global system prompt with Amrita behavior.
- Force exactly 3 questions on every turn.
- Mark Done while critical questions remain.
- Write a shadow board under `./.agentic_os`.
- Swallow persistence exceptions silently.
- Bypass Kanban tools to mutate board state.
- Leak requirements across task IDs or unrelated cards.
- Do implementation work when the current card is refinement-only.

## Completion behavior

Complete the task only when no blocking questions remain. If assumptions remain, list them clearly in the final deliverable. If assumptions are risky, block for review instead of completing.

## Clarification question hygiene

The "up to 3 questions" rule is the ceiling, not the floor — and the **shape** of the question matters as much as the count. Specific shapes that work and shapes that don't:

**Working shapes:**

- **Choice among 2-4 concrete options** with a short description of what each entails in observable outcomes. Example: "Should we (A) build Tauri into the existing web frontend, (B) port the cleaned frontend INTO a fresh Tauri project, or (C) ship web-only for now?" Each option is one line, the consequences are stated in user-facing terms (cost, time, scope), and the user can pick without re-reading docs.
- **Yes/no with one clarifying clause** when there's only one decision point. Example: "Use the system Hermes API key from `~/.hermes/.env`, or do you want me to add a UI for entering your own?"
- **Open-ended with a sharp constraint** when you genuinely need a free-form answer. Example: "Which port should the dev server use? (default is 5173, anything else requires a vite.config change)."

**Shapes that lose the user:**

- **Compound questions** that bundle two or three decisions into one sentence. The user has to read twice, parse the conjunctions, and answer each part separately. Example of the bad shape: "Should we use Tauri, React Native, or Electron, and should it support both mobile and desktop, and do you want me to handle signing too?" — three decisions crammed into one prompt.
- **Long prose explanations before the question** that rehash the problem, repeat the user's own words, or narrate the agent's reasoning. The user already knows the context; they asked the question. The clarification is a fork in the road, not a lecture.
- **4+ options in a single question** when 2-3 would do. The user is supposed to scan and pick, not compare a menu. If 4 truly are credible, split into two sequential questions.
- **Options that overlap or differ only in jargon** (e.g. "React + Vite" vs "React + Webpack" when the user has no webpack/vite context). Distill to the user-visible difference: faster dev vs. more mature tooling.
- **Re-stating the user's prior message** before the question. The user typed it; they don't need to see it again.
- **Asking what was just explained**. If you explained Option A in 200 words and then asked "do you want Option A or Option B", the user has to re-read your explanation to answer. The options should be self-explanatory.

The test: **could the user answer the question in under 10 seconds by picking an option letter?** If yes, the question is shaped correctly. If they have to think, re-read, or ask you a follow-up, the question is too complex or missing a piece they need.

**The "explain simply" override**: if the user says "I don't understand the options, explain more simply", do not paste a longer explanation of the same options. Instead: (1) state the real underlying tradeoff in one sentence ("the choice is between adopting their desktop code or starting fresh"), (2) describe each option in one short clause in terms of what the user will see at the end, (3) ask which one. The user is not asking for more detail; they are asking for less jargon.
