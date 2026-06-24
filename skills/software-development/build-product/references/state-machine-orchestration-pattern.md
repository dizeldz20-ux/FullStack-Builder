# State-Machine Orchestration Pattern

A reusable technique for any skill that drives a multi-phase workflow with state that survives sessions. This pattern is what `build-product` uses for its `state.md` + `route.sh` + `state-update.sh` trio, and it generalizes to any workflow that has discrete phases, a long runtime, and a need to resume mid-build.

## When this pattern applies

- The workflow has **3+ discrete phases** (e.g. new / feature / stuck / ship).
- The user may **pause and resume** across sessions or context compactions.
- The agent must **auto-detect** what to do when the user comes back without explicit instruction.
- The skill needs a **single source of truth** for "where is this build right now."

If your workflow has 1-2 phases or is always invoked fresh, this pattern is overkill — just use the standard tasks/ folder.

## The three components

### 1. `state.md` — the canonical record

A single file (usually `<repo>/.hermes/<skill-name>/state.md`) with:

- **Frontmatter** with `version`, `repo`, `created`, `last_updated` — machine-readable
- **Body** with phase-specific sections: `Phase`, `What's shipped`, `Current focus`, `Blockers`, `Stuck-recovery log`, `Reusable learnings`, etc.

**Why frontmatter + body?** Frontmatter gives the agent a one-line parse for "what phase are we in". Body is human-readable when the user reads the file directly.

### 2. `state-init.sh` + `state-update.sh` — the safe mutators

Shell scripts that touch the state file via Python (or jq), NOT raw sed. Why:

- The state file has structured sections. A bad sed can mangle them.
- Python regexes are testable. Sed chains are not.
- The scripts are idempotent: running `state-update.sh phase shipped` twice does the right thing.

**Example actions for any state-machine skill:**

```bash
state-update.sh phase <new|active|paused|done>   # the primary state transition
state-update.sh focus "<one-sentence current goal>"
state-update.sh blocker "<what's blocking us>"
state-update.sh shipped "<deliverable name>"
state-update.sh log "<stuck> → <cause> → <fix> → <preventive>"
state-update.sh show                            # human-readable summary
```

### 3. `route.sh` — the auto-dispatcher

Reads `state.md` and routes to the right `tasks/<phase>.md` automatically. This is the part that turns a multi-file skill from "the agent has to remember which file to load" into "the agent just runs `route.sh` and gets the right thing."

```bash
route.sh                  # auto-detect phase, print relevant task
route.sh show             # state snapshot + suggested route
route.sh <phase>          # force a specific phase (bypass auto-detect)
```

## Lessons from build-product v1.1 (where this pattern was first applied)

These are pitfalls found in the wild, not theoretical:

### Lesson 1: Don't append to state with raw sed

First version of `state-update.sh focus` used:

```bash
sed 's|<one sentence>.*|<new focus>|' state.md
```

This ate the next section header and merged two sections. **Always anchor the replacement to the section header AND stop at the next section header.** Python `re.sub` with `(?=\n## )` lookahead is the right tool.

### Lesson 2: Don't duplicate frontmatter values from the template

The first version of `state-init.sh` had the script both fill the template AND inject a `## Phase\n$PHASE` line, producing `## Phase\nnew\nnew`. **The template should have `## Phase\nnew` as a default, and the script should only modify it if a different phase is passed.** Otherwise the script and the template fight.

### Lesson 3: `state-update.sh show` needs anchored output

A naive `grep -A1 "^## Phase"` returns the section header AND the next blank line, not the actual phase value. **Always pair `grep -A1` with `tail -1` AND test the result on a real state file before shipping.**

### Lesson 4: The `route.sh` short-name → full-name mapping is mandatory

If `tasks/new-product.md` is the actual file but the command is `/build-product new`, the dispatcher needs:

```bash
case "$task" in
  new) task="new-product" ;;
  feature) task="build-feature" ;;
  stuck) task="stuck-recover" ;;
  ship) task="ship" ;;
esac
```

Otherwise `route.sh new` looks for `tasks/new.md` and fails.

### Lesson 5: Test the full state lifecycle before declaring the skill done

The end-to-end test for build-product took 7 steps:

1. `route.sh auto` with no state → routes to `new-product`
2. `state-init.sh new <slug> <path>` → creates state
3. `state-update.sh focus "..."` → populates
4. `state-update.sh blocker "..."` → adds
5. `state-update.sh slice <name> <branch> <commits> "<verified>"` → last slice
6. `state-update.sh phase shipped` → transitions phase
7. `route.sh auto` after shipped → routes to `build-feature` (next slice)

**All 7 steps must work with a real shell, real files, real output.** Testing the patterns in isolation misses the cross-step regressions (Lesson 1-4 above).

## Reusable template

If you want to apply this pattern to another skill, copy this scaffold:

```text
<skill-name>/
├── SKILL.md                          # add <routing> block pointing to these scripts
├── tasks/                            # one file per phase
│   ├── <phase-1>.md
│   ├── <phase-2>.md
│   └── ...
├── frameworks/
│   ├── state-schema.md               # define the YAML/markdown schema
│   ├── state-template.md             # template to copy
│   ├── state-init.sh                 # create state file
│   ├── state-update.sh               # safe field mutators
│   └── route.sh                      # auto-dispatch
└── references/
    └── state-machine-orchestration-pattern.md   # ← you are here
```

Each script needs:

- `set -euo pipefail`
- `STATE_FILE=".hermes/<skill-name>/state.md"` as the default path (overridable via env)
- Python heredoc for regex work, not sed
- A `show` action that prints a human-readable summary
- A short-name → full-name mapping in `route.sh`

## When NOT to use this pattern

- **Single-shot skills** (one task, no phases) — overhead exceeds value.
- **Read-only skills** (research, analysis) — no state to persist.
- **Sub-15-minute workflows** — the user can re-explain faster than the state can be re-read.
- **Skills with no real "phase" concept** — if every invocation is the same shape, just do the work inline.

## See also

- `frameworks/state-schema.md` in this skill — the concrete schema and field semantics
- `frameworks/route.sh` in this skill — the working dispatcher
- `frameworks/state-update.sh` in this skill — the working mutators
- The `amrita-architect` skill (Kanban) uses a related but different pattern (Kanban board is the state, not a markdown file). It might benefit from a state.md overlay but that's a separate design conversation.
