# Python `<< 'PYEOF'` Heredoc for Batch Pattern Replacement

Use when you need to do multi-pattern text replacement across many
files, especially when:
- The patterns contain Unicode (Hebrew, emoji, smart quotes)
- The patterns span multiple lines
- The patterns contain regex special characters that are painful to
  escape in `sed`
- You need a per-file audit trail of what changed

Verified on FullStack-Builder June 2026: 17 files, 6 patterns, ~90
seconds total. Same job with `sed` took 20 minutes of escape debugging
and produced silent failures on multi-line patterns.

## The base pattern

```bash
python3 << 'PYEOF'
import os

# Map of "bad string" -> "good replacement"
REPLACEMENTS = [
    ('old_string_1', 'new_string_1'),
    ('old_string_2', 'new_string_2'),
    # ... add as many pairs as you need
]

count = 0
for root, dirs, files in os.walk('skills'):
    for file in files:
        if not file.endswith(('.md', '.sh', '.py', '.yml', '.yaml')):
            continue
        path = os.path.join(root, file)
        with open(path, 'r') as f:
            content = f.read()
        original = content
        for old, new in REPLACEMENTS:
            content = content.replace(old, new)
        if content != original:
            with open(path, 'w') as f:
                f.write(content)
            count += 1
            print(f"  ✅ Fixed: {path}")

print(f"\n🎉 Total files fixed: {count}")
PYEOF
```

## Why `'PYEOF'` (with quotes)?

The single quotes around `'PYEOF'` prevent bash from doing variable
expansion, command substitution, or backtick interpretation on the
content of the heredoc. The Python code stays literal. **Always use
quotes** unless you have a specific reason to do shell expansion
inside the heredoc.

Without quotes (`<< PYEOF` instead of `<< 'PYEOF'`), bash will try
to expand `$1`, `$variable`, `$(command)`, and backticks inside the
heredoc body. That breaks Python f-strings, dictionary access like
`{0:>5}`, and any string containing `$`.

## Why this beats `sed -i`

| Problem | `sed -i` | Python heredoc |
|---|---|---|
| Multi-line pattern | Requires `-z` flag, awkward | Just put the newlines in the string |
| Special chars `/`, `&`, `\` | Need to escape each one | Treat as literal |
| Hebrew / emoji | Often stripped under LC_ALL=C | Unicode-safe |
| Multi-pattern chain | Need N sed invocations | One script, ordered |
| Audit trail | Silent | Prints per-file output |
| Order of replacement | Last-wins per file | Controlled by script order |
| Backslash at end of line | Escapes the newline, breaks | Plain string |

## Variants

### Single file, single replacement

```bash
python3 << 'PYEOF'
with open('CHANGELOG.md', 'r') as f:
    content = f.read()
content = content.replace(
    "After auditing 448 skills in the command-center local vault on the user's machine",
    "After auditing skills in the upstream skills registry"
)
with open('CHANGELOG.md', 'w') as f:
    f.write(content)
PYEOF
```

### Regex with re.sub()

When you need regex (e.g. pattern with character classes), use
`re.sub()`:

```bash
python3 << 'PYEOF'
import os
import re

count = 0
for root, dirs, files in os.walk('skills'):
    for file in files:
        if not file.endswith('.md'):
            continue
        path = os.path.join(root, file)
        with open(path, 'r') as f:
            content = f.read()
        original = content
        # Catch-all: any "[your-ai-product] Systems" or "[your-ai-product].cv/skool" reference
        content = re.sub(r'[your-ai-product] Systems · https://[your-ai-product]\.cv/skool', 'Skillsmith', content)
        content = re.sub(r'[your-ai-product] Systems', 'Skillsmith', content)
        content = re.sub(r'https://[your-ai-product]\.cv/skool', '<skillsmith-spec>', content)
        if content != original:
            with open(path, 'w') as f:
                f.write(content)
            count += 1
            print(f"  ✅ Fixed: {path}")

print(f"\n🎉 Total files fixed: {count}")
PYEOF
```

### Process specific files only (not directory walk)

```bash
python3 << 'PYEOF'
import os

FILES = [
    'README.md',
    'UPDATE.md',
    'CONTRIBUTING.md',
    '.gitignore',
]

for path in FILES:
    if not os.path.exists(path):
        print(f"  ⏭️ Skipped (not found): {path}")
        continue
    with open(path, 'r') as f:
        content = f.read()
    original = content
    content = content.replace('11 skills', '15 skills')
    content = content.replace('YOUR-USERNAME', 'dizeldz20-ux')
    content = content.replace('we already have 5', 'we already have 15')
    if content != original:
        with open(path, 'w') as f:
            f.write(content)
        print(f"  ✅ Fixed: {path}")
    else:
        print(f"  ⏭️ No change: {path}")
PYEOF
```

### Version bump on frontmatter only (skip body references)

When you need to bump versions in YAML frontmatter but not in code
blocks (where `version: 1.0.0` is shown as an example):

```bash
python3 << 'PYEOF'
import os
import re

count = 0
for root, dirs, files in os.walk('skills'):
    for file in files:
        if file != 'SKILL.md':
            continue
        path = os.path.join(root, file)
        with open(path, 'r') as f:
            content = f.read()
        # Only replace first occurrence (in frontmatter), use re.sub with count=1
        new_content = re.sub(r'^version: 0\.1\.0$', 'version: 1.0.0',
                             content, count=1, flags=re.MULTILINE)
        if new_content != content:
            with open(path, 'w') as f:
                f.write(new_content)
            count += 1
            print(f"  ✅ Bumped: {path}")

print(f"\n🎉 Versions bumped: {count}")
PYEOF
```

The `count=1` flag on `re.sub` ensures only the first match (in
the frontmatter) is replaced, not every subsequent occurrence in
the body where the version might appear in code blocks.

## When NOT to use this

- **Single-character substitution** (`s/X/Y/g`): use `sed -i`.
- **Whitespace cleanup** (`s/  *$//`): use `sed -i`.
- **You're on a system without Python** (rare): fall back to a
  careful `sed -i` chain.
- **The pattern is regex** but Python's `re` is overkill: just use
  `sed -E` for simple cases.

## Common mistakes

### Variable expansion (no quotes)

```bash
# ❌ WRONG: bash will try to expand $1, $(cmd), etc. inside the heredoc
python3 << PYEOF
print("$(whoami)")  # bash expands this to print("dizeldz20")
                    # then Python tries to find a variable named "dizeldz20"
PYEOF

# ✅ RIGHT: use 'PYEOF' to prevent expansion
python3 << 'PYEOF'
print("$(whoami)")  # literal string, prints exactly $(whoami)
PYEOF
```

### F-string collisions with shell

```bash
# ❌ WRONG: f-string syntax collides with shell $VAR
python3 << PYEOF
name = "dizeldz20"
print(f"hello {name}")  # bash tries to expand ${name} first
PYEOF

# ✅ RIGHT: 'PYEOF' preserves the f-string
python3 << 'PYEOF'
name = "dizeldz20"
print(f"hello {name}")
PYEOF
```

### Forgetting `import os`

When using `os.walk`, you need `import os` at the top. Easy to
forget in heredocs:

```bash
# ❌ NameError: name 'os' is not defined
python3 << 'PYEOF'
for root, dirs, files in os.walk('.'):
    ...
PYEOF

# ✅ Add the import
python3 << 'PYEOF'
import os
for root, dirs, files in os.walk('.'):
    ...
PYEOF
```

### Writing to a file that's being read

The script reads content into memory first, then writes. Don't try
to read and write the same file path in one operation without
intermediate storage.

## Combining with git workflow

```bash
# 1. Run the heredoc
python3 << 'PYEOF'
# ... replacement logic ...
PYEOF

# 2. Verify changes
git status

# 3. Stage and commit
git add -A
git commit -m "v1.4.1: Replace [your-ai-product] attribution in 17 files"

# 4. Push
git push origin main
```

The heredoc is the patch. Git is the rollback.

## Real worked example

**Task**: Strip `[your-ai-product] Systems · https://[your-ai-product].cv/skool` from 17
files. Replace with `Skillsmith`. Replace `[your-ai-product].cv/skool` (URL
fragment) with `<skillsmith-spec>`. Remove `provenance.skillsmith_source`
from frontmatter.

**Script**:

```bash
python3 << 'PYEOF'
import os
import re

count = 0
for root, dirs, files in os.walk('skills'):
    for file in files:
        if file.endswith(('.md', '.sh', '.py')):
            path = os.path.join(root, file)
            with open(path, 'r') as f:
                content = f.read()
            original = content
            # Footers
            content = re.sub(r'\*Built with Skillsmith · [your-ai-product] Systems.*?\*',
                             '*Built with Skillsmith*', content)
            # Other phrasings
            content = re.sub(r'[your-ai-product] Systems', 'Skillsmith', content)
            content = re.sub(r'[your-ai-product]\.cv/skool', '<skillsmith-spec>', content)
            if content != original:
                with open(path, 'w') as f:
                    f.write(content)
                count += 1
                print(f"  ✅ Fixed: {path}")

print(f"\n🎉 Total files fixed: {count}")
PYEOF
```

**Result**: 17 files modified in 90 seconds. All `[your-ai-product]`
references removed. Audit confirmed 0 hits with `grep -rn [your-ai-product]
. --exclude-dir=.git`.

## Reference

- The `incremental-hardening-refactor` SKILL.md has the
  "Python `<< 'PYEOF'` heredoc is the right tool for batch pattern
  replacement" pitfall that points to this reference.
- The 9-category audit (see `9-category-public-repo-audit.md`)
  typically uses 2-3 of these heredocs to apply the fixes after
  the grep pass.