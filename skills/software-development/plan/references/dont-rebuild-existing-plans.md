# Don't Rebuild Existing Plans — Worked Example

Session: June 2026, user asked "look at the `hermes-elevenlabs-ruby`
GitHub repo, what did you do there, why is it broken, and the UI
in Jarvis style is breaking my Telegram — I want a work plan to fix
it according to the Hermes research I gave you."

## What the agent did wrong

1. Cloned the repo and verified the smoke tests pass.
2. Started drafting a "scope clarification" question with three
   choices, one of which was the gateway/Telegram layer the user
   had not asked about.
3. Discovered `[vault-workspace]/[your-product-repo]/` (the
   real app) and `/tmp/jarvis-frontend/` (a fork of Stanford's
   [AssistantProduct] — *not* the user's code) and proposed "let's look
   at all of this."
4. User: "drop the gateway/telegram — that's a separate solved
   problem." Agent then asked another scope question that *re-
   introduced* the same drift.
5. User: "עצור" (stop).

## What existed that the agent missed

- `~/.hermes/skills/software-development/[your-voice-product]-product-squad/references/`
  contained 150+ `.md` files (11k lines) covering prior Ruby voice
  work — gated router, jarvis frontend scaffolds, action safety
  slices, deepgram latency, etc. The agent listed them once but
  never read any of them.
- `[vault-workspace]/[your-product-repo]/src/lib/hermesJarvis.ts`
  was the user's actual Jarvis code (253 lines) — the agent saw
  it, said "looks fine", and moved on.
- `/tmp/jarvis-frontend/` was a Stanford public project, **not the
  user's work**. The agent conflated the two.

## What the right kickoff would have looked like

```
1. Read the 2-3 most relevant references from
   [your-voice-product]-product-squad/references/ (e.g.
   ruby-cloud-jarvis-safe-scaffold.md, ruby-jarvis-gated-router-and-approval-hardening.md,
   cloud-jarvis-phased-delivery.md).

2. Ask the user a 4-axis scope question BEFORE the principles:
   - Repo code (in) — likely yes
   - Gateway/Telegram service (in / out?) — confirm explicitly
   - Jarvis UI surface (in / out?) — confirm explicitly
   - Provider live smokes (out — already verified by smoke-test)

3. After scope is locked, then read the relevant 1-2 source
   files, then summarize the prior research in the user's
   language, then propose 5 principles + plan.

4. If the prior research already covered the ask, the answer
   is "task N of the existing plan" — not a new plan.
```

## Signals that this is a "read prior research first" session

- The repo has a `PLAN.md`, `docs/plans/`, or
  `~/.hermes/skills/.../references/` directory.
- The user references "the research I gave you" or "what the
  Hermes creators published" — they expect continuity, not a
  fresh take.
- The user has explicitly said "read the docs first" or "תקרא
  קודם" in past turns.

## Anti-patterns the agent must avoid

- Listing 50 reference files and then reading none of them.
- Asking scope questions whose options *include* things the
  user has implicitly excluded.
- Re-introducing scope items after the user removed them.
- Confusing a third-party project (e.g. a Stanford fork) with
  the user's own work — they look similar in `find` output but
  have different provenance.

## Key behavioral fixes (one-liner each)

- "If references/ has >20 files on the topic, read at least 2
  before drafting anything."
- "Confirm scope with explicit in/out axes; never as a
  multiple-choice bundle that includes everything."
- "When user says stop / עצור / תוריד X, lock the new scope and
  do not reintroduce the removed items in later turns."
- "When `find` returns a path that looks like the user's project
  but has a public-project README (paper link, leaderboard,
  Stanford/Berkeley/etc.), it is a fork, not the user's code —
  treat as out of scope unless the user points to it."
