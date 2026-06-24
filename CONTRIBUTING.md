# Contributing to FullStack Builder

Thanks for your interest! Here's how to contribute effectively.

## Before opening a PR

1. **Open an issue first** describing what you want to change. This avoids duplicate work and lets us discuss the approach.
2. **Check the skillsmith spec** — all skills in this repo follow the [skillsmith convention](https://github.com/smith-horn/skillsmith). Read the spec before adding a new skill.
3. **Test against a real Hermes install** — copy your modified skill into `~/.hermes/skills/`, restart Hermes, and verify it loads.

## What we accept

- **Bug fixes** to existing skills (typos, broken code, missing steps)
- **New frameworks** under existing skills (e.g. a new `theme-cyberpunk.md` under `ui-design-system`)
- **New tasks** under existing skills (e.g. a new `deploy-cloudflare-pages.md` under `cloudflare-deploy`)
- **Better examples** in any framework
- **Improved pitfall blocks** based on real production issues

## What we DON'T accept

- New top-level skills (we already have 15, and they compose well — adding more creates fragmentation)
- Changes that add secrets, API keys, or account IDs to the files (they must be placeholders like `YOUR_*` or `your-*`)
- Changes that break the skillsmith convention (e.g. mixing workflow into `SKILL.md` instead of `tasks/`)
- Changes that remove the validation steps (every skill must have a "verified against X" note)

## Style guide

- **Hebrew for explanations, English for code** (consistent with `build-product`)
- **Tables for decisions, bullets for steps, code blocks for commands** — no walls of prose
- **3+ commands = 1 script** — never list numbered steps when a script can do it
- **All placeholders must be obvious** — `YOUR_ACCOUNT_ID`, `your-email@example.com`, not `[INSERT YOUR ID HERE]`

## Running the security scan

Before committing, run:

```bash
./scripts/security-scan.sh
```

This scans for:
- Real API tokens (Cloudflare, Supabase, GitHub, OpenAI, Anthropic)
- Real account IDs
- Real email addresses
- Internal file paths (e.g. `~/projects/<secret-dir>/`, `~/.config/<service>/`)
- Partial token prefixes (e.g. <partial-token-prefix>)

If the scan finds anything, **the PR will be rejected**.

## Testing your changes

```bash
# 1. Copy your skill into Hermes
cp -r skills/software-development/your-skill ~/.hermes/skills/software-development/

# 2. Restart Hermes
# (depends on your setup)

# 3. Load the skill and verify it works
/your-skill
```

If the skill doesn't load, check the YAML frontmatter for syntax errors.

## Reporting issues

When reporting a bug, include:
- The Hermes version
- The skill name + version
- The exact error message
- A minimal reproduction

## License

By contributing, you agree that your contributions will be licensed under the MIT License (see [LICENSE](LICENSE)).
