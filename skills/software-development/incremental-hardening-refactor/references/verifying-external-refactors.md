# Verifying External-Agent or Cross-Session Refactors

Companion to the SKILL.md section "Verifying external-agent or cross-session refactors."
Use when you are the reviewer of a refactor done by another agent (Claude, Codex, Maton
bot, an internal team PR), a compacted prior session, or any untrusted branch.

The standard incremental loop in SKILL.md is for "I just changed one thing, prove it."
This file is for "an external party claims the refactor is done; verify the claim
before merging or building on it."

## When to use this

- User says: "verify Claude's refactor", "check what X agent did", "review this PR"
- A refactor branch exists on `origin` that is not in the local worktree
- A commit message contains "fix: restore X (was corrupted)" or similar
- The refactor extracts types/constants/helpers to new files
- The project uses tsx, esbuild, swc, vitest, or any other runtime that strips types

## Full procedure

### Step 1 — Discover the refactor

```bash
# See new refs without changing anything
git fetch --all --dry-run

# What branches exist on origin that aren't local?
git branch -r | grep -v HEAD

# What's ahead/behind vs origin?
git status   # "Your branch is ahead of 'origin/X' by N commits" is the key signal
```

If the local branch is **behind** origin, the refactor lives on a remote branch you do
not have checked out. That is the branch to review.

### Step 2 — Isolate with a worktree

Do NOT use `git checkout origin/<branch> -- <files>` in the main worktree. It pollutes
`git status`, is easy to forget to clean up, and conflicts with any in-progress work.

```bash
# Create an isolated worktree
git worktree add /tmp/<branch>-review origin/<branch>

# Inspect the new branch
cd /tmp/<branch>-review
git log --oneline origin/<base>..HEAD
git diff --stat origin/<base>..HEAD
```

### Step 3 — Reuse node_modules

Do not run `npm install` from scratch — it is slow and may resolve different versions.
Symlink the main repo's `node_modules` instead:

```bash
ln -s /root/work/<main-repo>/node_modules /tmp/<branch>-review/node_modules
```

### Step 4 — Run BOTH gates (test + typecheck)

This is the single most important step. **Tests passing is not enough** for tsx/esbuild
projects — those transpilers strip types without checking them.

```bash
# 1. Test gate
cd /tmp/<branch>-review
node --import tsx --test <test-file>
# or
npm test

# 2. Typecheck gate — MUST run this separately
cd backend && npx tsc --noEmit
cd ../frontend && npx tsc --noEmit
# or
npm run typecheck --workspaces
```

A refactor that breaks every type in a file will still show **all tests green** if you
skip step 2. This is the most common way bad refactors ship.

### Step 5 — Hunt refactor smells

Walk the diff and look for these patterns. All have been seen in real refactors:

| Smell | How to detect | Why it matters |
|---|---|---|
| Missing `export` on extracted types | `tsc` errors: `TS2459`, `TS2724` | File imports the type from the new module; the new module never exported it. |
| Wrong import name (typo) | `tsc` error: `'X' has no exported member named 'Y'. Did you mean 'Z'?` | Agent renamed a type in conversation.ts but didn't update the import in voiceActions.ts. |
| Orphaned reference to "removed" function | `tsc` error: `Cannot find name 'X'` | Refactor commit message says "remove readFileSync" but a call site still uses it. |
| Field referenced but not defined | `tsc` error: `Property 'X' does not exist on type 'Y'` | New type doesn't carry the field the code tries to set (e.g. `expiresAt`, `actionHash`, `traceId`). |
| Name conflict (local + re-export) | `tsc` errors: `TS2484`, `TS2440` | Same type declared locally AND re-exported via `export type { ... }` from a barrel. |
| Implicit `any` in callback | `tsc` error: `TS7006` | `.map(x => ...)` where `x` lost its type after the refactor. |
| Barrel claims more than it re-exports | Read the barrel file, compare to its comment | An `index.ts` that says "exports constants + types" but only does `export * from '../parent.js'`. |
| Empty-blob restoration hiding a regression | `git show <sha> --stat` showing `e69de29` | Hash `e69de29` is the empty blob. The file was wiped at that point. The "fix" commit that restored it must be diffed against the last good version. |

### Step 6 — Verify any "restore from corruption" commits

If a commit message says "fix: restore X (was corrupted)" or "fix: re-add X":

```bash
# Did the file get wiped? Look for the empty blob hash
git show <fix-commit>^:<file> | wc -c       # 0 bytes = empty
git show <fix-commit>:<file> | wc -c       # non-zero = restored

# Diff the restored version against the last known good commit
git diff <lastGoodCommit>..<fixCommit> -- <file>
```

A legitimate restoration should differ only in:
- import path (e.g. `'./voiceActions.js'` → `'./voiceActions/index.js'`)
- whitespace or comments
- the bare minimum needed to point at the new module structure

If the diff shows body changes (logic, function signatures, new branches), the
"corruption" may have hidden a real regression that the "fix" did not address.

### Step 7 — Report in the user's preferred format

Concrete template (Hebrew house style for this user):

```
## ✅ מה שעובד (אומת בפועל)
- ... (test counts, file:line, command output)

## 🚨 מה שבור
- ... (each broken thing with file:line and the tsc/test evidence)

## 🎯 מה אני מציע
1. ... (concrete next step)
2. ... (concrete next step)
```

Vague "looks good" or "tests pass" is not enough on an untrusted refactor. Always cite
the file:line, the command that revealed the issue, and the specific evidence.

### Step 8 — Cleanup

```bash
# After the review is done
git worktree remove /tmp/<branch>-review
rm /tmp/<branch>-review   # if it was a symlinked worktree
```

## What this is NOT for

- **Pre-commit review of your own work.** That is `requesting-code-review` and runs a
  similar but different pipeline (static scan, baseline comparison, reviewer subagent).
- **Reviewing a teammate's PR via GitHub inline comments.** That is `github-code-review`.
- **Hardening a live codebase you own.** That is the rest of `incremental-hardening-refactor`.

## Real example (this skill's origin)

Branch `origin/refactor-voiceactions` in a Ruby voice repo. 13 commits by `maton-app[bot]`.
Pattern: extract types → `voiceActions/types.ts`, constants → `voiceActions/constants.ts`,
module-level helpers → `frontend/src/appHelpers.ts`. The branch also contained a
"fix: restore askRuby.ts (was corrupted)" commit.

Result of running this procedure:
- ✅ Tests: 79/79 pass, ~16s
- ✅ Frontend typecheck: clean
- ❌ Backend typecheck: 24 errors
- ❌ The "restore" commit only changed the import path — that part was clean — but the
  rest of the refactor shipped with 14 missing `export` keywords, 1 wrong import name
  (`VoiceActionCorrelation` vs `VoiceTurnCorrelation`), 3 fields referenced but not
  defined (`expiresAt`, `actionHash`, `traceId`), 1 orphaned `readFileSync` call, 1
  name conflict, 2 implicit `any`, and a misleading barrel comment.

**Verdict: do not merge as-is.** The runtime works; the type system is broken.

## Pitfall: the refactor branch may be behind base

External refactors are often done on a snapshot of `main` taken days or weeks
earlier. By the time the user asks you to verify, the base has moved on — usually
with feature commits that the refactor does not know about.

Symptoms:
- The refactor branch refactors `X` but `main` has added a new sibling feature
  (e.g. a new `whatsapp_send` action type) that the refactor never touched.
- After you `git fetch` and see commits on the local `main` not in the refactor,
  the refactor is missing them.
- A `git rebase` or `git merge` of the refactor onto `main` will conflict on
  exactly the files the new feature touched.

Detect before doing anything destructive:

```bash
# What commits are on main that are NOT in the refactor branch?
git log --oneline <refactor-branch>..main

# Is the refactor ahead of origin/main but missing local main?
git status      # "Your branch is ahead of 'origin/X' by N commits" is the key signal
```

In the second pass at the same repo, the refactor was based on `origin/main`
(1f4b53a). Local `main` had 5 WhatsApp commits on top (e9e31c0). Those 5
commits added `WhatsAppSendPayload`, the `'whatsapp_send'` action type, and all
the WhatsApp plumbing. The refactor refactored a *pre-WhatsApp* snapshot and
shipped without it — meaning the refactor branch could never merge cleanly even
if every typecheck error were fixed.

The fix is not to rebase the refactor onto local `main` and try to resolve
dozens of conflicts in `voiceActions.ts`. It is to start the fix work from a
clean local main and re-apply the refactor's *good parts* (the new files, the
structural changes) on top.

## Decision: when rebase/merge conflicts pile up, switch strategy

After the first rebase or merge attempt, count the conflict markers:

```bash
grep -c "<<<<<<<\|=======\|>>>>>>>" <conflicted-file>
```

Heuristics:
- **0–2 conflicts** in 1–2 files: resolve them manually and continue. Usually
  trivial (an import path, a function signature).
- **3+ conflicts in 1 file** OR conflicts across 2+ files: the structural intent
  of the refactor is incompatible with the structural intent of the base. Trying
  to resolve by hand will produce a frankenstein that confuses future readers.
  Abort, switch strategy.

The alternative strategy:
1. Abort the merge / rebase (`git merge --abort` or `git rebase --abort`).
2. Get user approval before doing destructive operations like
   `git reset --hard <base>` (see "Confirm with the user" below).
3. From a clean base, take the refactor's *new files* and *structural changes*
   file-by-file using `git show <refactor-branch>:<file>` to extract the content.
4. Hand-write or surgically patch the modified files so they combine:
   - the base's current feature set (everything added after the refactor's
     snapshot was taken)
   - the refactor's structural intent (extracted types/constants/helpers,
     import paths, barrel exports)
5. Squash the entire delta into one clean commit, not thirteen.
6. Run the full verification gate again.

The user explicitly chose this approach when offered the choice between
"rebase and resolve 5 conflicts" and "abort, reset to main, re-apply the
refactor's good parts as a single squash".

## Pitfall: the main worktree may be locked

In multi-worktree setups, `main` is typically checked out in exactly one
worktree. You cannot `git checkout main` from another worktree — git will
refuse with `fatal: 'main' is already used by worktree at <path>`.

Patterns that work:
- From the new worktree, use `git reset --hard <ref>` to move the current
  detached HEAD to a specific commit, then `git checkout -b fix/<name>` to make
  it a working branch.
- Or create yet another worktree explicitly tied to a ref:
  `git worktree add /tmp/<name>-fix <base-ref> -b fix/<name>`.
- Do not try to `git branch -D` a branch created in this session without user
  approval — it counts as a destructive operation even if you created the
  branch yourself a moment ago.

## Confirm with the user before destructive operations

Operations like `git reset --hard <base>`, `git branch -D <branch>`, and
`git rebase --abort` on a partially-completed rebase are destructive in the
sense that they discard work-in-progress or branch state. Even if the work was
created in the current session, ask via `clarify` before running them. The
user's house rule is: "risky/destructive changes require approval".

When the merge produced 5 conflicts in `voiceActions.ts` and 3 in
`rubyBridge.ts`, the right move was to present the user with a multi-choice
`clarify` asking which strategy to take, and to spell out the concrete end
state of each option. The user picked the squash-reset option and the work
moved forward cleanly.

## Real example addendum: the same case plus fall-behind base

Same repo (`origin/refactor-voiceactions`) but a later session found a new
failure mode: the refactor branch was based on an old snapshot of `main` that
did not include 5 WhatsApp commits. The first session's verdict ("do not
merge as-is, 24 typecheck errors") was still correct, but a second pitfall
emerged:

- Tests passed (the WhatsApp tests did not exist on the refactor's snapshot).
- The `fix: restore askRuby.ts (was corrupted)` commit was clean and could
  still be reused as-is.
- A plain `git rebase main` failed at the type-extraction commit with 1 conflict.
- A plain `git merge origin/refactor-voiceactions` produced 5 conflicts
  (3 in `voiceActions.ts`, 2 in `rubyBridge.ts`) because main's WhatsApp types
  collided with the refactor's narrower type definitions.

Correct next move (per the strategy above):
1. Abort the merge.
2. Create a new worktree from local `main` (e9e31c0) so WhatsApp is present.
3. Use `git show <refactor-branch>:<file>` to extract the refactor's good files
   (`voiceActions/constants.ts`, `voiceActions/index.ts`,
   `frontend/src/appHelpers.ts`).
4. Hand-write `voiceActions/types.ts` from main's *current* type set, with
   `export` on every type and the fields the code actually uses
   (`actionHash`, `expiresAt`, `traceId` in `HermesReplyNotification.timings`).
5. Patch `voiceActions.ts` to import from the new submodules while keeping
   main's WhatsApp code paths.
6. Update `rubyBridge.ts` and `askRuby.ts` to use the new barrel path.
7. Run the full gate: `npx tsc --noEmit` in both workspaces, `npm test` (or
   `node --import tsx --test`), and `npm run build` if the project has one.
8. Single clean squash commit on a `fix/refactor-merge` branch. Do not push to
   `origin` without explicit user approval.

The user's preferred report format for this work is brief Hebrew with sections
like `מה נבדק / מה שעובד / מה שבור / מה אני מציע` and concrete `file:line`
evidence for every claim.
