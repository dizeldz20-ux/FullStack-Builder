# Publishing a Skill to a Public Repo — Source + Public Validation

When you publish a Hermes skill (or a bundle of skills) to a **public GitHub repo**, two distinct copies exist and both must validate. This reference is the recipe for not silently leaving bugs in the source.

## The two copies

| Copy | Path | Lives where | What runs it |
|------|------|-------------|--------------|
| **Source** | `~/.hermes/skills/<category>/<skill>/` | Your live Hermes install | The agent on every `/skill-name` invocation |
| **Public** | `/tmp/<public-repo>/skills/<category>/<skill>/` | Staging directory before `git push` | Anyone who clones the public repo |

The public copy is a snapshot. The source is what *your* Hermes actually loads. **A bug in the source is more important than a bug in the public copy** — your live skill is broken, while the public copy is just a snapshot you can rebuild.

## Pass 1 — Validate the public copy

Run these before `git push`:

```bash
PUBLIC=/tmp/<public-repo>

# 1. Frontmatter closed (works even when description has quotes)
for skill_md in $(find "$PUBLIC" -name SKILL.md); do
  skill_dir=$(dirname "$skill_md")
  dashes=$(grep -c '^---$' "$skill_md")
  if [ "$dashes" -lt 2 ]; then
    echo "❌ UNCLOSED frontmatter: $skill_dir/SKILL.md"
  else
    echo "✅ $skill_dir"
  fi
done

# 2. No secrets/PII (run your security-scan.sh)
./scripts/security-scan.sh "$PUBLIC"

# 3. related_skills resolve (from build-product/frameworks/validate-related-skills.sh or your own)
~/.hermes/skills/software-development/build-product/scripts/audit-skill.sh "$PUBLIC/skills/<path>"
```

## Pass 2 — Validate the SOURCE (this is the one most agents skip)

```bash
SOURCE=~/.hermes/skills/<category>/<skill>

# 1. Same frontmatter check
dashes=$(grep -c '^---$' "$SOURCE/SKILL.md")
[ "$dashes" -ge 2 ] && echo "✅ source frontmatter closed" || echo "❌ SOURCE BROKEN"

# 2. Hermes can actually load it (ground truth, not "the YAML parses")
timeout 30 hermes skills list 2>&1 | grep -F "<skill-name>" && echo "✅ Hermes can load it" || echo "❌ NOT in hermes skills list"

# 3. All related_skills resolve (the existing pitfall's recipe)
~/.hermes/skills/software-development/build-product/scripts/audit-skill.sh "$SOURCE"
```

**If Pass 2 fails, fix the source first, then re-sync to the public copy.** Never fix the public copy alone — the bug stays in the live skill.

## Three-source equivalence check (after publishing)

Before pushing, prove source and public are equivalent except for deliberate scrubbing:

```bash
diff -rq ~/.hermes/skills/<path>/ /tmp/<public-repo>/<path>/
# Empty output = equivalent (modulo scrubbing)
# Any non-empty output = review each line: was it a deliberate scrub, or a bug?
```

The 3 expected kinds of diff for a deliberately-scrubbed publish:

1. **Account IDs / tokens** → placeholder strings (e.g. `YOUR_CLOUDFLARE_ACCOUNT_ID`)
2. **Email addresses** → `you@example.com`
3. **Internal filesystem paths** → `~/<...>` (generic)

Anything else (typos, missing files, structural changes) is a bug — fix it before push.

## The 5 reusable techniques from the 2026-06-24 FullStack-Builder publish

### 1. Frontmatter close check (grep, not YAML)

```bash
# Why grep not YAML: description: "Some text with "quotes" inside" breaks PyYAML
# and returns None for the whole frontmatter, masking the real issue.
grep -c '^---$' path/to/SKILL.md
# >= 2 = closed, < 2 = unclosed (need to add --- after the last frontmatter field)
```

### 2. Hermes ground-truth check (list, not inspect)

```bash
# Why list not inspect: hermes skills inspect hangs 180s+ on skills with many
# related_skills. hermes skills list returns in <5s and is the fast sanity gate.
timeout 30 hermes skills list 2>&1 | grep -F "<skill-name>"
# If it appears with `enabled` in the output, Hermes can load it.
```

### 3. Audit-skill.sh as the all-purpose validator

`build-product` ships `scripts/audit-skill.sh` — it checks:

- related_skills cross-references resolve
- `<commands>` ↔ `@-references` in `<routing>` agree
- `<commands>` ↔ `route.sh` case statement agree
- `state-update.sh` phase regex ↔ `route.sh` phases agree
- Cross-skill `@-references` (e.g. `@../cloudflare-deploy/SKILL.md`) exist
- Content duplication heuristic across `tasks/*.md`

Use it on **both** source and public copy before any publish.

### 4. Three-pass secret scrub (defense in depth)

When scrubbing secrets for a public publish, do **three passes**, not one:

1. **First scan** — broad patterns (`grep -E '(@gmail\.com|@[a-z]+\.[a-z]+\.com|Account ID|TX[A-Za-z0-9]{20,})'`)
2. **Second scan** — what the first missed (often partial prefixes, lowercase variants, internal path fragments)
3. **Third scan** — token-shaped strings (`sbp_[a-z0-9]+`, `cfat_[a-z0-9]+`, `ghp_[a-z0-9]+`, `sk-[A-Za-z0-9]{20,}`)

Common misses on pass 1 that pass 2 catches:

- `Liam` (proper name → use generic `Voice`)
- `<voice-id>` (ElevenLabs voice ID → strip)
- `~/projects/workspace/...` (internal path → `~/projects/...`)
- <partial-token-prefix> (partial token prefix even after `sbp_` regex match)
- `<your-github-username>` (username without email wrapping)
- `<your-subdomain>` (Cloudflare subdomain — looks like a generic dev name but is yours)

### 5. Self-exclusion in CI security scripts

`scripts/security-scan.sh` will report findings against **itself** if you grep for the patterns it tests for. Always add a self-exclusion:

```bash
SELF=$(realpath "$0")
grep -rEn "$PATTERN" "$TARGET" --exclude="$(basename "$SELF")" || true
```

## Pitfall recap

The one-paragraph version: **when you publish a skill externally, the source is more important than the public copy, but most agents only validate the public copy.** Always run Pass 2 (source) immediately after Pass 1 (public), and use `diff -rq` to prove they only differ by deliberate scrubbing.

The 30-second cost of Pass 2 catches bugs that would otherwise live in your live skill for months.