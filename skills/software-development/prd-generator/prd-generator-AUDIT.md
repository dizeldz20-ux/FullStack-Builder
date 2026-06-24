===================================================
Skillsmith-style Audit: prd-generator
Path: ~/.hermes/skills/software-development/prd-generator
Date: 2026-06-24
===================================================

## 1. Structure

  [32m✓[0m Entry point exists: SKILL.md
  [32m✓[0m Subdirectory exists: tasks/
  [32m✓[0m Subdirectory exists: frameworks/
  [32m✓[0m Subdirectory exists: references/
  [32m✓[0m Required file exists: tasks/interview-questions.md
  [32m✓[0m Required file exists: tasks/generate-prd.md
  [32m✓[0m Required file exists: tasks/prd-template.md
  [32m✓[0m Required file exists: frameworks/prd-quality-checklist.md
  [32m✓[0m Required file exists: frameworks/open-questions-catalog.md
  [32m✓[0m Required file exists: references/prd-examples.md

## 2. Entry Point (SKILL.md)

  [32m✓[0m YAML frontmatter opens with ---
  [32m✓[0m YAML frontmatter closes (found 2 dashes lines)
  [32m✓[0m name: prd-generator present
  [32m✓[0m type: standalone (valid enum)
  [32m✓[0m version: 0.1.0 (semver)
  [32m✓[0m description present (bilingual)
  [32m✓[0m allowed-tools present
  [32m✓[0m related_skills present
  [32m✓[0m related_skills references: build-product
  [32m✓[0m related_skills references: product-build-blueprint
  [32m✓[0m related_skills references: plan
  [32m✓[0m related_skills references: writing-plans
  [32m✓[0m XML section present: <activation>
  [32m✓[0m XML section present: <persona>
  [32m✓[0m XML section present: <commands>
  [32m✓[0m XML section present: <routing>
  [32m✓[0m XML section present: <greeting>
  [32m✓[0m   <activation> has: ## What
  [32m✓[0m   <activation> has: ## When to Use
  [32m✓[0m   <activation> has: ## Not For
  [32m✓[0m   <persona> has: ## Role
  [32m✓[0m   <persona> has: ## Style
  [32m✓[0m   <persona> has: ## Expertise
  [32m✓[0m provenance metadata present (skillsmith_version/source)
  [32m✓[0m skillsmith footer present

## 3. Task Files (tasks/)

  [32m✓[0m tasks/interview-questions.md starts with content (no frontmatter)
  [32m✓[0m   tasks/interview-questions.md has <purpose>
  [32m✓[0m   tasks/interview-questions.md has <user-story>
  [32m✓[0m   tasks/interview-questions.md has <when-to-use>
  [32m✓[0m   tasks/interview-questions.md has <steps>
  [32m✓[0m   tasks/interview-questions.md has <output>
  [32m✓[0m   tasks/interview-questions.md has <acceptance-criteria>
  [32m✓[0m   tasks/interview-questions.md has named steps (count: 11)
  [32m✓[0m   tasks/interview-questions.md has plain checklist acceptance criteria
  [32m✓[0m   tasks/interview-questions.md has skillsmith footer
  [32m✓[0m tasks/generate-prd.md starts with content (no frontmatter)
  [32m✓[0m   tasks/generate-prd.md has <purpose>
  [32m✓[0m   tasks/generate-prd.md has <user-story>
  [32m✓[0m   tasks/generate-prd.md has <when-to-use>
  [32m✓[0m   tasks/generate-prd.md has <steps>
  [32m✓[0m   tasks/generate-prd.md has <output>
  [32m✓[0m   tasks/generate-prd.md has <acceptance-criteria>
  [32m✓[0m   tasks/generate-prd.md has named steps (count: 7)
  [32m✓[0m   tasks/generate-prd.md has plain checklist acceptance criteria
  [32m✓[0m   tasks/generate-prd.md has skillsmith footer
  [32m✓[0m tasks/prd-template.md starts with content (no frontmatter)
  [32m✓[0m   tasks/prd-template.md has fenced markdown template block
  [32m✓[0m   tasks/prd-template.md has skillsmith footer

## 4. Framework Files (frameworks/)

  [32m✓[0m frameworks/prd-quality-checklist.md starts with content
  [32m✓[0m   frameworks/prd-quality-checklist.md has skillsmith footer
  [32m✓[0m frameworks/open-questions-catalog.md starts with content
  [32m✓[0m   frameworks/open-questions-catalog.md has skillsmith footer

## 5. Reference Files (references/)

  [32m✓[0m   references/prd-examples.md has skillsmith footer

## 6. Routing Consistency

  Found 6 @-references in routing:
    @frameworks/open-questions-catalog.md
    @frameworks/prd-quality-checklist.md
    @references/prd-examples.md
    @tasks/generate-prd.md
    @tasks/interview-questions.md
    @tasks/prd-template.md

  [32m✓[0m   routing @-ref exists: @frameworks/open-questions-catalog.md
  [32m✓[0m   routing @-ref exists: @frameworks/prd-quality-checklist.md
  [32m✓[0m   routing @-ref exists: @references/prd-examples.md
  [32m✓[0m   routing @-ref exists: @tasks/generate-prd.md
  [32m✓[0m   routing @-ref exists: @tasks/interview-questions.md
  [32m✓[0m   routing @-ref exists: @tasks/prd-template.md

## 7. Cross-file @-references

  [32m✓[0m   Cross-file @-references validated

===================================================
Summary
===================================================
Passed:  70
Failed:  0
Warning: 0
Total:   70

[32mRESULT: PASS (Compliant)[0m
Skill meets all structural and content requirements.
