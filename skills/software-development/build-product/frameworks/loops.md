# Quality Loops for build-product (v1.2)

Seven feedback loops that wrap existing build-product phases. Each loop is
bounded (max_iter, exit conditions, failure handling). All loops are adapted
from internal design rules — see the design rules section below.
canonical source.

**When to load this file:** any time a build task might spin, produce
uncertain output, or lack a clear "we're done" signal. Default: load on every
`/build-product new|feature|stuck|ship`.

**Design rules:**
1. Observe → Choose → Act → Verify → Record → Repeat or stop
2. Success / clean no-op / blocked / approval-required / exhausted / stagnated
   outcomes are explicit
3. **No-progress stops** are mandatory when no user-supplied budget exists
4. Independent verification when the same actor should not both create and
   approve (builder ≠ reviewer)
5. Reversible / destructive / production / privacy-sensitive actions require
   explicit the user approval

---

## Loop 1: Plan Quality Loop (Goal Forge adaptation)

**Where it plugs in:** `new-product.md` Phase 2 (after writing-plans produces
the first-slice plan) and `build-feature.md` Phase 2 (after feature plan).

**Intent:** Verify the plan is concrete enough that a fresh subagent could
execute it without re-asking the user.

**Trigger:** Plan is written and the user approved it verbally.

**Body:**

```markdown
## Plan Quality Loop

After the user approves the plan, a fresh subagent (not the one who wrote the
plan) tries to execute it in isolation.

[Read the plan from .hermes/plans/. Read AGENTS.md + package.json from the
target repo. Then attempt the first 3 tasks of the plan with zero additional
context from the orchestrator.]

After each attempt, [run the test suite + smoke check the touched files].
Keep only plans where every first-3-tasks attempt either completes GREEN or
surfaces a concrete, fixable ambiguity in the plan itself.

Stop when [all 3 first tasks execute green in isolation, OR a concrete
ambiguity is identified in the plan]. Ask the user before [fixing the plan
based on the ambiguity, or proceeding with the original].

Max iterations: 3. After 3 unsuccessful attempts → escalate to the user with
the specific ambiguity list (NOT a 10-bullet "consider X" dump).
```

**Why it exists:** "if a task fails twice → STOP" in Phase 3 is reactive —
this is proactive. It catches "plan was approved but is ambiguous" before
the build spins for 30 minutes.

**Anti-pattern this prevents:** "the user approved the plan" treated as
sufficient signal. The plan can be approved and still be un-executable by a
fresh agent (assumes context the user didn't realize was implicit).

---

## Loop 2: Builder-Reviewer Loop

**Where it plugs in:** `new-product.md` Phase 3 and `build-feature.md` Phase 3
(wraps `subagent-driven-development`).

**Intent:** Every task subagent writes code is reviewed by a SEPARATE
subagent before commit. If review fails, feedback goes back to the builder
for one bounded retry.

**Trigger:** Builder subagent reports a task GREEN.

**Body:**

```markdown
## Builder-Reviewer Loop

After every builder subagent reports GREEN, [spawn a fresh `cavecrew-reviewer`
subagent with the diff + the task's spec]. The reviewer returns one of:
- PASS (commit and move on)
- SPEC_MISMATCH (feedback to builder, retry once)
- QUALITY_ISSUE (file as MAJOR, don't block, move on)

Stop when [reviewer returns PASS or QUALITY_ISSUE]. Escalate to the user when
[builder fails twice on the same task with SPEC_MISMATCH feedback].

Max iterations per task: 1 retry. The original "if a task fails twice →
stuck-recover" rule still applies AFTER the retry.
```

**Why it exists:** Builder and reviewer are now independent agents —
prevents "I tested it myself and it works" self-approval.

**Anti-pattern this prevents:** Same-actor bias where the subagent that
wrote the code also signs off on it.

---

## Loop 3: Smoke Test Retry Loop

**Where it plugs in:** `new-product.md` Phase 4B and `ship.md` Phase 2C.

**Intent:** Smoke test is flaky or environment-dependent. A single failure
should not block ship — a clean retry should be allowed.

**Trigger:** Smoke test returns FAIL on first run.

**Body:**

```markdown
## Smoke Test Retry Loop

If the smoke test fails on first run, [re-read the failure, classify it
(env-flake vs real-bug), then re-run the smoke test once with the same
inputs].

Stop when [smoke passes, OR fails again with the same root cause].
Escalate to the user when [second attempt fails with the same root cause —
this is the trigger for stuck-recover, NOT a 3rd attempt].

Max iterations: 1 retry. NEVER retry a 3rd time — that is masking a bug,
not fixing one.
```

**Why it exists:** Distinguishes "test infra was cold" from "the feature
is broken". One retry catches the first; two failures on the same root
cause is always a real bug.

**Anti-pattern this prevents:** "Smoke failed, let me just run it again"
infinite retry pattern that hides real issues.

---

## Loop 4: Pre-Ship Quality Loop

**Where it plugs in:** `ship.md` Phase 1 (code review) → Phase 2 (build +
smoke).

**Intent:** CRITICAL review findings must be fixed and re-reviewed before
the build/smoke phase begins. MAJOR findings require the user decision.

**Trigger:** Code review returns one or more CRITICAL findings.

**Body:**

```markdown
## Pre-Ship Quality Loop

If `requesting-code-review` returns CRITICAL findings, [route them back to
the builder for surgical fixes via `cavecrew-builder`, then re-run the
review on the patched diff]. If CRITICAL persists after one fix attempt,
[stop and escalate to the user with the full review diff + fix attempt].

Stop when [the second review returns 0 CRITICAL]. Max iterations: 2 review
rounds. After 2 rounds with CRITICAL remaining → escalate to the user with
the option to (a) accept the risk, (b) cut scope, (c) halt ship.

For MAJOR findings: [collect them as a follow-up list, do NOT block ship].
```

**Why it exists:** Today, a single "CRITICAL found → fix → ship anyway"
chain is possible if the user is in a hurry. This loop forces explicit
re-review and bounds the fix attempts.

**Anti-pattern this prevents:** "The CRITICAL is minor, just ship it" —
the user's call, but only AFTER an explicit second review confirms it's
truly blocking.

---

## Loop 5: state-update.sh Self-Loop Detection

**Where it plugs in:** Whenever the orchestrator is driving `state-update.sh`
multiple times in one session.

**Intent:** Prevent runaway state-machine updates that bury real changes
under noise.

**Trigger:** Same `state-update.sh` action called 5+ times in one session
on the same `state.md` file.

**Body:**

```markdown
## State Update Self-Loop Detection

If `state-update.sh <action>` has been called 5+ times with no
intervening commit or phase change, [STOP and surface to the user: "I've
called <action> N times. Either (a) commit current state, (b) consolidate
the changes into one update, (c) escalate if stuck"].

Stop when [the user confirms the state is correct, or a phase transition
resets the counter]. Max iterations before surface: 5 same-action calls.
```

**Why it exists:** The state machine is great when it represents reality.
It's noise when the orchestrator updates the same field repeatedly
without committing — the user will lose trust in `state.md`.

**Anti-pattern this prevents:** "Let me just update state one more time"
pattern that creates a state.md that drifts from git history.

---

## Loop 6: Deploy Retry Loop (Cloudflare)

**Where it plugs in:** `deploy-to-cloudflare.md` (the Phase 6 / 5.5 default).

**Intent:** Cloudflare deploys can fail transiently (Workers quota, Access
propagation lag, wrangler cold start). Bounded retry catches the transient
failures without masking real config bugs.

**Trigger:** `wrangler deploy` or `cloudflare-deploy` skill returns non-zero
exit.

**Body:**

```markdown
## Deploy Retry Loop

If the deploy command returns non-zero, [classify the error: TRANSIENT
(network/5xx/rate-limit) vs PERMANENT (config/wrangler.toml syntax/secrets)].

For TRANSIENT: [sleep 30s, retry]. Stop when [deploy succeeds or PERMANENT
is identified]. Max iterations: 3 retries with 30s + 60s + 120s backoff.

For PERMANENT: [stop and surface the specific error to the user — never
auto-fix wrangler.toml or secrets].

For SUCCESS but Cloudflare Access not yet propagated: [poll
/.well-known/cloudflare-access for 200, max 2 min, then surface "Access
propagation taking longer than expected" with manual verification steps].
```

**Why it exists:** Distinguishes "wrangler is being slow" from "you have
a config bug". The retry budget is fixed and visible.

**Anti-pattern this prevents:** Silent infinite retries that mask
typos in wrangler.toml, or Access URLs that never actually protect the
endpoint.

---

## Loop 7: Build Reflection Loop

**Where it plugs in:** `ship.md` Phase 4 (wrap up).

**Intent:** After every successful ship, the orchestrator reflects on what
went well / poorly and proposes durable rules. This is the "meta-loop" that
makes build-product get smarter over time.

**Trigger:** `ship.md` completes with smoke test GREEN and the user approves
production deploy.

**Body:**

```markdown
## Build Reflection Loop

After every shipped slice, [spawn a single reflection subagent with this
prompt: "Review the last build-product session. Output 3 things: (1) What
worked well and should be repeated, (2) What failed and the smallest fix,
(3) Any reusable rule that would apply to future builds. Append (3) to
Skill Candidates if the rule is general. Do not invent rules that fit
this build but not others."]

Stop when [the reflection subagent returns its 3 items OR 5 minutes
elapsed]. The orchestrator then surfaces these 3 items to the user for
approval before persisting them.

Max iterations: 1 reflection per ship. Never run the reflection twice on
the same session (overfitting risk).
```

**Why it exists:** The state file gets updated per build, but lessons
learned evaporate if not reflected on. This is the
`skill-library/Skill Candidates` update path that the cron distiller
already uses — but triggered automatically after every ship.

**Anti-pattern this prevents:** "We learned this lesson last month but
forgot it because nobody wrote it down."

---

## Loop 8: PRD Completeness Loop (new in v1.2.0)

**Where it plugs in:** `prd-generator` after Phase 1 produces a draft PRD.

**Intent:** A fresh subagent checks the PRD for missing sections,
internal contradictions, and "would a fresh agent be able to build from this?".
Catches the "looks complete but isn't" trap.

**Trigger:** `prd-generator` produces a PRD draft.

**Body:**

```markdown
## PRD Completeness Loop

A fresh subagent (NOT the one that ran the interview) reads the PRD and:
1. Verifies every required section is present (Goals, Non-goals, User
   Stories, Acceptance Criteria, Edge Cases, Open Questions).
2. Checks that User Stories map to Acceptance Criteria.
3. Flags any "we'll figure it out later" handwaves.
4. Returns one of:
   - COMPLETE (proceed to build)
   - GAP_FOUND (specific list of gaps, ask the user to address)
   - CONTRADICTION (flag the conflicting statements, ask the user)

Stop when [COMPLETE OR the user addresses the gaps]. Escalate to the user
when [a second pass still finds gaps].

Max iterations: 2 passes. After 2, the PRD is "good enough" — note
remaining gaps as known limitations and move on.
```

**Why it exists:** the user is fast at interviews but might skip questions
("let's just build it"). A second pair of eyes catches what he missed
without re-asking him.

**Anti-pattern this prevents:** "the user approved the PRD" treated as
proof of completeness. PRDs can be approved and still have hidden gaps
that bite during build.

---

## Loop 9: Contract-Code Drift Loop (new in v1.2.0)

**Where it plugs in:** `api-contract-designer` after spec + types generated.

**Intent:** Verify that generated TypeScript types compile and that
example requests pass Zod validation. Catches "spec looks right but
codegen broke".

**Trigger:** `api-contract-designer` produces OpenAPI/GraphQL spec and
generated types.

**Body:**

```markdown
## Contract-Code Drift Loop

After types are generated:
1. [Run `tsc --noEmit` on the generated types file — must compile clean].
2. [Take 2 example endpoints from the spec — build example request bodies,
   parse them through the Zod schemas, must succeed].
3. [Take 2 example responses — parse them through response schemas, must
   succeed].

Stop when [all 3 checks pass OR a real spec bug is found]. Fix the spec
and regenerate. Escalate to the user when [the same endpoint fails 3 times
— the design itself may be broken].

Max iterations: 3. After 3 failures on the same endpoint, escalate to
the user with the specific contradiction between spec and reality.
```

**Why it exists:** Specs and code drift silently. Without this loop, you
ship an "OpenAPI compliant" API that breaks the moment a real client
hits it.

**Anti-pattern this prevents:** "I generated the types, looks fine" —
without actually compiling or validating, the types might be subtly
broken (Date vs DateTime, optional vs nullable, etc).

---

## Loop 10: Flaky Test Quarantine Loop (new in v1.2.0)

**Where it plugs in:** `e2e-testing` when a test fails 3 times in the
same CI run.

**Intent:** Distinguish "real bug" from "flaky environment" without
silently passing flaky tests. Quarantine, don't auto-skip.

**Trigger:** Same e2e test fails 3 times in a single CI run (counted
within the run, not across runs).

**Body:**

```markdown
## Flaky Test Quarantine Loop

After a test fails 3 times:
1. [Tag the test `@flaky` in its filename and code].
2. [Move it to `tests/quarantined/` directory — still runs, but failures
   don't block CI].
3. [Open a GitHub issue automatically with: test name, failure pattern,
   last 3 failure logs, "needs investigation"].
4. [Surface to the user: "X test is now quarantined — needs your eyes"]

Stop when [the user either fixes the test OR explicitly accepts the
quarantine for >7 days]. Escalate to the user when [quarantined tests
exceed 10 — that means the test suite is rotting].

Max quarantine period without action: 7 days. After 7 days, the test
either gets fixed or gets deleted (with the user approval).
```

**Why it exists:** Flaky tests are toxic — either you ignore them
(loses signal) or you block on them (loses velocity). Quarantine
preserves both: the test runs, but doesn't gate, and is tracked.

**Anti-pattern this prevents:** "Just retry until it passes" — masks
real bugs in race conditions. Also prevents "delete the flaky test"
which loses coverage.

---

## Loop 11: Cost Guardrail Loop (new in v1.2.0)

**Where it plugs in:** `analytics-monitoring` runs hourly / daily.

**Intent:** Catch runaway costs (OpenAI tokens, Cloudflare Workers
requests, Supabase storage) before the bill arrives. Surface to the user
when a single day's spend exceeds the threshold.

**Trigger:** `analytics-monitoring` detects daily spend > configured
threshold (default: $10/day for dev, $100/day for prod).

**Body:**

```markdown
## Cost Guardrail Loop

Hourly:
1. [Read current day spend from each provider's API/billing endpoint].
2. [If day_spend > threshold_daily: trigger Telegram alert with specific
   service, current spend, projected month-end].
3. [If projected month spend > threshold_monthly: trigger WARNING alert
   with "consider pausing this service"].

Stop when [the user acknowledges OR threshold is recalibrated OR service
is paused]. Escalate to the user when [3 consecutive days over threshold
without response — automatic pause of the offending service IF
configured to allow it].

Max iterations per day: 1 alert per service (no spam). Reset threshold
state at midnight UTC.
```

**Why it exists:** A misconfigured cron or runaway loop can burn
hundreds of dollars overnight. Catching it at $10 vs $1000 is the
difference between "oops" and "f***".

**Anti-pattern this prevents:** "I'll check the bill at end of month"
— by then it's too late. Also prevents "alerts that fire on every
single event" (alert fatigue).

---

## Loop 12: Legal Disclaimer Verification Loop (new in v1.2.0)

**Where it plugs in:** `privacy-tos-generator` before publishing any
legal doc.

**Intent:** Enforce the "this is not legal advice" disclaimer on every
generated legal document. Prevent accidental publication of
un-disclaimed legal text (which creates real legal exposure for
the user).

**Trigger:** `privacy-tos-generator` produces any legal doc (Privacy
Policy, ToS, Cookie Banner, DPA).

**Body:**

```markdown
## Legal Disclaimer Verification Loop

After any legal doc is generated:
1. [Grep the doc for "This is template boilerplate, not legal advice"
   OR the Hebrew equivalent "זה תבנית, לא ייעוץ משפטי"].
2. [Verify the disclaimer appears at the TOP (first 500 chars) AND in
   a footer].
3. [Verify "consult a lawyer" appears at least once in body or footer].

Stop when [all 3 checks pass]. Block publication when [any check fails]
— fix the doc and regenerate. Escalate to the user when [the user asks to
remove the disclaimer — refuse and explain the risk].

Max iterations: 3 (regeneration attempts). After 3, stop and surface
the doc to the user with "disclaimer is missing or in wrong place —
manual fix required before publishing".
```

**Why it exists:** Templates that look like legal advice create real
liability. This loop protects from accidental non-compliance — many builders underestimate regulatory complexity.

**Anti-pattern this prevents:** "Clean up the boilerplate before
shipping" — the user might delete the disclaimer thinking it's just
template noise. This loop catches that.

---

## Loop 13: Stripe Webhook Health Loop (new in v1.2.0)

**Where it plugs in:** `pricing-monetization` after Stripe integration.

**Intent:** Webhook failures are silent and expensive. A missed
`invoice.paid` webhook means a paying customer whose account you
think is unpaid (or vice versa).

**Trigger:** Daily cron (set via `analytics-monitoring` or independent).

**Body:**

```markdown
## Stripe Webhook Health Loop

Daily:
1. [Query Stripe for webhook delivery attempts in the last 24h].
2. [Count: total attempts, succeeded, failed permanently (4xx not retried),
   still retrying].
3. [If any webhook event has >5 failed attempts: alert the user with
   event type + customer ID + error message].
4. [If overall success rate < 99%: alert the user — webhook endpoint may
   be down].

Stop when [all webhooks for the day succeeded OR the user acknowledges
the failures]. Escalate to the user when [same webhook event fails 10
times across 3 days — likely a code bug in our handler].

Max iterations per day: 1 summary + per-failure alerts (cap at 5/day
to prevent alert fatigue).
```

**Why it exists:** Webhooks fail silently. Stripe retries 3 days then
gives up — by then the customer is in a bad state.

**Anti-pattern this prevents:** "I'll check the Stripe dashboard
weekly" — weekly is too late. Also prevents building webhook handlers
without observability.

---

## Loop 14: Onboarding Activation Loop (new in v1.2.0)

**Where it plugs in:** `customer-support-templates` after drip campaign
sends.

**Intent:** Users who don't activate in 7 days churn. Catch them
before they leave with a personal touch (not another automated
email).

**Trigger:** User signed up but hasn't completed the "activation
event" (defined per product, e.g., "created first project") within 7
days.

**Body:**

```markdown
## Onboarding Activation Loop

Daily:
1. [Query DB for users where: signed_up_at < now() - 7 days AND
   activation_event_at IS NULL AND has_not_been_personal_contacted].
2. [For each, generate a personal-email draft using the
   `customer-support-templates/churn-prevention-email` task with
   reason = "didn't activate"].
3. [Send ONLY after the user approves the draft — never auto-send].

Stop when [user activates OR the user sends the personal email]. Escalate
to the user when [>20 users in the activation-stuck queue — something
in onboarding is broken].

Max iterations: 1 personal email per stuck user (don't spam). Reset
the "has_been_contacted" flag if user unsubscribes.
```

**Why it exists:** Automated drip campaigns stop converting after
email 3. A personal email from the founder at day 7 is the
highest-ROI intervention in the entire funnel.

**Anti-pattern this prevents:** "Send more emails" — noise. Also
prevents "let them churn, they'll come back" — they won't.

---

## Loop 15: Idea Refinement (amrita-architect)

**Where it plugs in:** Phase 0 (Intake) of `tasks/new-product.md` — every
"build me X" request with a vague description.

**Intent:** Force a bounded clarification exchange (≤ 3 questions) so
downstream skills (`prd-generator`, `plan`, `build-feature`) get a
spec, not a guess.

**Trigger:** User says "I want to build X" and X is described in ≤ 2
sentences, OR a Kanban card has only a 1-line description.

**Body:**
```
Per turn:
1. [Read the original idea verbatim — do not paraphrase yet].
2. [Internally classify into: Resolved / Active gaps / Assumptions].
3. [If Active gaps exist, ask ONE question — only the highest-value one].
4. [After the user answers, re-classify; ask the next question only if
   the answer materially changes the spec].
5. [Stop asking as soon as remaining gaps would not change the spec].
6. [Produce the spec using the 9-threshold template from
   `amrita-architect/tasks/refine-idea.md`].
```

**Stop when:** (a) the 9-threshold template is fully resolved OR has
explicit assumptions listed, AND (b) the user approves the spec.

**Max iterations:** 3 questions. Hard cap. Never invent filler
questions to reach 3.

**Escalate to the user when:** the user refuses to answer (the loop is
not making progress → route to `stuck-recover`).

**Anti-pattern this prevents:** "Just start coding, you'll figure it
out" — agents that build the wrong product in 3 hours. Also prevents
"ask 10 questions until the user gives up" — agents that never ship.

---

## Loop 16: Hermes Config Validation (hermes-config-validation)

**Where it plugs in:** Phase 0.5 (Hermes setup) of `tasks/new-product.md`
— before any code is written for a project that depends on Hermes
TTS / STT / MCP / plugins / personalities.

**Intent:** Catch silent config errors BEFORE coding, not 3 hours
into a build when the documented key is ignored by the runtime, or
the tool has no public HTTP endpoint.

**Trigger:** Project involves any Hermes built-in provider (TTS, STT,
MCP, plugin, personality) OR a non-gateway frontend (web UI, mobile
app) on top of Hermes.

**Body:**
```
Once before any feature design:
1. [Read the user's current `~/.hermes/config.yaml` and version].
2. [For each config key the user wants, check the corresponding
   reference file (e.g. `hermes-v0.16-tts-builtins.md`) — is the key
   actually honored by the installed source?].
3. [For each Hermes tool the user wants to expose, check
   `hermes-config-validation` references — is there an HTTP endpoint, or is
   it only invokable from inside an agent turn?].
4. [For each stored API key (NEVER the literal — reference the file
   path at `~/.config/<service>/`), run the live-credential smoke].
5. [Produce a report with ✅ / ⚠️ / ❌ + exact remediation].
6. [Block any subsequent design / coding if any ❌ is unresolved].
```

**Stop when:** all ⚠️ have been acknowledged AND all ❌ have been
resolved (or the user explicitly accepts the risk).

**Max iterations:** 1 (this is a one-shot validation, not a retry
loop). The loop is bypassed entirely if the project does not use
Hermes built-in providers.

**Escalate to the user when:** a documented key is silently ignored —
this is a Hermes bug, not a user error. File in `references/` and
in the built-in loops catalog (this file) if pattern repeats.

**Anti-pattern this prevents:** "Just try it, see if it works" —
silently ignored keys = silent failure = 3 hours wasted. Also
prevents the trap where developers assume an HTTP endpoint exists for
a tool that is only invoked from inside an agent turn.

---

## Loop 17: Dogfood Pre-Ship (dogfood)

**Where it plugs in:** Phase 5.5 (Pre-Ship QA) of `tasks/build-feature.md`
and `tasks/ship.md` — after `e2e-testing` smoke tests pass, before
`/build-product ship`.

**Intent:** Catch real-world bugs (silent JS errors, broken navigation,
visual regressions, accessibility issues) that the deterministic smoke
tests miss, before users hit them.

**Trigger:** A new user-facing flow is added (any PR that changes
a route, a form, a button, or the home page) AND the project has a
public URL (staging or production).

**Body:**
```
Once per pre-ship:
1. [Run `dogfood/tasks/qa-test.md` against the public URL — explore
   the new flow + 3 adjacent flows that the change might have broken].
2. [Take a screenshot per issue found; classify by severity
   (Critical/High/Medium/Low) + category (Functional/Visual/
   Accessibility/Console/UX/Content) using
   `dogfood/references/issue-taxonomy.md`].
3. [Save the report to `{output_dir}/report.md` and embed screenshots
   with `MEDIA:<path>`].
4. [Block the ship if any Critical issue is found].
5. [Re-run after fixes — verify the Critical is gone].
```

**Stop when:** all Critical and High issues are fixed, OR the user
explicitly accepts the risk with a "ship anyway with known issues"
note in the report.

**Max iterations:** 1 dogfood pass per pre-ship. Do NOT loop until
all Medium / Low are fixed — those go to a follow-up issue, not a
ship blocker.

**Escalate to the user when:** a Critical issue is found in production
(rollback first, then dogfood, then fix, then re-ship).

**Anti-pattern this prevents:** "The smoke tests pass, ship it" —
smoke tests are deterministic and miss visual / UX / accessibility
bugs. Also prevents "we'll fix it after launch" — fixing a Critical
post-launch is 10x more expensive than fixing it pre-ship.

---

## How the loops fit together (run order)

```
new-product.md:
  Phase 0 → Phase 1 (brief) → Phase 2 (plan)
                              ↓
                          [Loop 1: Plan Quality]   ← catches ambiguous plans
                              ↓
                          Phase 3 (execute)
                              ↓
                          [Loop 2: Builder-Reviewer per task]   ← catches self-approved bugs
                              ↓
                          Phase 3.5 (auth)
                              ↓
                          Phase 4 (review + smoke)
                              ↓
                          [Loop 3: Smoke Retry if FAIL]   ← catches env flakes
                              ↓
                          Phase 5 (decide next)
                              ↓
                          Phase 6 (deploy)
                              ↓
                          [Loop 6: Deploy Retry if FAIL]   ← catches transient CF errors
                              ↓
                          [Loop 7: Reflection]   ← captures lessons

ship.md:
  Phase 0 (pre-flight) → Phase 1 (review)
                              ↓
                          [Loop 4: Pre-Ship Quality if CRITICAL]   ← catches unfixed CRITICALs
                              ↓
                          Phase 2 (build + smoke) → Phase 3 (deploy)

state-update.sh:
  [Loop 5: Self-Loop Detection on repeated calls]
```

## References

- Loop engineering is fully internal — see the design rules and templates above.
- Source loop IDs from catalog (if you want to read the originals):
  - #27 builder-reviewer loop
  - #35 goal-forge loop
  - #43 prepare-a-new-project loop
  - #44 test-stabilizer loop (related to Loop 3)
  - #45 artifact-to-skill loop (related to Loop 7)

## Loop 18: Israeli Deploy Window (shabbat-aware-scheduler) — NEW v1.4.0

**When**: Phase 7 (Deploy) — before pushing to Cloudflare.

**Why**: Israeli products must not auto-deploy during Shabbat or major Jewish holidays. A naive cron + Friday 5pm deploy = users seeing failed deploys at sundown. Bad UX, halachically problematic for Israeli business users.

**The loop**:

1. **Pre-deploy check** — invoke `shabbat-aware-scheduler` skill to compute:
   - Current zmanim (sunset, candle-lighting, havdalah)
   - Holiday status (Yom Tov, Chol HaMoed, regular Shabbat)
   - Next safe deploy window (earliest post-Havdalah OR next Sunday morning for Yom Tov)
2. **Defer if needed** — if now is Shabbat/Yom Tov → reschedule deploy to next safe window. Notify the user: "Deploy deferred to Sunday 19:30 (post-Shabbat)." Block the build until then.
3. **Force-deploy escape hatch** — if the user explicitly types `--force deploy` and confirms "I take responsibility for Shabbat deploy", proceed. Log the override in the deploy state file.
4. **Cache window per build** — once the safe window is known for this build, don't recompute it. Move on to the next phase.

## Israeli Deploy Window

```bash
# Compute safe window
safe=$(shabbat-aware-scheduler --check-now --json | jq '.next_safe_window')

if [[ "$(date +%s)" -lt "$safe" ]]; then
  echo "Deploy deferred to $(date -d @$safe)"
  exit 0  # Block deploy, continue other phases
fi

# Proceed with normal deploy
./deploy-to-cloudflare.sh
```

**Pitfall**: a Friday afternoon deploy that finishes at 4:50pm in June will hit the user's customers during Shabbat. Use this loop.

## Loop 19: Marketing Asset Build (hyperframes + popular-web-designs) — NEW v1.4.0

**When**: Phase 6 (Polish & Showcase) — after the product is built, before the launch announcement.

**Why**: most builds ship the product but forget marketing assets — landing-page hero image, 30-second demo video, social card, animated explainer. Without these, the launch looks bare. `hyperframes` (HTML→video) and `popular-web-designs` (54 reference designs) cover both needs.

**The loop**:

1. **Identify assets needed** — pick from: hero image, demo video (30-60s), social card (1200×630), explainer animation, email banner. Default = first 3.
2. **Reference design first** — `popular-web-designs` provides 54 production design systems (Stripe, Linear, Vercel, etc.) as starting templates. Pick one that matches the product's audience.
3. **Build the video assets with hyperframes** — write HTML composition, render to MP4/WebM via the skill. Each asset has its own composition file under `marketing/assets/<name>/`.
4. **Smoke test** — play the video in a browser. Check first frame, audio sync, captions.
5. **Bundle** — put all assets in `marketing/` folder with `marketing/README.md` listing what each is for.

## Marketing Asset Build

```bash
# Reference design
popular-web-designs --select stripe-marketing --render > hero.html

# Build video assets
hyperframes --compose hero-video --output marketing/hero.mp4
hyperframes --compose social-card --output marketing/social.mp4

# Smoke test
ffprobe marketing/hero.mp4 2>&1 | grep Duration
```

**Pitfall**: skipping this loop means the product launches with just a GitHub link. Israeli audiences expect polish — a hero video + Hebrew landing page is the difference between 10 signups and 100.

## Loop Coverage Matrix (v1.4.0)

| Skill | Loops applied | Coverage |
|-------|---------------|----------|
| `prd-generator` | Loop 8 (Completeness) | ✅ |
| `api-contract-designer` | Loop 9 (Drift) | ✅ |
| `e2e-testing` | Loop 3 (Smoke Retry) + Loop 10 (Flaky Quarantine) | ✅ |
| `analytics-monitoring` | Loop 11 (Cost Guardrail) | ✅ |
| `privacy-tos-generator` | Loop 12 (Legal Disclaimer) | ✅ |
| `pricing-monetization` | Loop 13 (Stripe Webhook Health) | ✅ |
| `customer-support-templates` | Loop 14 (Onboarding Activation) | ✅ |
| `amrita-architect` | Loop 15 (Idea Refinement) | ✅ |
| `hermes-config-validation` | Loop 16 (Hermes Config Validation) | ✅ |
| `dogfood` | Loop 17 (Dogfood Pre-Ship) | ✅ |
| `shabbat-aware-scheduler` | Loop 18 (Israeli Deploy Window) | ✅ NEW v1.4.0 |
| `hyperframes` + `popular-web-designs` | Loop 19 (Marketing Asset Build) | ✅ NEW v1.4.0 |
| `hebrew-voice-bot-builder` / `n8n-hebrew-workflows` / `greenapi-whatsapp-bot-builder` | (feature implementations — no dedicated loop, called via tasks) | ✅ |
| `cloudflare-deploy` | Loop 6 (Deploy Retry) | ✅ |
| `supabase-auth-patterns` | Loop 2 (Builder-Reviewer) via build-product | ✅ |
| (meta — design + audit other loops) | — | — |
| `plan` / `writing-plans` | Loop 1 (Plan Quality) | ✅ |
| `requesting-code-review` | Loop 2 (Builder-Reviewer) + Loop 4 (Pre-Ship) | ✅ |
| `incremental-hardening-refactor` | Loop 5 (Self-Loop Detection) | ✅ |

**Total loops in build-product v1.4.0: 19** (17 from v1.3.0 + 2 new for Israeli deploy + Marketing assets).

## Changelog (loops.md)

- v1.4.0: +2 loops (Israeli Deploy Window via shabbat-aware-scheduler, Marketing Asset Build via hyperframes + popular-web-designs)
- v1.3.0: +3 loops (Idea Refinement, Hermes Config Validation, Dogfood Pre-Ship)
- v1.2.1: +7 loops (Completeness, Drift, Flaky Quarantine, Cost Guardrail, Legal Disclaimer, Stripe Webhook, Onboarding Activation) + Loop Coverage Matrix
- v1.0.0: 7 original loops (Plan Quality, Builder-Reviewer, Smoke Retry, Pre-Ship, Self-Loop, Deploy Retry, Reflection)
