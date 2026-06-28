# 9-Category Public Repo Audit (validated 2026-06-25, FullStack-Builder)

The shallow 4-category grep returned "0 findings." The deeper 9-category
audit found 60+ issues. This reference captures the worked example so
the next session starts at category 5, not category 1.

## The trap

A first-pass audit on the public repo `dizeldz20-ux/FullStack-Builder`
used these patterns:

```bash
grep -rln "sbp_\|sk-\|ghp_\|cfat_\|@gmail\.com" .
grep -rln "100\.[0-9]\+\.[0-9]\+\.[0-9]\+\|vmi[0-9]\+" .
grep -rln "Dizel\|Maimon" .
grep -rln "C:\\\\Users\\\\" .
```

Result: "0 findings." the user pushed back: "תחפור במקומות
שלא חשבת לחפור בהן." The deeper pass found 60+ issues across 4 commits
to clean (3 commits total: v1.4.1 + v1.4.2).

## What the 4-category first pass missed

### 1. Boilerplate attribution (25 occurrences in 17 files)

`prd-generator` and `e2e-testing` were scaffolded by a `skillsmith init`
binary that left this in every file footer:

```
*Built with Skillsmith · [your-ai-product] Systems · https://[your-ai-product].cv/skool*
```

Plus `provenance.skillsmith_source: "https://[your-ai-product].cv/skool"` in the
YAML frontmatter of `prd-generator/SKILL.md`.

**Why first pass missed it:** The grep matched `@gmail.com` and email
patterns, but `[your-ai-product].cv/skool` is a URL, not an email. The boilerplate
is "attribution noise" — easy to dismiss as harmless.

**Fix:** Replace `[your-ai-product].cv/skool` and `[your-ai-product] Systems` with a generic
`<skillsmith-spec>` placeholder in all 17 files. Remove the
`provenance.skillsmith_source` line from frontmatter.

### 2. Brand names as proper nouns (10+ occurrences)

`Ruby's super-builder` appeared in:
- `build-product/CHANGELOG.md` (3x)
- `build-product/SKILL.md` (4x — including pitfall titles)
- `build-product/frameworks/scripts/scaffold-{node,python}.sh` (2x — in comments)
- `build-product/frameworks/routing-map.md` (2x)

Other brand leaks found:
- `[your-voice-product]-specific` in `SKILL.md` line 331
- `creative/ruby-design-triad` in `routing-map.md`
- `[your-product]` in `routing-map.md`

**Why first pass missed it:** "Ruby" is not a secret, and the patterns
look like normal text. The grep was searching for IP-shaped strings,
not proper nouns.

**Fix:** Replace with `a peer agent's super-builder pattern` and similar
generic phrasings. Keep the attribution concept (something was borrowed)
without naming the source.

### 3. Backup folder paths with timestamps

`~/.[vault-runner]/workspace/_backup-command-center-v0.1-20260609-064221/command-center-v0.1/command-center.config.json`
appeared in `build-product/SKILL.md` line 80, embedded in a pitfall.

**Why first pass missed it:** The grep matched `/root/.[vault-runner]` paths
in a different way — it caught `.[vault-runner]` substrings, not the full
backup path with timestamp. The timestamp `20260609-064221` (June 9,
2026, 06:42:21) leaks when a backup was created.

**Fix:** Replace the entire path with `the canonical agent config file`.

### 4. Cross-references to skills that don't exist in the public repo

11 `@../../<skill-name>/SKILL.md` references in `build-product/SKILL.md`
point to skills that live only in the user's private Hermes runtime:

- `cavecrew-builder`
- `cavecrew-investigator`
- `cavecrew-reviewer`
- `incremental-hardening-refactor`
- `loop-library`
- `plan`
- `requesting-code-review`
- `spike`
- `subagent-driven-development`
- `systematic-debugging`
- `test-driven-development`
- `writing-plans`

These are valid references **for the user** (who has these skills
installed), but **break for any external reader** who clones the public
repo. The references silently 404.

**Why first pass missed it:** Grep matches `@\.\.` patterns; it does
not validate that the target file exists.

**Fix:** Decide which references are documentation (keep, but mark as
"private skill") vs which are actually needed by the public build.
For the public version, the references work for the original author
who has the skills installed — but external readers will see broken
links. The right fix is either to add a "Prerequisites" section to the
README listing the required skills, or to remove the cross-references
from public-facing docs.

### 5. Cross-product brand contamination

`build-product/SKILL.md` line 281 mentioned `a command-center product`
as one of the user's products. `routing-map.md` had `<my-product>-*`
prefixed with `Ruby live voice product`.

**Why first pass missed it:** First pass didn't include product names
in the search patterns.

**Fix:** Replace with `a specific product (e.g. Next.js based)`.

### 6. Stale session narratives

`SKILL.md` line 80 had:

> "the user pushed back twice in one session with the same correction:
> 'יש לך גישה מלאה, תחפש בעצמך'. Memory captures the preference; this
> rule makes sure the agent actually does it every time."

This is a **single-session narrative** that does not belong in a public
skill. It leaks (a) the user's frustration history, (b) a quote in
Hebrew that anchors the user to a specific session.

**Why first pass missed it:** It looks like part of the rule
documentation, not PII.

**Fix:** Strip the narrative; keep the rule. "Search before asking" is
the rule — the history of how the user pushed back is not.

### 7. Repo-meta inconsistency

| What was wrong | Where | Fix |
|---|---|---|
| "11 skills" in README | README.md line 11 | "15 skills" |
| "we already have 5" | CONTRIBUTING.md line 21 | "we already have 15" |
| "v1.2.1" (stale) | UPDATE.md | Add v1.4.0 entry with 6 new skills |
| `[vault-workspace]/memory/.secrets/` | `.gitignore` line 26 | `/<agent-vm-home>/<service>/.secrets/` |
| `YOUR-USERNAME` placeholder | README.md (3x) | `dizeldz20-ux` |
| Version `0.1.0` on 4 skills | analytics, customer-support, pricing, privacy | Bump to `1.0.0` |

**Why first pass missed it:** First pass focused on secrets/PII, not
on version drift or placeholder leakage.

### 8. Scripts living in the wrong place

`scripts/security-scan-public.sh` was created inside
`skills/<name>/scripts/` (i.e. `skills/software-development/build-product/scripts/`)
instead of the repo's top-level `scripts/` directory. README and
CONTRIBUTING referenced `scripts/security-scan.sh` but not
`security-scan-public.sh`. A reader cloning the repo would not find
the public-scan script in the obvious place.

**Fix:** Move/copy the script to the repo's top-level `scripts/` and
ensure both scripts are documented in CONTRIBUTING.

### 9. Attribution leaks in skill frontmatter

`prd-generator/SKILL.md` line 20:

```yaml
provenance:
  skillsmith_version: "1.0.0"
  skillsmith_source: "https://[your-ai-product].cv/skool"
  generated_by: "manual scaffold following skillsmith specs (no `skillsmith init` binary present in this repo)"
```

The `provenance` block was scaffolded by the same `skillsmith init`
template that left the footer attribution. `provenance.skillsmith_source`
points to a third-party site that the public repo should not link to.

**Fix:** Remove the entire `provenance:` block (or replace
`skillsmith_source` with `<skillsmith-spec>`).

## The 9-category checklist

```bash
# Category 1: Standard secrets/PII (the "shallow" pass)
grep -rln "sbp_\|sk-\|ghp_\|cfat_\|@gmail\.com\|@[a-z]\+\.[a-z]\+\.com" .

# Category 2: Network/internal IPs and hostnames
grep -rln "100\.[0-9]\+\.[0-9]\+\.[0-9]\+\|vmi[0-9]\+\|contaboserver\|\.ts\.net\|Tailscale IP" .

# Category 3: Personal paths
grep -rln "/root/\.[vault-runner]\|/root/\[hermes-config-dir]/memories/Hermes/Brain\|/root/\.ssh\|C:\\\\Users\\\\\|/Users/\|OneDrive" .

# Category 4: Brand names (own + third-party templates)
grep -rln "[your-voice-product]\|[your-other-product]\|[your-other-product]\|[your-product]\|[your-github-username]\|[your-ai-product]\|[your-ai-product]\|skool" .

# Category 5: Backup/timestamp patterns in paths
grep -rln "backup-[a-z-]\+-[0-9]\+\-[0-9]\+\|[0-9]\{8\}-[0-9]\{6\}" .

# Category 6: Cross-reference validation (every @ path must resolve)
grep -rh "@\.\." . | grep -oE "@\.\.[^ )]+" | sort -u | while read ref; do
  target="${ref:1}"
  [ -f "$target" ] || [ -d "$target" ] || echo "BROKEN: $ref -> $target"
done

# Category 7: Attribution/contamination in footers and frontmatter
grep -rln "Built with\|generated by\|maintained by\|skillsmith_source\|provenance" .

# Category 8: Session-narrative leakage
grep -rln "יש לך גישה\|user pushed back\|session \[\|validated 2026-0[67]-[0-9]\{2\} v" .

# Category 9: Repo-meta consistency
#   - SKILL.md count in README vs `find . -name SKILL.md | wc -l`
#   - Latest version in UPDATE.md vs latest SKILL.md frontmatter
#   - .gitignore paths reference specific machines
#   - Placeholder strings still present (YOUR-USERNAME, your-email, etc.)
#   - Skill versions consistent (no 0.1.0 on production-ready skills)
```

## Outcomes

After running all 9 categories on FullStack-Builder:

- **3 commits** to clean: `a27a8b5` (v1.4.1, 38 files), `8cd7f51` (v1.4.2, 1 file)
- **0 secrets, 0 PII, 0 brand names, 0 backup paths, 0 broken paths** at HEAD
- **15 skills** Skillsmith-compliant with consistent versions
- **2 security scripts** in repo root `scripts/`

## Time cost

The 9-category pass took ~15 minutes (grep + manual fix). The shallow
4-category pass had taken ~2 minutes and returned 0 — which is
**worse** than no audit because it gave false confidence.

The lesson: **a quick audit that returns 0 findings is more dangerous
than a slow audit that returns 60 findings.** The slow audit surfaces
real issues. The quick audit gives the user a false sense of security.

## Reference

The full session transcript is in the conversation history. The actual
commits are `a27a8b5` and `8cd7f51` on
`dizeldz20-ux/FullStack-Builder`.