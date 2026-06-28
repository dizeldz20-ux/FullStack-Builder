---
name: html-structured-extract
version: 1.0.0
description: "Extract every row from a known-shape HTML page (table, repeating card grid, RSS-rendered-as-HTML) using curl + Python regex. Use when the user wants to read every item from a server-rendered structured page and browser_snapshot truncates at ~200 elements or Jina Reader collapses the table to prose. Triggers: 'extract every row from this page', 'scrape the table at URL', 'give me all the items on this list page', 'pull all rows from this directory/listing', 'this page has 45 items, get them all'. NOT for JS-rendered SPAs (use playwright-scraper-skill or opencli-rs), login-walled pages, or prose reads of single articles (use Jina via agent-reach/references/web.md)."
author: Hermes Agent (Daniel workflow)
license: MIT
metadata:
  hermes:
    tags: [scraper, html, regex, table, structured-data, extraction, no-js, curl]
    related_skills: [agent-reach, playwright-scraper-skill, opencli-rs, dogfood]
    note: "Captures the recipe + pitfalls learned on 2026-06-21 when extracting 45 rows from signals.forwardfuture.ai/loop-library/ — see references/worked-example-loop-library.md."
---

# HTML Structured Extract — curl + regex for known-shape pages

When the page is a **server-rendered HTML table or repeating list with a stable, repeating row shape** — and you want **every row**, not a prose summary — `curl` + a small Python regex script is faster, more complete, and more reliable than either a browser snapshot or Jina Reader.

## When to use this

- The page is a publicly fetchable server-rendered HTML table / list / card grid with a repeating structure (rows, cards, articles, prompts, products, etc.).
- You want **every row**, not a summary.
- `browser_snapshot` would truncate (it caps at ~200 interactive elements — 8–10 dense rows already hits it).
- `Jina Reader` would collapse the table to prose and lose the column alignment.
- The page is not behind a login wall, and no JS execution is needed to render the data you want.

## When NOT to use this

- The data is rendered by client-side JS (React/Vue SPA fetching JSON after load). → `playwright-scraper-skill` or `opencli-rs`, or hit the JSON API directly if there is one.
- The data lives behind a login or anti-bot gate. → `playwright-scraper-skill` (with anti-bot posture) or `opencli-rs` (logged-in Chrome session).
- The deliverable is a prose read of one article or one landing page. → Jina Reader via `agent-reach/references/web.md`.
- The user wants exploratory QA with screenshots, console-error capture, or interaction (click, fill, scroll). → `dogfood`.
- The user wants to **build** something like the source site, not extract data from it. → `competitor-product-research-to-build`.

## The recipe (5 steps, ~30 lines of Python)

```bash
# 1. Fetch
curl -sL -A 'Mozilla/5.0' 'URL' -o /tmp/page.html

# 2. Strip blocks that would match your row regex falsely
python3 - <<'PY'
import re, html, json
src = open("/tmp/page.html", encoding="utf-8").read()
src = re.sub(r"<script[\s\S]*?</script>", "", src)
src = re.sub(r"<style[\s\S]*?</style>",  "", src)

# 3. Match the repeating container. Prefer a stable data-* attribute on the row.
row_re = re.compile(r'<tr\b[^>]*class="[^"]*YOUR-ROW-CLASS[^"]*"[\s\S]*?</tr>', flags=re.I)
rows = row_re.findall(src)

def text(s): return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", s))).strip()

# 4. Extract the fields you need. Allow attributes to span multiple lines.
records = []
for r in rows:
    cat     = (re.search(r'data-category="([^"]+)"', r) or [None,"?"])[1]
    title   = text((re.search(r'<a\b[^>]*class="[^"]*title[^"]*"[^>]*>([\s\S]*?)</a>', r) or [None,""])[1])
    summary = text((re.search(r'<p class="[^"]*summary[^"]*">([\s\S]*?)</p>', r) or [None,""])[1])
    records.append({"category": cat, "title": title, "summary": summary})

with open("/tmp/page.json", "w", encoding="utf-8") as f:
    json.dump(records, f, ensure_ascii=False, indent=2)

from collections import Counter
print("counts:", Counter(x["category"] for x in records))
print("total rows parsed:", len(records))
PY

# 5. Sanity-check: print titles + a one-line summary each
python3 -c "
import json
for L in json.load(open('/tmp/page.json')):
    print(f\"  [{L['category']:13}] {L['title']}\")
    print(f'     → {L[\"summary\"]}')
"
```

**Why Python regex instead of `html.parser` or `BeautifulSoup`?** Because the row pattern is usually simple and `<tr class="X" data-...>...</tr>` regex matches the right scope without DOM-tree traversal. When the row pattern is genuinely nested (cards inside cards inside cards), switch to BeautifulSoup — but try regex first; it's faster to write and 90% of "list pages" match this shape.

## Pitfalls

### ❌ Trust the first regex you write on the first row

Always print the **first parsed row's fields** before declaring victory. The shape that breaks most often is **`<a>` tags with attributes that span multiple lines**:

```html
<a
  class="loop-title-link"
  href="./loops/foo/"
>
  The title text
</a>
```

A naive `<a class="loop-title-link"[^>]*>(.*?)</a>` regex misses this because the **opening** `<a` and the `class="..."` attribute are on different lines — `[^>]*` does cross newlines, but the `class="loop-title-link"` token is no longer immediately after `<a`. **Fix:** use a class **substring** match with `\b` to anchor the `<a` boundary, and `[\s\S]*?` for the content capture:

```python
re.search(r'<a\b[^>]*class="[^"]*title[^"]*"[^>]*>([\s\S]*?)</a>', r)
```

`\b` (word boundary) handles the case where the `<a` tag has extra attributes between `<a` and `class`; `[^"]*title[^"]*` matches any class containing "title" (`loop-title-link`, `item-title`, etc.). Tested pattern.

### ❌ Rely on `browser_snapshot` for "just give me all the rows"

`browser_snapshot` truncates at ~200 interactive elements. A page with 45 rows where each row has 4–6 interactive elements (link, button, expand toggle) hits the cap around row 8. You get the first ~8 rows and then a "more lines truncated, use browser_snapshot full=true" footer. `browser_snapshot full=true` returns more, but at 8000+ chars the response gets summarized. Switch to `curl` + regex instead.

### ❌ Use `Jina Reader` for table-shaped data

`r.jina.ai/URL` returns Markdown. Tables become pipe-tables with collapsed whitespace; multi-row cells, badges, and category labels get inlined or dropped. For "give me the rows + the category + the author + the prompt body", the regex recipe above preserves all of it. **Use Jina for prose, not for tabular data.**

### ❌ Match on `>CATEGORY<` text content inside the row

The category badge is usually inside a `<span class="loop-category">Engineering</span>` and the row also has a `data-category="engineering"` attribute on the `<tr>`. **Always prefer the `data-*` attribute** — it's stable, lowercase, and present on every row regardless of CSS rendering. Text content is for humans; data attributes are for parsers.

### ❌ Forget to strip `<script>` and `<style>` blocks first

`loop-row` text inside a `<script>` block (analytics, JSON-LD, embedded React payload) will match your row regex and double-count or break the schema. Strip both blocks before counting.

### ❌ Save the parsed JSON to `/tmp/` and forget to copy

`/tmp/` is fine for the working file. **But if the parsed rows feed into a skill update, a Vault note, or a follow-up build plan**, copy to `~/.hermes/memories/...` or `/root/<project>/` **before** you move on. Same caveat as any `/tmp/` write.

### ❌ Ship the script without printing one sample row

A regex that returns 45 rows where every `title` is `""` is a silent failure. Always print the first row's fields (and a `from collections import Counter; Counter(categories)` line) to catch the empty-title failure mode before declaring the extraction done.

## Quick decision tree

```
Need every row of a structured HTML page?
├─ Yes, public, server-rendered ─────► this recipe (curl + regex)
├─ Yes, behind login / JS-rendered ───► playwright-scraper-skill / opencli-rs
├─ Yes, but I only need ~10 rows ─────► browser_snapshot (accept truncation)
├─ Yes, but I want a Markdown prose read of one row ─► Jina Reader (agent-reach/references/web.md)
└─ No, I want to interact with the page (QA / click / fill) ─► dogfood (with browser tools)
```

## Worked example

On 2026-06-21 I needed to review 45 "AI agent loop" prompts on `https://signals.forwardfuture.ai/loop-library/`. The page had a `<table class="...">` with one `<tr class="loop-row" data-category="engineering|evaluation|design|operations|content">` per loop. `browser_snapshot` returned the first ~8 rows + a truncation footer. `Jina Reader` collapsed the table to prose, losing the per-loop category badge and the full prompt body.

The recipe above extracted all 45 rows with `{category, author, title, summary, prompt}` fields in ~3 seconds. The resulting JSON fed directly into a Tier 1/2/3 ranking without any manual re-typing. Full transcript in `references/worked-example-loop-library.md`.

## Related skills

- `agent-reach` + `agent-reach/references/web.md` — for prose reads of single pages (Jina Reader), not for tabular extraction.
- `playwright-scraper-skill` — when you need to execute JS, defeat anti-bot, or operate on a logged-in session.
- `opencli-rs` — when the site has an opencli-rs-supported backend (X, Reddit, HN, GitHub, etc.).
- `dogfood` — for exploratory QA of web apps with screenshots, console capture, and interaction.
- `competitor-product-research-to-build` — when the deliverable after extraction is a build plan, not a data table.
