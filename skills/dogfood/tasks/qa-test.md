<purpose>
Run systematic exploratory QA on a web application using the browser toolset — navigate, interact, capture evidence of issues, and produce a structured bug report with severity, category, and reproduction steps.
</purpose>

<user-story>
As a developer about to ship, I want the agent to dogfood my web app end-to-end and surface real bugs with evidence, so that I can fix them before users hit them.
</user-story>

<when-to-use>
- "Test my app at [URL]" or "dogfood [URL]"
- "Find bugs in [URL]"
- Pre-ship QA pass before `e2e-testing` runs
- A PR introduces a new user-facing flow and needs exploratory validation beyond the smoke test
- User explicitly invokes `/dogfood` or `/dogfood [URL]`
</when-to-use>

<context>
- Target URL
- Scope (specific features OR "full site")
- Output directory (default: `./dogfood-output/`)
- Any known constraints (auth credentials — reference file path, never paste literal)
</context>

<references>
@../references/issue-taxonomy.md (severity + category classification for findings)
@../templates/dogfood-report-template.md (the report format to produce)
@~/.config/hermes/skills/software-development/e2e-testing/SKILL.md (the deterministic smoke tests — dogfood is the complement, not the replacement)
</references>

<steps>

<step name="setup" priority="first">
Create the output directory:
- `{output_dir}/screenshots/` — evidence
- `{output_dir}/report.md` — final report (placeholder)
</step>

<step name="plan_scope">
Build a rough sitemap of pages and flows to test. Cover:
- Landing / home
- Navigation (header, footer, sidebar)
- Key user flows (sign up, login, search, checkout, etc.)
- Forms and interactive elements
- Edge cases (empty states, error pages, 404s)
</step>

<step name="explore_pages">
For each page in scope:
1. `browser_navigate(url=...)`
2. `browser_snapshot()` — DOM accessibility tree
3. `browser_console(clear=true)` — clear and inspect JS errors
4. `browser_vision(question="...", annotate=true)` — visual + element refs
5. Test interactive elements: click, type, press, scroll
6. After every interaction: re-check console, take a vision diff
</step>

<step name="collect_evidence">
For every issue found:
1. Take a screenshot with `browser_vision(question="...", annotate=false)` — save the `screenshot_path`
2. Record: URL, steps to reproduce, expected vs actual, console errors, screenshot path
3. Classify: severity (Critical/High/Medium/Low) + category (Functional/Visual/Accessibility/Console/UX/Content) using `references/issue-taxonomy.md`
</step>

<step name="categorize_dedup">
Review all collected issues. Merge duplicates. Sort by severity. Count by category.
</step>

<step name="report">
Generate the final report using `templates/dogfood-report-template.md`. Save to `{output_dir}/report.md`. Use `MEDIA:<screenshot_path>` to embed images inline.
</step>

</steps>

<output>
A report at `{output_dir}/report.md` with:
- Executive summary (total count, breakdown by severity, scope tested)
- Per-issue sections (severity, category, URL, repro steps, expected/actual, screenshots, console errors)
- Summary table
- Testing notes (what was/wasn't tested, blockers)

Plus a `screenshots/` directory with one PNG per finding.
</output>

<acceptance-criteria>
- [ ] Every issue has a screenshot, repro steps, expected vs actual, and a severity/category classification
- [ ] Report is saved to `{output_dir}/report.md` and follows the template
- [ ] Console errors are checked after every navigation AND every significant interaction
- [ ] Issues are sorted by severity, deduplicated
- [ ] Executive summary includes total count, breakdown by severity, scope tested
- [ ] Testing notes explicitly state what was NOT tested
- [ ] The deterministic smoke test (`e2e-testing`) is NOT replaced — dogfood complements it
</acceptance-criteria>
