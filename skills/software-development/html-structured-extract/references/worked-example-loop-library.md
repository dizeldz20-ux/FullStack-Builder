# Worked example — Forward Future Loop Library (45 rows, 2026-06-21)

## The task

Daniel asked: "תסתכל באתר הזה https://signals.forwardfuture.ai/loop-library/, יש שמה כל מיני פרומפטים ללואות, תעבור על זה ותבדוק כל מיני פרומפטים ללולאות שיכולים להיות רלוונטים ושימושיים עבורינו".

Translation: "Look at this URL. It has a bunch of prompts for loops. Go through them and check which loop prompts could be relevant and useful for us."

## What the page actually was

- A `<table class="loop-library">` with 45 `<tr class="loop-row" data-category="engineering|evaluation|design|operations|content">` rows.
- Each row: `<span class="loop-category">` + `<span class="loop-attribution">` + `<h3><a class="loop-title-link">` + `<p class="loop-summary">` + `<p data-prompt>` + a `<button class="copy-button">`.
- The full prompts (multi-sentence instructions for an AI agent to follow) live in the `<p data-prompt>` blocks — the public-facing "summary" is just one line.

## What worked

### 1. browser_navigate (smoke check)

`browser_navigate('https://signals.forwardfuture.ai/loop-library/')` returned the page title, a navigation snapshot, and the first ~10 rows with interactive elements. Confirmed the page structure and that it was server-rendered (no JS-only gating).

### 2. browser_snapshot (FAILED — capped at 200 elements)

`browser_snapshot()` returned rows 1–6 with full `ref` IDs (`@e34`–`@e45`) and a footer saying "[... 276 more lines truncated, use browser_snapshot for full content]". `browser_snapshot full=true` came back at 8000+ chars and got summarized by the LLM layer — the summary dropped the prompt bodies.

**Lesson encoded**: never trust `browser_snapshot` to give you the full table on a dense page. The 200-element cap is hit by row 8 on this kind of layout.

### 3. curl + Python regex (WORKED — all 45 rows in ~3 seconds)

```bash
curl -sL -A 'Mozilla/5.0' 'https://signals.forwardfuture.ai/loop-library/' -o /tmp/loop_library.html
```

Then iterated on the parsing script twice:

**First regex (BROKEN)** — used `<a class="loop-title-link"[^>]*>([\s\S]*?)</a>` to extract the title. Worked on rows where the `<a>` tag was single-line, but returned empty strings for rows where the page rendered the tag across multiple lines:

```html
<a
  class="loop-title-link"
  href="./loops/architecture-satisfaction-loop/"
>
  The architecture satisfaction loop
</a>
```

**Second regex (FIXED)** — anchored on the class as a substring rather than a full match:

```python
re.search(r'<a\b[^>]*class="[^"]*title[^"]*"[^>]*>([\s\S]*?)</a>', r)
```

`\b` handles the multi-attribute gap between `<a` and `class`, and `[^"]*title[^"]*` matches any class containing "title" (loop-title-link, item-title, etc.) regardless of other class tokens. All 45 titles parsed correctly.

### 4. data-category as the canonical category source

Initial attempt matched `>(FEATURED|ENGINEERING|EVALUATION|...)<` text inside the row — got `?` for all 45 rows because that pattern didn't exist in the rendered HTML. The category badge is inside `<span class="loop-category">Engineering</span>` (text) AND on the row as `data-category="engineering"` (attribute). Switched to the data attribute:

```python
cat = (re.search(r'data-category="([^"]+)"', r) or [None, "?"])[1]
```

All 45 categories parsed correctly: 23 engineering, 10 evaluation, 6 design, 4 operations, 2 content.

## The deliverable

A Hebrew chat reply with:
- The distribution by category (45 rows, 23/10/6/4/2)
- Tier 1 / Tier 2 / Tier 3 ranking based on which loops aligned with the developer's existing projects (a Hebrew voice agent, a desktop dictation product, a multi-agent orchestration framework, a multi-agent Kanban board)
- Concrete next-action options (install the Loop Library skill, save Tier 1 to Vault, pull full prompts for specific loops)

Total chat message: ~120 lines. Time from URL drop to deliverable: ~5 minutes.

## What would have gone wrong without this skill

- **Jina Reader path**: would have returned the table as pipe-table Markdown, losing the per-row category badges and the full prompt bodies. The Tier 1/2/3 ranking would have had to skip "look at the actual prompt and see if it fits our workflow" — the whole point of the task.
- **browser_snapshot full=true path**: would have returned 8000+ chars that get LLM-summarized before they hit context. Summaries drop field-level structure.
- **BeautifulSoup path**: would have worked but is slower to write and overkill for a 45-row table with clean `data-*` anchors.

## Reusable takeaways

1. **Anchor on data-* attributes** for category / type / status fields. They're stable, lowercase, present on every row regardless of CSS, and don't depend on text-content order.
2. **Strip `<script>` and `<style>` first** — analytics payloads and JSON-LD inside scripts will match naive row regexes and double-count.
3. **Allow multi-line attributes in title/link extraction** — use `<TAG\b[^>]*class="[^"]*NEEDLE[^"]*"[^>]*>([\s\S]*?)</TAG>`. Tested pattern.
4. **Print `Counter(field)` after parsing** — gives an immediate sanity check that your extraction worked (45 distinct titles, 5 category values with sensible distribution).
5. **The 200-element `browser_snapshot` cap is a real ceiling**, not a soft suggestion. Plan for it.
