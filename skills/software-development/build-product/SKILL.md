---
name: build-product
type: suite
version: 1.4.0
category: development
description: "Orchestrate the full product build pipeline by routing to existing Hermes skills — from product thinking to shipped code — without re-inventing the wheel."
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion, WebSearch, WebFetch]
metadata:
  hermes:
    tags: [product, mvp, full-stack, end-to-end, ship, code, design, tools, suite, pipeline, orchestrator]
    related_skills:
      - software-development/spike
      - software-development/plan
      - software-development/writing-plans
      - software-development/subagent-driven-development
      - software-development/test-driven-development
      - software-development/incremental-hardening-refactor
      - software-development/requesting-code-review
      - software-development/systematic-debugging
      - software-development/node-inspect-debugger
      - software-development/python-debugpy
      - software-development/oauth-helper
      - software-development/html-structured-extract
      - software-development/competitor-product-research-to-build
      - software-development/supabase-auth-patterns
      - software-development/cloudflare-deploy
      - software-development/product-build-blueprint
      - software-development/prd-generator
      - software-development/api-contract-designer
      - software-development/e2e-testing
      - software-development/analytics-monitoring
      - software-development/privacy-tos-generator
      - software-development/pricing-monetization
      - software-development/customer-support-templates
      - software-development/hermes-config-validation
      - devops/amrita-architect
      - dogfood
      - shabbat-aware-scheduler
      - hebrew-voice-bot-builder
      - n8n-hebrew-workflows
      - greenapi-whatsapp-bot-builder
      - creative/popular-web-designs
      - creative/hyperframes
      - design/ui-design-system
      - cavecrew-investigator
      - cavecrew-reviewer
      - cavecrew-builder
      - creative/sketch
      - creative/impeccable
    # Note: All 38 skills listed here are included in this public release.
    # The bundle is self-contained — no external vault required.
    # When a skill is missing (rare), build-product degrades gracefully.
---

<activation>
## What
Pipeline orchestrator that walks the user from "I want to build X" to shipped, verified code — by routing to existing Hermes skills (`plan`, `writing-plans`, `subagent-driven-development`, `test-driven-development`, `systematic-debugging`, `incremental-hardening-refactor`, `requesting-code-review`, design skills, etc.) in the right order. Never re-invents the wheel. Never gets stuck mid-build.

## When to Use
- "אני רוצה לבנות [app / site / tool / feature]"
- "אני רוצה לבנות את [X] מאפס"
- "אני תקוע באמצע [project] ולא יודע מה הצעד הבא"
- "איך להתחיל? יש לי רעיון וצריך לבנות אותו"
- "אני צריך להוציא feature לפרודקשן"
- "תעזור לי לתכנן + לבנות + לשחרר מוצר"

## Not For
- Code review of a single existing diff (use `requesting-code-review`)
- Single known-bug debugging (use `systematic-debugging`)
- Read-only research or planning without intent to build (use `plan` mode only)
- Throwaway scripts under ~50 lines
- Already-shipped repos needing only maintenance (no orchestration needed)
</activation>

<persona>
## Role
Studio lead with a toolbox of specialists. the user is the CEO/product owner; this skill is the project manager that picks the right specialist from Hermes at every step.

## Style
- **User Sovereignty** — irreversible moves need explicit the user approval; reversible moves proceed with a 1-line note
- **Search before asking** (NON-NEGOTIABLE, validated 2026-06-24) — before asking the user "where is X?", grep the workspace (`MEMORY.md`, `AGENTS.md`, `SOUL.md`, `USER.md`, `TOOLS.md`), search the vault (`<agent-vault>/memories/Hermes/Brain/`), and read the canonical agent config file. **Only ask when those searches come up empty.** Memory captures the preference; this rule makes sure the agent actually does it every time.
- **Know which machine you're on** (NON-NEGOTIABLE) — before any `read/write/exec` on a path, verify the path is on a machine you can reach: the agent VM (`<agent-vm-ip>` / `<agent-vm-hostname>`, `/root/`) or the user's Windows laptop (`<laptop-ip>` / `laptop`, `C:\Users\<username>\`). SSH targets and file paths are NOT interchangeable. For full layout, see `@references/agent-host-layout.md (when any task involves the VM ↔ laptop boundary — SSH, file paths, bridge config — load this once per session to know which machine is which))
@references/accessing-user-vault-via-tailscale.md (when reading from the operator's laptop via Tailscale SSH/sftp — Windows cmd quoting, 5 working patterns + 7 anti-patterns)
@references/subagent-timeout-recovery.md (when a `delegate_task` subagent timed out and you need the inspect/finish/follow-up decision tree in 30s)
@references/adding-skills-to-super-skill.md (when the user asks to add N new skills to the orchestrator — the 7-step protocol: research → filter → approve → build → audit 100% → sync-to-public + scrub → verify + push + report. validated at release)

## Auto-routing
Run `frameworks/route.sh` to auto-detect phase from current state and route to the right task.
Run `frameworks/route.sh show` to see state snapshot + suggested route.
Run `frameworks/state-init.sh <phase> <slug> <path>` to create state.md for a new build.
Run `frameworks/state-update.sh <action> [args]` to update state fields (phase, focus, blocker, shipped, learn, log, slice, show).

## Skill maintenance
Run `scripts/audit-skill.sh` after any skill integration or edit. Catches drift between SKILL.md `<commands>`, `frameworks/route.sh`, and `frameworks/state-update.sh`. See pitfall "Keep the state machine, the router, and the commands list in sync" below for why this matters.

Before publishing to a public GitHub repo, run `scripts/security-scan-public.sh <target-dir>` to catch the 19 specific patterns documented in `references/public-publish-scrub-catalog.md`. Self-excludes itself from the scan. Exit 0 = clean, exit 1 = real findings.
</routing>

<greeting>
Build Product loaded.

**איך אתה רוצה להתחיל?**

| Command | When |
|---------|------|
| `/build-product new` | "אני רוצה לבנות [דבר חדש]" |
| `/build-product feature` | "תוסיף לי [feature] לריפו הזה" |
| `/build-product stuck` | "אני תקוע" |
| `/build-product ship` | "אני רוצה לשחרר" |
| `/build-product deploy` | "תעלה את זה ל-Cloudflare" |

*Or just describe what you want to build in plain Hebrew/English — I'll route you.*

**Default stack:** TS/Node primary · Python secondary · Next.js web · Electron/FastAPI desktop · RTL/Hebrew UI · server-side secrets only.
**Default mode:** TDD vertical slices · subagent-driven execution · user-approval on irreversible moves.

*build-product v1.0 · Hermes skill orchestrator · uses existing skills (plan, TDD, subagent, debug, ship, design)*
</greeting>

## Pitfall: Entry point must stay thin — heavy logic lives in tasks/

**Why this rule exists** (2026-06-24, build-product v1 → v2):

The first version of this skill was 7,011 bytes in a single `SKILL.md` file. It tried to embed activation + persona + 4 commands + routing + greeting + an emergency decision tree + half of a routing map all in one place. the rule surfaced when the agent then had to ask three clarifying questions before continuing the build (the "don't ask what I can find" pitfall in the `plan` skill). Once the user pushed back, the skill was restructured into a 120-line entry point + 4 task files (126-158 lines each) + 3 framework files (133-155 lines each) = 1,095 total lines, but **loadable in pieces** by the agent.

**Symptom you're violating the rule:**

- `SKILL.md` exceeds ~200 lines.
- The `<routing>` section duplicates content that exists in `tasks/`.
- The entry point contains a workflow (a sequence of phases) inline.
- An agent loading the skill gets 6+ pages of context just to know "what command should I run."

**The right shape (skillsmith convention):**

```
build-product/
├── SKILL.md                      # 100-150 lines, ALL semantic XML sections, no workflow
├── tasks/                        # one file per command route, 100-200 lines each
│   ├── new-product.md
│   ├── build-feature.md
│   ├── stuck-recover.md
│   └── ship.md
└── frameworks/                   # reference material, loaded on demand
    ├── routing-map.md
    ├── user-defaults.md
    └── stuck-patterns.md
```

**How to decide what goes where:**

| Content | Where | Why |
|---|---|---|
| What the skill does (1-2 lines) | `SKILL.md` `<activation>` | Discoverability |
| When to use / not use | `SKILL.md` `<activation>` | Trigger |
| Persona / voice / style | `SKILL.md` `<persona>` | Always-on context for the agent |
| List of commands | `SKILL.md` `<commands>` | Routing table |
| @-references to task files | `SKILL.md` `<routing>` | How to load heavy work |
| Greeting (1-3 lines) | `SKILL.md` `<greeting>` | User-facing intro |
| **Step-by-step workflow** | `tasks/<command>.md` | Loaded only when the command is invoked |
| **Decision trees** | `frameworks/routing-map.md` | Loaded on demand |
| **Defaults / constants** | `frameworks/user-defaults.md` | Loaded on demand |
| **Common failure modes** | `frameworks/stuck-patterns.md` | Loaded when stuck |

**The agent's loading discipline:** when this skill is invoked, load `SKILL.md` (always) + the single `tasks/<command>.md` (per command) + the single `frameworks/<topic>.md` (per topic). Do NOT load all 4 tasks and all 3 frameworks at once — that's the 7,011-byte mistake in another form.

## Pitfall: Validate `related_skills` cross-references before declaring the skill done

The `metadata.hermes.related_skills` list is a contract. Every entry must resolve to a real `SKILL.md` file in the user's `~/.hermes/skills/` tree. If it doesn't, the agent that loads the skill later will hit `FileNotFoundError` and either silently degrade (skipping the dependency) or hallucinate (making up the skill content). Both are bad.

**Validation recipe** (run before saving a new or edited suite skill):

```python
import os

# Collect every related_skill entry from frontmatter
related = [
    "software-development/spike",
    "software-development/plan",
    "software-development/writing-plans",
    # ... (read from SKILL.md frontmatter metadata.hermes.related_skills)
]

# Try each in canonical location, then alternates
missing = []
for entry in related:
    base = os.path.basename(entry)
    candidates = [
        f"~/.hermes/skills/{entry}/SKILL.md",
        f"~/.hermes/skills/creative/{base}/SKILL.md",
        f"~/.hermes/skills/devops/{base}/SKILL.md",
        f"~/.hermes/skills/{base}/SKILL.md",  # root-level
    ]
    if not any(os.path.exists(os.path.expanduser(c)) for c in candidates):
        missing.append(entry)

if missing:
    print(f"❌ {len(missing)} broken references:")
    for m in missing:
        print(f"   - {m}")
else:
    print(f"✅ All {len(related)} related_skills resolve")
```

**Worked example** (2026-06-24, build-product v1 → v2): the initial frontmatter listed `cavecrew-investigator`, `cavecrew-reviewer`, `cavecrew-builder` as bare names. Validation revealed they live at `~/.hermes/skills/cavecrew-*/SKILL.md` (root-level), NOT under `software-development/`. The fix: list each as its full relative path so the lookup is unambiguous, and validate the same way for any future edit. Three references were broken; all fixed by adding the category prefix.

**Why this is its own pitfall, not a "validate before ship" general rule:** the broken references are *invisible* during authoring. The skill looks complete. The file is saved. The agent only discovers the break on the next invocation, far from the build context. That's the failure mode the rule prevents.

**Anti-patterns:**

- ❌ Listing bare names (`- spike`, `- plan`) when skills are categorized — relies on PATH-like resolution that doesn't exist
- ❌ Trusting the Skills Index as ground truth — it auto-indexes on `ls`, which masks missing files
- ❌ Adding related_skills "just in case" — each one is a real coupling, not a hint
- ✅ Listing full category-relative paths (`- software-development/spike`, `- creative/sketch`)
- ✅ Running the validation recipe after every frontmatter edit
- ✅ Running the validation recipe as part of the `ship` task (see `tasks/ship.md` Phase 0)

## Pitfall: One orchestrator, not a skill per product

When the user says "build me a super-skill that builds a product end-to-end" and then lists their products (a voice product, a desktop product, another product, a video product), the temptation is to build either (a) a separate skill per product, or (b) a mega-skill that hard-codes knowledge of every product. **Both are wrong.**

**What the user actually means** (validated 2026-06-24):

> "רציתי שתבנה את הסקיל ממה שכבר קיים אצלך, ורק שתיקח מיזה מסקנות. לא בהכרך סקיל חכל מוצר ספציפי."

= "Build the skill from what already exists in your toolkit, and just take some lessons from these products. It doesn't have to be a skill per product."

**The right architecture:**

```
build-product/                         # ONE generic orchestrator (this skill)
├── SKILL.md                           # persona, commands, routing
├── tasks/{new,feature,stuck,ship}.md  # generic workflow phases
├── frameworks/                        # generic defaults + decision trees
│   ├── user-defaults.md             # stack/security/deploy (no product names)
│   ├── routing-map.md                 # which skill when
│   ├── past-examples.md               # 2-4 worked examples from real products
│   └── ...
│
└── related_skills (in frontmatter):   # product-specific, NOT duplicated here
    - <my-product-skill>         # ← loaded when working on a voice product
    - <product-skill>             # ← loaded when working on a specific product
    - desktop-product-managed-cloud-feature-work
    - ...
```

**The anti-patterns this rule prevents:**

| Anti-pattern | Symptom | Why it fails |
|---|---|---|
| One skill per product | 5 separate `<build-my-product>`, `<build-my-product>`, `<build-my-product>` skills | Drift. Adding a new product = a new skill. Code duplication. State doesn't share. |
| Mega-skill that knows all products | `build-product` has 30 pages of voice + desktop + other product specific knowledge | Bloats the entry point. Most loaded context is unused. |
| Generic skill that ignores product context | `build-product` has zero awareness of `<my-product-skill>` | The agent forgets there's a specialist for the active product, so it falls back to generic patterns. |

**The test for whether a product-specific concern belongs in this skill:**

1. If it applies to **every product** (e.g. TDD, vertical slices, ship discipline) → in this skill's `tasks/` or `frameworks/`.
2. If it applies to **one product** (e.g. "a voice product uses a voice with this exact personality YAML") → NOT here. It lives in that product's specialist skill (`<my-product-skill>`) and is loaded via `related_skills` only when the active repo matches.
3. If it's a **worked example** that teaches a general lesson (e.g. "a voice product clean rebuild — 5 principles before plan") → in `frameworks/past-examples.md`, one bullet each, no product-specific code.

**What the agent does when the user says "build me X" in repo Y:**

```bash
# 1. This skill loads (build-product)
# 2. Detect active repo from cwd: e.g. ~/projects/workspace/<my-product>
# 3. Check related_skills for product match — <my-product-skill> matches
# 4. Load that specialist skill alongside this one
# 5. Route to tasks/new-product.md (or build-feature.md if repo already has code)
# 6. Both skills' routing maps apply — this skill handles the generic pipeline,
#    the product skill handles product-specific things (voice UX, TTS/STT choices, etc.)
```

**Symptom you're violating the rule:**

- `tasks/new-product.md` mentions "Liam voice" or "a voice" by name.
- `frameworks/user-defaults.md` lists "Frontend: Next.js 15" as the only option.
- `frameworks/past-examples.md` has 8 worked examples all from one product.
- The skill's `related_skills` list is empty.
- the user has to ask "what about my other products?" after reading the skill.

## Pitfall: Keep the state machine, the router, and the commands list in sync — they are one contract

This skill has three places that all describe the same thing — "what phases and commands exist":

1. `SKILL.md` `<commands>` table — the user-facing command list
2. `frameworks/route.sh` case statement — the auto-detect router
3. `frameworks/state-update.sh` phase regex — the phase validator

If you add a new phase or command in **any one** of these three and forget the other two, the skill breaks silently:

- User runs `/build-product deploy` → `route.sh` has no `deploy` case → falls through to `unknown action` → user is confused
- State has `phase: deploy` → `route.sh show` says "unknown phase, defaulting to new-product" → wrong route
- User runs `./state-update.sh phase deploy` → regex rejects it → user is stuck

**Why this happens (2026-06-24, build-product v1.1 → v1.2 — supabase-auth-patterns and cloudflare-deploy integration):**

When I added `/build-product deploy` to the `<commands>` table, I forgot to:
1. Add `deploy) task="deploy-to-cloudflare" ;;` to `route.sh`'s `route_to()` case statement
2. Add `deploy) route_to "deploy" ;;` to the `auto` case statement  
3. Add `deploy|deploying|deployed` to the `state-update.sh` phase regex

The skill *looked* complete. SKILL.md was correct. The audit script (`scripts/audit-skill.sh`) caught all three — but only after a manual sweep, because there's no automatic trigger.

**The rule (validated 2026-06-24):**

Whenever you add or rename a phase/command anywhere in this skill, update **all three** of these in the same edit:

| Location | What to update | Recipe |
|---|---|---|
| `SKILL.md` `<commands>` table | Add a row | `/command-name` → `@tasks/<task>.md` |
| `frameworks/route.sh` `route_to()` case | Add `name) task="<task-name>" ;;` | One line per command |
| `frameworks/route.sh` `auto` case | Add `name) route_to "name" ;;` | One line per command |
| `frameworks/route.sh` `show` case | Add `phase) echo "  → tasks/<task>.md" ;;` | One line per phase |
| `frameworks/state-update.sh` phase regex | Add `phase-name` to the alternation | One regex edit |

**The audit script (`scripts/audit-skill.sh`) catches this automatically:**

```bash
./scripts/audit-skill.sh
# Reads SKILL.md <commands>, walks all @-references, walks all phases in
# state-update.sh and route.sh, and prints any 3-way mismatch.
```

**Run the audit script:**
- After every skill integration (added a related_skill that brings new commands)
- Before every `ship` task
- Once per quarter even if nothing changed (drift happens silently)

**Anti-patterns:**

- ❌ Adding a command to SKILL.md without running the audit script — guaranteed drift
- ❌ Editing only `route.sh` and forgetting `state-update.sh` (or vice versa) — partial fix
- ❌ Trusting your eyes to scan 3 files for 5+ phases each — humans miss this; use the script
- ✅ Edit SKILL.md → run audit → fix what's flagged → run again → green

## Pitfall: Audit the skill every 2-3 integrations, not after every edit

I learned this the hard way integrating `supabase-auth-patterns` and `cloudflare-deploy` (2026-06-24). Adding 2 skills caused **4 cascading issues**:

1. `route.sh` didn't know about `deploy` (already covered above)
2. `state-update.sh` rejected `deploy` phase (already covered above)
3. Content duplicated between `tasks/deploy-to-cloudflare.md` and the Phase 6 / Phase 5.5 sections in `new-product.md` and `build-feature.md` — the same deploy instructions written in 3 places
4. Phase numbering drifted (5.5 in feature, 6 in new-product) — defensible if intentional, but undocumented

If I'd audited after each skill integration, I'd have caught issues 3 and 4 mid-flight. If I waited until the end, fixing them took 30 minutes in one pass.

**The cadence (validated 2026-06-24):**

- **Per edit**: spot-check — does this change affect SKILL.md `<commands>`, `route.sh`, or `state-update.sh`? If yes, update all three.
- **Per 2-3 integrations**: full audit — run `scripts/audit-skill.sh` end-to-end. Look for: cross-reference drift, content duplication, phase numbering inconsistency, related_skills mismatch.
- **Per quarter**: even if nothing changed, run the audit. Skills Index regenerates, but route.sh and state-update.sh don't.

**What the audit checks (run `./scripts/audit-skill.sh`):**

| Check | What it catches |
|---|---|
| `related_skills` resolution | Broken `@-references` to skill files |
| `<commands>` ↔ `@-references` in `<routing>` | Tasks referenced in commands but no `<routing>` entry, or vice versa |
| `<commands>` ↔ `route.sh` case statement | New command not in router |
| `state-update.sh` phase regex ↔ `route.sh` show/auto phases | Phase accepted by state-update but not routed |
| Cross-skill `@-references` (e.g. `@../cloudflare-deploy/SKILL.md`) | Referenced skill doesn't exist |
| Content duplication heuristic | Same paragraph repeated across `tasks/*.md` files (>50% overlap) |

**Symptom you're violating the rule:**

- Adding 3+ skills in one session without running the audit
- "I'll audit at the end" — this is how issues 3 and 4 happened
- "It's just a small edit, no need to audit" — small edits on multiple files are exactly what audit catches
- The audit output grows stale because nothing calls it — fix by hooking it into `tasks/ship.md`

## Pitfall: Validate the SOURCE, not just the public copy, when publishing a skill externally

When publishing a skill (or skill bundle) to a **public GitHub repo**, the obvious mistake is to only validate the published copy (`/tmp/PublicRepo/...`) and assume the source (`~/.hermes/skills/...`) is fine. It is not. **Bugs in the source travel to the public copy** — the public copy is a snapshot, not a parallel universe — and if the source is broken, every future sync inherits the same bugs.

**The trap (validated 2026-06-24, FullStack-Builder publish):**

I scrubbed and validated `build-product/SKILL.md` inside `/tmp/FullStack-Builder/`, fixed the unclosed frontmatter (missing trailing `---`), pushed to GitHub. The user asked: *"אז הבאג שמצאת שסרקת את הסקיל הציבורי בגיטהאב ותיקנת עם הskill.md — האם גם בסקיל אצלינו זה קיים?"* (Did you fix the source too?) — and the answer was *no*. The source still had the unclosed frontmatter. The same Hermes validator that accepted the public copy would have rejected the source. **One bug, two copies, one fixed.**

**The rule (validated 2026-06-24):** When you publish a skill externally, treat the publish flow as **two validation passes**, not one:

| Pass | What you validate | Command |
|------|-------------------|---------|
| Pass 1 — public copy | The staged repo at `/tmp/<repo>/` after scrubbing | Same checks you'd run on the source |
| Pass 2 — source | The actual `~/.hermes/skills/<path>/` that the agent loads at runtime | Same checks, on the original path |

If Pass 2 fails, **fix the source first**, then re-sync to the public copy. Never "fix the public copy only" — the bug stays in the live skill Hermes loads.

**The canonical frontmatter check (works even when description has quotes):**

```bash
# Count standalone '---' lines — frontmatter must have at least 2 (open + close)
dashes=$(grep -c '^---$' "$skill/SKILL.md")
[ "$dashes" -ge 2 ] && echo "✅ closed" || echo "❌ frontmatter NOT closed"
```

This is more reliable than `python -c "import yaml; yaml.safe_load(...)"` when the description field contains unescaped quotes. PyYAML returns `None` for the whole frontmatter if the description line has stray `"` characters, masking the real issue. The grep is dumb but correct.

**The canonical ground-truth check (does Hermes actually load this skill?):**

```bash
timeout 30 hermes skills list 2>&1 | grep -E "build-product" | head -5
# If the skill appears in the list with `enabled`, Hermes can load it.
# SKILL.md being parseable by YAML does NOT prove Hermes can load it.
```

`hermes skills inspect` is the most thorough check but times out (180s+) on a skill with many `related_skills`. `hermes skills list` is the fast sanity gate.

**Three-source equivalence check (after publishing):**

```bash
diff -rq ~/.hermes/skills/<path>/ /tmp/<public-repo>/<path>/
# Empty output = source and public are equivalent except for scrubbing.
# Any non-empty output = review the diff: was it a deliberate scrub, or did a bug sneak through?
```

**The full checklist for "publish a skill externally" (added to `tasks/ship.md` Phase 0):**

1. Copy source → `/tmp/<public-repo>/`
2. Run security scan for secrets/PII (`scripts/security-scan-public.sh <target-dir>` — see `references/public-publish-scrub-catalog.md` for the 19 patterns)
3. Replace each finding with a generic placeholder (see `references/public-publish-scrub-catalog.md` for the rename map)
4. **Run the same frontmatter + `hermes skills list` check on the SOURCE** — fix any bugs there first
5. Re-sync the fix from source to public copy (or vice versa, then validate both match)
6. Add repo scaffolding (README, LICENSE, CONTRIBUTING, .gitignore)
7. Re-scan the public copy (should be clean)
8. `git init` + `gh repo create --public` + push

**Two-pass scrub discipline:**

> "[scrub directive] Re-check the public repo and verify with 100% certainty that no secret, sensitive key, or personal information of any kind remains."

The standard is **100%** — no "0 real findings out of 220 with 201 false positives," but **0 real findings period, and a clear breakdown of which patterns matched and why each is OK** (e.g., "scripts/security-scan-public.sh contains the patterns by design — it scans for them — so it's self-excluded"). The two-pass pattern:

| Pass | What you scrub | What you ALSO scrub |
|------|----------------|---------------------|
| **Pass 1 — public copy** | The staged repo at `/tmp/<repo>/` | Document each false positive (security scanner scripts, doc files that teach about secrets) |
| **Pass 2 — source** | `~/.hermes/skills/<path>/` | Same false-positive catalog, applied to source |

If a pattern matches in source but not in public (or vice versa), there's drift — investigate. The point of the two passes is that **no real secret lives in either tree**, not "we found 0 obvious leaks."

**The scrub catalog (validated 2026-06-24):**

The 19 patterns in `references/public-publish-scrub-catalog.md` cover:
- **Identity**: name, username, surname, agent name (with rename map: `<your-name>` → `the user`, `<your-agent-name>` → `the voice agent`)
- **Network**: VM IP, laptop IP, bridge port, Tailscale hostnames
- **Paths**: `/root/...`, `<vault-path>/...`, `C:\Users\<username>\...`
- **API keys/tokens**: Supabase PAT, GitHub token, OpenAI key, ElevenLabs key, Cloudflare Account ID (32-hex), voice IDs, partial-token prefixes (e.g., <partial-token-prefix> even when the rest is redacted)
- **Cloudflare specifics**: Workers subdomain, account email, public repo URLs containing the username
- **Misc**: credit-card patterns, Israeli ID (9 digits), phone numbers

**The scrub rename map (capture in your head, not in the public repo):**

|| Original (in source) | Replacement (in public) | Why |
||---|---|---|
|| `<your-name>` / `<your-name>'s laptop` / `ask <your-name>` | `the operator` / `the operator's laptop` / `ask the operator` | Identity |
|| `<your-agent-name>` (a peer agent) | `a peer agent` | Agent identity |
|| `<your-github-username>` | `YOUR-GITHUB-USERNAME` | GitHub username |
|| `<your-cloudflare-email>` / `<your-email>` | `<your-cloudflare-email>` / `<your-email>` | Email |
|| `<agent-vm-ip>` / `<laptop-ip>` / `<agent-vm-hostname>` | `<agent-vm-ip>` / `<laptop-ip>` / `<agent-vm-hostname>` | Tailscale |
|| `:<bridge-port>` (e.g. 27873) | `:<bridge-port>` | Bridge |
|| `/root/...` | `~/projects/...` | VM path |
|| `/root/.hermes/...` | `~/.config/hermes/...` | VM path |
|| `C:\Users\<username>\...` | `C:\Users\<username>\...` | Laptop path |
|| `~/.hermes/memories/...` | (remove reference) | Vault path |
|| `<your-cloudflare-account-id>` (32-char hex) | `<your-cloudflare-account-id>` | Cloudflare |
|| `<voice-id>` (ElevenLabs voice ID) | `<voice-id>` | TTS |
|| `<your-subdomain>` (Cloudflare subdomain) | `<your-subdomain>` | Cloudflare |
|| `<token-prefix>` / `<project-ref>` (partial token prefixes) | `<redacted>` | Even partial prefixes identify |
|| `<name>-defaults.md` (filename) | `user-defaults.md` | Filename contains name |
|| `<name>-machine-layout.md` (filename + content) | `agent-host-layout.md` (rename + rewrite generically) | Local-only reference, removed from public |

**Self-scrubbing rule**: this map itself MUST NOT contain real values from your environment. If you find yourself writing `<your-cloudflare-email>` or `<agent-vm-ip>` examples in this table with literal values, you have already lost — the source leaks. Replace with `<your-X>` placeholders BEFORE the table is committed.

**Anti-patterns:**

- ❌ "The public copy validates, ship it" — the source is the live skill; it matters more
- ❌ Fixing a bug only in `/tmp/PublicRepo/` and leaving the source broken — every future re-publish re-introduces the bug
- ❌ Trusting YAML parsing on `description:` fields with quotes — use the grep count instead
- ❌ Using `hermes skills inspect` as a fast check — it can hang 3+ minutes; use `hermes skills list`
- ❌ Reporting "0 real findings out of 220 matches, 201 are false positives" as a green pass — every audit gap must be resolved before declaring compliance; match counts are not a sufficient metric
- ❌ Treating "0 real findings" as good enough without explaining each false positive
- ✅ Always run Pass 2 (source validation) immediately after Pass 1 (public copy validation)
- ✅ Add the diff-equivalence check between source and public before pushing
- ✅ When you find a bug in one copy, fix it in BOTH before continuing
- ✅ Document each false positive in the scrub report (which file, which pattern, why it's a false positive)

**Anti-patterns:**

- ❌ "The public copy validates, ship it" — the source is the live skill; it matters more
- ❌ Fixing a bug only in `/tmp/PublicRepo/` and leaving the source broken — every future re-publish re-introduces the bug
- ❌ Trusting YAML parsing on `description:` fields with quotes — use the grep count instead
- ❌ Using `hermes skills inspect` as a fast check — it can hang 3+ minutes; use `hermes skills list`
- ✅ Always run Pass 2 (source validation) immediately after Pass 1 (public copy validation)
- ✅ Add the diff-equivalence check between source and public before pushing
- ✅ When you find a bug in one copy, fix it in BOTH before continuing

**Symptom you're violating the rule:**

- You just published a skill and the user asks "is the source fixed too?" — you don't know without running the check
- Re-publishing the same skill months later reintroduces a bug you "fixed" last time — the fix was in the public copy only
- `hermes skills list` shows the skill, but the skill crashes on load with a YAML parse error — your check only validated the public copy's structure, not its semantics

## Pitfall: When `delegate_task` subagents time out, the work is partly on disk — verify state, don't restart

A `delegate_task` call to a subagent has a 10-minute (600s) hard timeout. When a subagent times out, the natural reaction is to retry from scratch — **don't**. The subagent usually got 10-30+ tool calls in before the timeout, and many of those created real files on disk. Restarting means redoing work that's already done and possibly overwriting partially-correct files.

**The recovery recipe (validated 2026-06-24, building 7 skills in parallel via `delegate_task`):**

Three of seven subagents timed out. In all three cases, ~50-80% of the work was already on disk. The recovery was: inspect the filesystem, identify the gap, finish it directly in the parent session (or send a focused follow-up subagent with a narrower scope).

```bash
# Step 1: Inspect what's actually on disk
ls -la ~/.config/hermes/skills/software-development/<skill-name>/
find ~/.config/hermes/skills/software-development/<skill-name> -type f

# Step 2: Compare against the spec
# Spec said: 8 files in tasks/ + 3 in frameworks/ + 1 in references/ + SKILL.md
# Disk says: SKILL.md + 2 files in tasks/ + 0 in frameworks/
# Gap: 6 files in tasks/, 3 in frameworks/, 1 in references/

# Step 3: Either finish in parent (fast, for 1-3 missing files) OR send a narrow follow-up subagent:
```

**When to finish in parent vs send follow-up subagent:**

| Missing files | Best action |
|---|---|
| 1-3 files, small content | Finish in parent — subagent overhead exceeds the work |
| 4+ files, or files are interdependent | Send a follow-up `delegate_task` with **explicit current-state spec** and "DO NOT recreate X, DO NOT touch Y" |
| Subagent appears to have made wrong design choices | Finish in parent — don't let a confused subagent do more damage |

**The follow-up subagent prompt pattern (validated 2026-06-24):**

```
"Complete the `<skill-name>` skill at `<path>`. Previous subagent started but timed out.

CURRENT STATE (verified by parent):
- SKILL.md exists (8.9 KB) — DO NOT MODIFY
- tasks/design-rest-endpoints.md exists
- frameworks/ is EMPTY
- references/ is EMPTY

WHAT TO COMPLETE (focused, no scope creep):
1. Add tasks/design-graphql-schema.md
2. Add tasks/generate-openapi-spec.md
...
8. Add references/openapi-vs-graphql-decision.md

CONSTRAINTS:
- Do NOT modify existing files
- Do NOT touch any other skills
- Don't run audits — parent will do that
- Skip skillsmith — direct file creation
- Report at end: list of all 8 NEW files created with sizes."
```

**Anti-patterns:**

- ❌ Retrying the original `delegate_task` from scratch — discards the partial work, re-runs the slow parts
- ❌ Asking the user what to do — they don't know the subagent's progress; you do (or can find out with `ls`)
- ❌ Skipping the inspection step and "just trying again" — wastes another 10 min if the gap is small
- ❌ Letting a follow-up subagent run with the same broad scope — it will time out again on the same wall

**Symptom you're violating the rule:**

- Subagent timed out and you immediately called `delegate_task` again with the same prompt
- Subagent timed out and you asked the user "what should I do?"
- You never ran `find` / `ls` on the target directory after a timeout
- The follow-up prompt still includes the full original spec instead of "the gap is X"

## Pitfall: For small skills (<10 files), skip skillsmith and write files directly

Skillsmith (`~/projects/workspace/repos/skillsmith/`) is a scaffolding CLI that generates a skill with provenance, anti-theft footers, and BASE-v2 integration. It's powerful for production-grade skills that go to a registry. For **small skills (<10 files)** or **personal skills** that stay local, it adds friction without much value.

**The comparison (validated 2026-06-24, building 7 skills):**

| Aspect | Skillsmith init | Direct write |
|---|---|---|
| Time to first file | ~3-5 min (init wizard, choices) | <30s (open editor) |
| Files created per minute | 1-2 (slow due to scaffold overhead) | 4-6 (raw `write_file`) |
| Provenance / footer | Auto-injected, consistent | Manual (copy from template) |
| 10-min subagent budget | Often times out at init | Fits comfortably |
| Frontmatter correctness | Guaranteed | Manual (but `grep -c '^---$' ≥ 2` catches it) |
| Right for | Public registry, multi-contributor, >15 files | Personal/local, <10 files, fast iteration |

**The recipe when you decide to skip skillsmith:**

1. Write `SKILL.md` first with this template (copy-paste, fill fields):

```yaml
---
name: <skill-name>
type: skill
version: 1.0.0
category: development
description: "<Hebrew one-liner>. <English one-liner for trigger matching>."
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion, WebSearch, WebFetch]
related_skills:
  - build-product
  - <other-skill-1>
---

# <Skill Title>

<One paragraph: what this skill does, when to use it.>

## מתי להשתמש

- ✅ <trigger 1>
- ✅ <trigger 2>

## מה יש בפנים

| קובץ | מה זה |
|------|-------|
| `tasks/<file>.md` | <one-line description> |
| ... | ... |

_footer: <skill-name>/SKILL.md · <skill-name> v0.1.0_
```

2. Write each task/framework/reference file with the same `_footer: <skill-name>/<path> · <skill-name> v0.1.0_` line at the bottom.

3. Verify frontmatter: `grep -c '^---$' <skill>/SKILL.md` should return ≥2.

4. Run `scripts/audit-skill.sh` from build-product (or your own audit) to catch structural drift.

**When to USE skillsmith:**

- Publishing to a public skill registry
- Skill is part of a multi-skill bundle (provenance matters for attribution)
- You're new to skill structure and want a guided wizard
- Skill has >15 files and the scaffold overhead amortizes

**When to SKIP skillsmith:**

- Personal/local skill
- <10 files
- Fast iteration needed
- Subagent is doing the writing (the init wizard is interactive)

**Symptom you're violating the rule:**

- You ran `./bin/skillsmith init` for a 6-file skill and the subagent spent 4 minutes on scaffolding instead of writing content
- You wrote a skill with `version: 1.0.0` and full BASE-v2 metadata for a draft that the user asked you to "just try"
- You're on a 10-min budget and skillsmith init is still asking questions

## Pitfall: 5 mandatory questions before any build (adopted from a peer agent's super-builder pattern)

When `/build-product new` or `/build-product feature` is invoked with a description shorter than 3 sentences, the skill MUST ask these 5 questions before generating any plan, code, or scaffold:

1. **מה בדיוק צריך להיבנות?** (2-3 sentences describing the deliverable)
2. **למי זה מיועד?** (end user / 3rd party / internal)
3. **איפה זה ירוץ?** (server / browser / desktop / mobile)
4. **מה הקריטריונים להצלחה?** (one checkable assertion that can be run and observed)
5. **מה בהיקף ומה לא?** (explicit scope/non-scope — the in-scope list must be concrete, the out-of-scope list must be enforced as a hard "do not do")

**Why this exists (v1.3.0, borrowed from a peer agent's super-builder pattern):**
A peer agent's `super-builder` skill bakes these 5 questions as the first step of every build, in Hebrew, with a "תבנית הבנה מהירה" (quick-understanding template) that forces a 6-line answer before any work begins. The result: zero misaligned builds. build-product originally deferred to `amrita-architect` (Loop 15) for clarification, but learned that 3 questions is too few for the wide range of products build-product handles. Five is the right number — covers objective, audience, runtime, success, scope. Any answer that is "I don't know" or "you decide" forces an assumption to be written into the spec; assumptions are not silently swallowed.

**The quick-understanding template** (insert into `tasks/new-product.md` Phase 0, before plan generation):

```
## מה: [2-3 sentence description]
## למי: [user / customer / internal]
## איפה: [web / desktop / API / WhatsApp / voice]
## הצלחה = [one checkable assertion]
## בהיקף: [concrete list — what gets built]
## מחוץ להיקף: [concrete list — what does NOT get built]
```

**Anti-patterns:**
- ❌ "Just start building, ask if I get stuck" — costs hours when the answer was obvious upfront
- ❌ Asking 10 questions until the user gives up — agents that never ship
- ❌ Skipping the success-criterion question and "figuring it out later" — there is no later
- ✅ Filling the template verbatim before any code is written
- ✅ Routing vague ideas to `amrita-architect` first (Loop 15), then returning to this template

## Pitfall: 2 scaffold scripts (scaffold-node.sh + scaffold-python.sh)

`tasks/new-product.md` Phase 1 calls one of these 2 scripts to bootstrap a new project. Without them, the agent wastes 10+ minutes on `npm init` / `venv setup` / `git init` boilerplate.

**The scripts live at `frameworks/scripts/`:**

- `scaffold-node.sh` — Node.js + Express + TypeScript + ESLint + Jest + `.env.example` + `README.md` + `package.json` with `dev` / `test` / `start` / `build` scripts + health endpoint at `/health`
- `scaffold-python.sh` — Python 3.12 + `venv` + `pyproject.toml` + `pytest` + `ruff` + `.env.example` + `README.md` + entry point + health endpoint

**Why they exist (v1.3.0, borrowed from a peer agent's super-builder pattern):**
Every new project needs the same 10 things: git, .gitignore, README, .env.example, .gitignore for secrets, health endpoint, dev/test/start scripts, a basic test that passes, a basic lint config. Doing this manually = 10+ minutes of boilerplate. Doing it with a script = 30 seconds. build-product routes to the right script based on stack detection in Phase 1; the script does the rest.

**The rule:** if a new project does not have a `scripts/scaffold-*.sh` equivalent in its framework, the agent MUST run one of these two before writing any feature code.

**Anti-patterns:**
- ❌ `npm init -y` then manually adding 10 packages — drift in versions, missing health endpoint
- ❌ Skipping `.env.example` and getting caught later when deploying — never commit `.env`, always commit `.env.example`
- ❌ Adding Tailwind / Prisma / Next.js "to be safe" — wait for the spec, only add what's needed
- ✅ Pick the script by stack detection (Node vs Python) and run it
- ✅ After scaffold, verify `curl http://localhost:PORT/health` returns 200 before writing any feature

## Pitfall: If a finding is "technically partial but works", it's still a finding — don't downgrade

When auditing against an external spec (skillsmith, OpenAPI, JSON-Schema, RFC compliance, etc.), the rule is: **the spec is the bar, not "does it work in practice."** A custom script that returns "92% ✅" while the official tooling says "PARTIAL" is *not* a green audit — it's a parallel universe that hides the gap.

**The trap (validated 2026-06-24, build-product v1.3.0 audit):**

I wrote a hand-rolled Python audit that checked 6 things: frontmatter, version, category, name, related_skills, and task-format. It returned 92% ✅. I declared the skill "COMPLIANT" and moved on. The user pushed back: *"עשית audit עם skillsmith לסופר סקיל ? אם לא תעשה.."* — explicitly asking whether I had used the actual skillsmith tooling, not my reimplementation.

I hadn't. The real skillsmith spec had requirements my script didn't check (e.g., the `<steps>` task format with named snake_case steps, vs my script accepting "Phase N" as equivalent because it "still works"). The hand-rolled audit had systematically **downgraded CRITICAL findings to acceptable** because the code functionally worked.

**The rule (validated 2026-06-24):**

When the user asks for an audit against a named standard, the workflow is:

1. **Identify the canonical tool** for that standard. For skillsmith, it's `~/projects/workspace/repos/skillsmith/skillsmith/tasks/audit.md` plus the `specs/*.md` files. For OpenAPI, it's an OpenAPI validator. For JSON-Schema, it's a JSON-Schema validator. Don't write a reimplementation unless the canonical tool is unavailable.
2. **Run the canonical tool.** Capture its output verbatim, including warnings.
3. **If you must supplement with a custom check** (e.g., because the canonical tool misses something), say so explicitly. Don't present custom checks as equivalent to canonical.
4. **Never claim "✅ COMPLIANT" based on a custom check that disagrees with the canonical.** If your custom check says green and the canonical says red, the canonical wins. Investigate the gap, don't paper over it.
5. **"It works in practice" is a separate question from "it conforms to spec."** Both matter. Spec violations are technical debt that compound; runtime breakage is what users see. Don't let one excuse the other.

**Anti-patterns:**

- ❌ Writing your own validator because "the spec is too long to read" — the spec is what the user asked for
- ❌ Calling a hand-rolled check "skillsmith audit" when it isn't — that misrepresentation compounds
- ❌ Reporting "92% ✅" when the canonical tool says PARTIAL — the percentage is meaningless across incompatible rubrics
- ❌ Concluding "this gap is non-critical because the code works" — that's a runtime argument, not a spec-conformance argument
- ✅ Identify the canonical tool. Run it. Report its output. If gaps exist, fix them or flag them honestly.
- ✅ If you must run a custom check, name it: "Custom check for X (does not replace canonical)"

**Symptom you're violating the rule:**

- The user asked for an audit against standard Y, and you ran your own check instead
- Your audit output is "92% green" with a smiley but the spec requires X, Y, and Z and you only checked X and Y
- The conversation has a moment where you say "I think this is fine" and the user replies "did you actually check?"
- You catch yourself writing "this is technically compliant" when you mean "this functionally works"

**Connection to other pitfalls in this skill:**

- "Audit the skill every 2-3 integrations" — the cadence. This pitfall is about *what kind* of audit: use the canonical tool, not a reimplementation.
- "Validate the SOURCE, not just the public copy" — the same principle applied to a different surface (source vs public).

## Pitfall: 100% or it's not done — never accept "good enough on the parts that don't matter" (validated 2026-06-24, v1.3.0 hardening)

**The user's standard, captured verbatim:**

> "[user-directive-rule] Every audit item the user flags as critical IS critical."

Translation: "Anything I don't see as critical, it IS critical. I want the skill to score 100%."

**Why this rule exists:**

**Anti-pattern:** Shipping at <100% audit pass-rate and calling it "compliant." A 92% audit on a critical-skill release is a 8% gap that can mask real defects (false-positive regex coverage + missing examples). Treat every audit gap as blocking until resolved.

Then, when I declared 95% on the second pass, the user pushed back the same way: *"skills get a 100% score, not less."* And only then did I go to 100% — by fixing the actual gaps (a real bug in `deploy-to-cloudflare.md` user-story phrasing, plus 2 framework files). **Three passes to reach 100% because the first two passes accepted "good enough."**

**The rule:**

When the user names a numeric standard (100%, 90%, "score X"), treat it as a **hard floor**, not a target to round down from. The work to go from 92% to 100% is almost always cheaper than the work to convince the user the gap is acceptable.

**Audit-loop discipline for "100% or not done":**

1. **Run the audit.** Capture the score and the failing items.
2. **For each failing item, classify:**
   - **Real gap** (skill actually violates the spec) → fix it. This is the bulk of cases.
   - **False positive in the audit script** (e.g., regex doesn't match the long-form pattern) → fix the audit, then re-run. **Do not** declare the gap non-critical.
   - **Cosmetic** (e.g., example wording, file ordering) → fix it anyway. Cheap.
   - **Out of scope** (the spec is wrong or the requirement doesn't apply) → tell the user, get explicit permission to skip.
3. **Re-run the audit.** If still below 100%, repeat from step 2.
4. **Only declare done when the canonical tool returns 100%** (or the user explicitly accepts a gap with a one-line note: "X is intentionally below 100% because Y").

**Anti-patterns:**

- ❌ "92% ✅ — that's COMPLIANT" — the gap between 92% and 100% is almost always small
- ❌ "The failing items are cosmetic / non-critical" — that judgment is the user's, not yours
- ❌ "I'll fix this in the next pass" — there is no next pass until the user is satisfied
- ❌ Reporting a custom-audit 100% when the canonical tool is at 92% — see the pitfall above
- ✅ Run the canonical audit. Read every failing item. Fix every failing item. Re-run. Stop only at 100% or explicit user waiver.
- ✅ "100% on the audit tool" is the **definition** of done for skill maintenance. Anything else is "in progress."

**Symptom you're violating the rule:**

- The user has to ask "are you sure it's 100%?" after you said you're done
- The audit output ends with "PARTIAL" and you report it as "✅"
- You tell the user "this gap is non-critical" without their agreement
- The conversation has "good enough" or "that should be fine" anywhere in the closing message
- You're tempted to ship at 95% because the remaining 5% is "just examples" or "just wording"

**Connection to other pitfalls in this skill:**

- "If a finding is 'technically partial but works', it's still a finding" — same principle from the previous round of feedback, hardened to a numeric standard
- "Audit the skill every 2-3 integrations" — the cadence. This pitfall says: the cadence's *output* must be 100%, not "92% with no criticals."

## Pitfall: Deployment checklist before `/build-product ship`

`tasks/ship.md` Phase 0 includes a 4-item pre-deploy checklist. The agent MUST verify all 4 before declaring a build "shipped":

1. **README.md** — "מה זה עושה (2 שורות)" + "איך מתחילים (3-5 פקודות)" + "מה ה-API (אם יש)" + "איך להתקין מחדש"
2. **.env.example** — all required env vars with placeholder values, NO real secrets
3. **Health endpoint** — `GET /health` returns 200 with `{"ok": true, "version": "..."}`
4. **Smoke test passes** — `e2e-testing` (Loop 3 + Loop 10) AND `dogfood` (Loop 17) both pass

**Why it exists (v1.3.0, borrowed from a peer agent's super-builder pattern):**
"Works on my machine" is not a deploy. 3 of the 4 items above are not optional. A missing health endpoint means you cannot monitor uptime. A missing README means the next developer (or you, 3 months later) cannot boot the project. A missing `.env.example` means the first deploy fails with a cryptic env-var error. A missing smoke test means the deploy goes out blind.

**The deployment order:**
1. Scaffold script (Pitfall: 2 scaffold scripts) → boots the project
2. `e2e-testing` runs smoke + visual regression (Loop 3 + Loop 10)
3. `dogfood` runs exploratory QA (Loop 17)
4. All 4 checklist items above are ✅
5. THEN `/build-product ship` is allowed

**Anti-patterns:**
- ❌ "I tested it locally" — local is not prod, smoke test must run against the deployed URL
- ❌ Deploying without a health endpoint — you cannot detect when the service is down
- ❌ Committing `.env` instead of `.env.example` — secret leak, never do this
- ✅ Run the 4-item checklist in `ship.md` Phase 0 before declaring done
- ✅ If any item is missing, the skill refuses to ship until it's added (block, not warn)
- The skill will never leave your local `~/.hermes/skills/`, but it has provenance footers pointing to a registry it will never join