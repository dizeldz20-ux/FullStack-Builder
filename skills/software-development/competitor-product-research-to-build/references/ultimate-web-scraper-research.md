# Worked Example: Ultimate Web Scraper Research (June 2026)

## The user's ask (in Hebrew)

> אמי רוצה שתעשה מחקר מעמיק על האתר הזה Ultimate Web Scraper - Easy Data Scraper. זה תוסף לכרום שעושה web scraping. תנתח איך זה עובד בדיוק. תיכנס לכל איזור באתר. תפתח לך דפדפן ותתחיל לעבור טאב טאב איזור איזור. תחקור לא עומק איך זה עובד. יש שם הרבה מידע. תיכנס גם לבלוג עצמו. תחזור אליי עם ממצאים של איך אני בונה דבר כזה ככלי עצמאי עבורי.

**Translation**: User's mother asked for deep research on a Chrome web scraper extension. Analyze how it works. Browse every area of the site tab by tab. Read the blog for technical depth. Return with findings on how to build such a tool independently.

## Read map (10 pages)

| # | URL | What I extracted |
|---|---|---|
| 1 | `https://ultimatewebscraper.com/` | Pitch, 5 sub-tools grid, 80K+ users stat, use-case chips |
| 2 | `https://ultimatewebscraper.com/chrome-extension` | Main extension page with feature list |
| 3 | `https://ultimatewebscraper.com/pricing` | 4 tiers (Light $9, Starter $39, Pro $99, Max $199), credit system, local-vs-cloud split |
| 4 | `https://ultimatewebscraper.com/chrome-extension/list-extractor` | 3-step flow (Hover / Click / Export) |
| 5 | `https://ultimatewebscraper.com/chrome-extension/email-extractor` | Deep-scan + bulk URL flow |
| 6 | `https://ultimatewebscraper.com/blog` | 40+ posts, mostly "how to scrape X" tutorials |
| 7 | `https://ultimatewebscraper.com/blog/no-code-web-scraping` | Tutorial-style post, the actual UX flow described |
| 8 | `https://ultimatewebscraper.com/blog/web-scraping-tools` | 12-tool comparison, this product is #1 on its own list |
| 9 | `https://ultimatewebscraper.com/changelog` | Gold mine — every release note since 2024 |
| 10 | `https://ultimatewebscraper.com/blog/...` (2 deep tutorials) | Use-case validation |

## The 5 reads → 1 deliverable mapping

**Read 1 (Landing)**: Captured the pitch, the 5 sub-tool grid, and the "used by 80,000+ professionals" stat. The hero shows use-case chips (Search Results, Price Data, Real Estate, Reviews, etc.) which I used to scope the use cases section.

**Read 2 (Feature pages)**: The 5 sub-tool pages each have a 3-step "How it works" section. These became the **implementation map** — Hover → Click → Export is the UX, and behind it is content script → selector generation → IndexedDB → PapaParse export.

**Read 3 (Pricing)**: The pricing page revealed the **local-vs-cloud split** that's the most important product architecture decision. Local extractions are unlimited (the extension runs in your browser); cloud runs are metered with credits. This means the build can start as **local-only** and add cloud later.

**Read 4 (Blog + Changelog)**: This was the highest-density source. The changelog alone gave me 6 named techniques:
- v2.1 — "Dynamic extract" (works even if selectors change)
- v2.2 — "Load more" pagination support
- v2.3 — "Better pagination. Detects when page content has changed instead of relying on a fixed delay"
- v2.4 — "Updated references from visualwebscraper → Ultimate Web Scraper" (rebrand history!)
- v2.5 — "Autoscroll for Google Maps" (site-specific fix)
- v2.9 — "Credit system for usage tracking" (the monetization unit)
- v2.9 — "Improved OpenAI integration" (AI feature)

**Read 5 (Sub-tools)**: The list-extractor and email-extractor pages gave the UX flow. The blog tutorial posts (specifically "no-code-web-scraping") walked through the user journey step by step, which let me build the **4-week MVP** with the right tasks in the right order.

## The deliverable I sent (in Hebrew, ~120 lines)

```markdown
# 🔍 מחקר מעמיק: Ultimate Web Scraper

## מה זה בעצם
תוסף Chrome... 80,000+ משתמשים... נקרא בעבר PandaExtract.

## הארכיטקטורה — 5 כלים פנימיים
[table of 5 sub-tools with their central algorithms]

## איך זה עובד טכנית
1. Smart Group Detection (the core)
2. Pagination Strategies (4 types)
3. Data Pipeline (DOM → Smart Selector → Group Match → Live Preview → Export)
4. Cloud Side (PRO features)

## תמחור (להקשר)
[4 tiers, monthly/yearly, credit system]

---

# 🛠️ תוכנית בנייה — כלי עצמאי עבורך

## עקרונות מנחים (5)
1. Local-first
2. Point-and-click
3. Schema-agnostic
4. Export flexibility
5. Fast feedback

## Stack מומלץ
[3 paths: full extension, MVP script, Python CLI]

## MVP — 4 שבועות
[weekly breakdown with concrete tasks]

## Roadmap אחרי ה-MVP
[5 features cut from MVP]

## הבדלים אפשריים
[5 differentiators vs the original]

## שאלה לפני שמתחילים
[One explicit question: MVP in Python or jump to full extension?]
```

## What worked / what I'd refine

**Worked**:
- Parallel tabs reduced research time by ~3x
- `mcp_playwright_browser_evaluate` with `innerText.slice(0, 7000)` got me the long-form prose without having to scroll/screenshot
- The "changelog as algorithm source" pattern is reusable for any product
- Closing all tabs after research kept the browser clean

**Refine next time**:
- The pricing tier names (Light/Starter/Pro/Max) should be captured as a bullet list, not a table — Telegram renders the table awkwardly
- The MVP plan could have been a separate "5 principles" section *before* the stack recommendation, matching the `plan` skill's "the user kickoff overlay" structure more exactly
- Could have offered to verify the architecture by reading the source code on the Chrome Web Store listing (the extension is unpacked and reviewable) — but the user didn't ask for that, so it stayed in the "next step" question

## Time budget

- Navigation + snapshot of 5 pages: ~3 minutes
- Deep read of changelog + 2 blog posts: ~5 minutes
- Synthesis + deliverable: ~5 minutes
- **Total: ~13 minutes from "research this" to "here's your build plan"**

That's the right ballpark for this skill.
