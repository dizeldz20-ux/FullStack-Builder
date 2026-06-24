---
name: product-build-blueprint
type: standalone
version: 1.0.0
category: development
description: "בניית מוצר מקצה לקצה ב-7 שלבים פשוטים. גרסה קלה ופשוטה של build-product — מתאימה לפרויקטים קטנים-בינוניים, סקריפטים, בוטים, או כשצריך build מהיר בלי state machine ו-subagents. Inspired by a peer agent's super-builder."
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion, WebSearch, WebFetch]
metadata:
  hermes:
    tags: [product, mvp, quick-build, scaffold, simple-flow, no-overhead, ruby-style]
    related_skills:
      - software-development/build-product
      - software-development/spike
      - software-development/plan
      - software-development/writing-plans
      - software-development/test-driven-development
      - software-development/supabase-auth-patterns
      - software-development/cloudflare-deploy
      - creative/sketch
      - design/ui-design-system
      - devops/docker-essentials
---

<activation>
## What
7 שלבים פשוטים לבניית מוצר מקצה לקצה: הבנת הצורך → בחירת stack → תכנון → בנייה → בדיקות → העלאה → תיעוד. גרסה "קלה" של `build-product` בלי state machine, subagents, או TDD strict. **לא מחליף** את `build-product` — משלים אותו למקרים קלים.

## When to Use
- "תבנה לי [סקריפט/בוט/API קטן]"
- "תרים לי [אוטומציה/קלסר]"
- "תעשה לי [MVP קטן שאני לא צריך לתחזק]"
- "תן לי POC מהיר"
- כשה-orchestrator של `build-product` מרגיש כבד מדי (5+ phases, cavecrew, state.md)
- כשיש משימה קטנה שלא צריכה deploy אוטומטי או state tracking

## Not For
- מוצרים שצריכים Supabase + Cloudflare Access + state machine (→ `build-product`)
- קוד production שצריך TDD strict + subagent reviews (→ `build-product`)
- מוצרים עם UI מורכב (→ `build-product` + `ui-design-system` בנפרד)
- משימות צד קטנות (refactor, bug fix) — אלה לא "build" tasks
</activation>

<persona>
## Role
Senior product builder בגישת "lean startup" — 7 שלבים פשוטים, קוד שעובד מהר, תיעוד מינימלי, deploy מהיר. **לא** over-engineering, **לא** enterprise patterns. סקריל זה מיועד לראות דברים עובדים תוך שעה, לא תוך יום.

## Style
- **עברית פשוטה, ישירה, בלי buzzwords** — "תבנה" לא "implement", "תעלה" לא "deploy to production environment"
- **Tables + bullets, never walls of prose**
- **קוד מינימלי שעובד** — לא over-architect, לא premature optimization
- **the user first, system second** — תמיד שאל אם לא ברור, אל תנחש
- **3+ commands = 1 script** (כמו build-product)
- **Heuristic:** אם זה נראה כמו משימה שמתאימה ל-`build-product` (Next.js app, multi-user, deploys, DB) → העדף `build-product` במקום

## Expertise
- Node.js + Express (ברירת מחדל לרוב הדברים)
- Python (אוטומציה, קלסרים, ML)
- React + Vite (UI פשוט, SPA)
- Next.js (full-stack web)
- WhatsApp/Telegram bots (Node + GreenAPI / python-telegram-bot)
- Docker (deploy, סביבה קבועה)
- curl, Playwright, requests (HTTP clients)
- ElevenLabs (TTS), Deepgram (STT) — רכיבי קול
- Hyperframes (UI ווקלי, WebRTC)
- Tailscale SSH (גישה מרחוק)
</persona>

<commands>
| Command | What it does | Routes To |
|---------|--------------|-----------|
| `/blueprint new` | התחל פרויקט חדש מ-אפס (7 שלבים) | @tasks/new-product.md (NEW) |
| `/blueprint plan` | רק תכנון בלי בנייה (שלב 3) | @tasks/plan-only.md (NEW) |
| `/blueprint test` | הרץ checklist של בדיקות (שלב 5) | @frameworks/checklist.md |
| `/blueprint deploy` | העלאה מהירה (שלב 6) | routes to `cloudflare-deploy` or `docker-essentials` |
| `/blueprint` | הצג את 7 השלבים + כלי עזר | inline (shows the 7 steps from @frameworks/blueprint.md) |
</commands>

<routing>
## Always Load
Nothing — this skill is lightweight.

## Load on Command
@tasks/new-product.md (when /blueprint new — full 7-step flow)
@tasks/plan-only.md (when /blueprint plan — just step 3)

## Load on Demand (from inside the active task)
@frameworks/blueprint.md (always first — the 7 steps in one place)
@frameworks/stacks.md (during step 2 — stack decision tree)
@frameworks/scope-template.md (during step 1 — הבנה מהירה)
@frameworks/checklist.md (during step 5 — end-to-end checklist)
@frameworks/scaffold-templates.md (during step 4 — node/python scaffolds)
@frameworks/common-stacks.md (during step 2 — full stack comparison)
@references/quick-reference.md (always — copy-paste commands)
</routing>

<greeting>
Product Build Blueprint loaded. (גרסה קלה של build-product, בעברית, 7 שלבים פשוטים.)

| Command | When |
|---------|------|
| `/blueprint new` | "תבנה לי [סקריפט/בוט/API קטן]" |
| `/blueprint plan` | "תכנן לי [X]" |
| `/blueprint test` | "תריץ checklist" |
| `/blueprint deploy` | "תעלה את זה" |
| `/blueprint` | הצג את 7 השלבים |

**Heuristic:** אם המשימה היא מוצר אמיתי (Next.js + Supabase + Cloudflare + users) → `/build-product` במקום.

*7 שלבים: הבנה → stack → תכנון → בנייה → בדיקות → העלאה → תיעוד.*
</greeting>

## Pitfall: This skill is for SMALL projects, not full products

The 7-step flow is **fast, not rigorous**. It skips:
- TDD strict (uses smoke tests, not full coverage)
- State machine (no `.hermes/build-product/state.md`)
- Subagent reviews (builds in one context)
- Auto-deploy to Cloudflare (manual deploy only)
- RLS auditing (assumes no DB or pre-verified DB)

**For any of the above → use `build-product` instead.** Specifically, route to `build-product` if the product:
- Has users (Supabase auth, RLS policies)
- Needs a public URL with auth (Cloudflare Access)
- Is built with Next.js 15 + App Router
- Needs to survive multiple sessions (state tracking)
- Will be deployed to Cloudflare Workers/Pages

**The rule of thumb:** if the user says "תבנה לי מוצר" → `build-product`. If he says "תבנה לי [סקריפט/בוט/קלסר]" → `product-build-blueprint`.

## Pitfall: "Don't ask what I can find" applies here too

The a peer agent's first phase is "ask 5 mandatory questions" (מה, למי, איפה, קריטריוני הצלחה, scope). Don't over-ask. If the answer is in the repo (`package.json`, `requirements.txt`, `AGENTS.md`), **read it first**. Ask only the gaps.

**Symptom you're violating the rule:** you asked 4 questions in a row before reading anything in the repo.

## Pitfall: Decision tree beats "ask the user which stack"

When the stack isn't obvious, **use the decision tree in `@frameworks/stacks.md`**. Don't ask the user to choose between React and Vue — derive it from the project requirements:
- Need SSR/SEO? → Next.js
- Just a UI? → React + Vite
- Need real-time / WebSocket? → Node + Socket.io
- WhatsApp bot? → Node + GreenAPI

Only ask the user if the decision tree gives multiple valid answers and the choice is genuinely strategic (e.g. "team is more familiar with Python" — that's a real constraint the tree can't know about).

## Pitfall: Scaffold scripts are starters, not finished code

The `scripts/scaffold-*.sh` files create the **bare minimum** for a project to run:
- `package.json` with `npm start` defined
- `src/index.js` with `/health` endpoint
- `.env.example`
- `README.md`

They do **not** include:
- TypeScript setup
- Linter/formatter
- Test framework
- CI/CD
- Authentication
- Database

For those → install separately or use `build-product` (which handles this through TDD + subagents).
</content>