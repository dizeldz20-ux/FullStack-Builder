# adding-skills-to-super-skill.md (stub)

> **[stub]** — This file is referenced from `build-product/SKILL.md` but is not yet implemented in the public release. It documents the workflow for adding a new skill to the `build-product` super-skill.

This file should cover:
- Step 1: Verify the skill exists locally (Vault) and passes `audit-skill.sh`
- Step 2: Add to `related_skills` frontmatter in `build-product/SKILL.md`
- Step 3: Wire into at least one task in `tasks/*.md` (otherwise it's orphan)
- Step 4: Add to the loop coverage matrix in `frameworks/loops.md`
- Step 5: Update CHANGELOG and re-run CI guardrail

The CI guardrail in `.github/workflows/validate.yml` will block any PR that adds a skill to `related_skills` without it being shipped in `skills/`.

**To fill this stub**, copy the developer's local Vault version (if present) or implement from scratch.