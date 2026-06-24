<purpose>
התחל פרויקט חדש מ-אפס. 7 השלבים של product-build-blueprint: הבנה → stack → תכנון → בנייה → בדיקות → העלאה → תיעוד. גרסה קלה בלי state machine.
</purpose>

<user-story>
As the user who wants to build a quick script/bot/API without the heavy orchestration of build-product, I want a simple 7-step flow that gets me to working code in under an hour, so I can test the idea before committing to a full product.
</user-story>

<when-to-use>
- "תבנה לי [סקריפט/בוט/API קטן]"
- "תעשה לי [POC]"
- "תקים לי [one-off]"

NOT for: Next.js apps, products with users, anything that needs Supabase + Cloudflare + state tracking (use `build-product` instead).
</when-to-use>

<context>
@frameworks/blueprint.md (always — the 7 steps in one place)
@frameworks/user-defaults.md (the user's stack preferences)
</context>

<references>
@frameworks/blueprint.md (the 7 steps in one place)
@frameworks/stacks.md (during step 2 — stack decision tree)
@frameworks/scope-template.md (during step 1 — fill in the scope)
@frameworks/checklist.md (during step 5 — pre-deploy checklist)
@frameworks/scaffold-templates.md (during step 4 — scaffold examples)
@../supabase-auth-patterns/SKILL.md (during step 4 if the product needs auth — route to it instead)
@../cloudflare-deploy/SKILL.md (during step 6 if deploying to Cloudflare — route to it)
@references/quick-reference.md (always — copy-paste commands)
</references>

<steps>

<step name="understand_need" priority="first">
**5 שאלות חובה** (ראה @frameworks/scope-template.md):

1. מה בדיוק צריך להיבנות? (2-3 משפטים)
2. למי זה מיועד?
3. איפה זה ירוץ?
4. מה הקריטריונים להצלחה?
5. מה בהיקף ומה לא?

**לפני ששואלים** — חפש בריפו: `package.json`, `requirements.txt`, `AGENTS.md`, README. רק אם המידע חסר — שאל את המשתמש.

**Output:** טופס scope מלא ב-`@frameworks/scope-template.md`, מאושר על ידי המשתמש.
</step>

<step name="choose_stack" priority="first">
**עץ החלטות** — `@frameworks/stacks.md`:

```
האם צריך UI?
├── כן → React / Next.js / Vite
└── לא → Node.js / Python / Bash
```

**מתי לעבור ל-build-product במקום** (אל תמשיך ב-7 שלבים):
- יש Supabase auth + RLS → `build-product`
- צריך deploy ל-Cloudflare Workers/Pages → `build-product`
- Next.js 15 + App Router → `build-product`
- המוצר צריך לשרוד sessions → `build-product`
</step>

<step name="plan">
3 דברים לפני שמקלידים קוד:

1. **מבנה תיקיות** — תיעוד קצר (`src/`, `tests/`, `scripts/`, `README.md`)
2. **API/פורטים** — מה נחשף, מה פנימי
3. **נקודות כאב** — איפה דברים עלולים להישבר (DB connection, rate limits, race conditions)

**Output:** סקיצה קצרה ב-`@frameworks/blueprint.md` → "תבנית תכנון קצרה".
</step>

<step name="build">
**סדר נכון** (עקבי!):

1. סקפולדינג → `bash scripts/scaffold-node.sh <name>` (או python)
2. תסריט התחלה → שרת עולה, אפשר `npm start`
3. לוגיקה בסיסית → הכי פשוט שעובד
4. אינטגרציות → חיבור לכלים חיצוניים
5. שגיאות → try/catch עם הודעה ברורה
6. בדיקות → שרת עונה נכון למקרה אחד
7. ניקיון → למחוק debug, console.log

**כללי קוד:**
- פשוט קודם — אל תייעל לפני שזה עובד
- שם ברור — `handleIncomingMessage` עדיף על `fn1`
- קונפיג בקובץ — לא hardcoded
- לא לחזור על קוד — פונקציה אחת, לא שלוש
</step>

<step name="test">
**בדיקה מינימלית** (ראה `@frameworks/checklist.md`):

```bash
# 1. התקנה נקייה
cd project && npm install

# 2. התחלה
npm start

# 3. בדיקה
curl http://localhost:PORT/health
# חייב להחזיר 200 + JSON {status: "ok"}

# 4. המקרה המרכזי
# [ספציפי לפרויקט — מה שמוגדר ב-scope]
```

**רוץ את הchecklist המלא** לפני העלאה.
</step>

<step name="deploy">
**שאלות לפני העלאה:**

1. איפה זה ירוץ? (Cloudflare / Docker / שרת ישיר / Railway)
2. איך מתחילים? (`npm start` / `docker run`)
3. מי מפעיל? (the user / CI / cron)
4. צריך domain? (כן/לא)

**אם Cloudflare → רוט ל-`/cf-deploy`** (ה-skill המלא).

**אחרת** — בחר:
- Docker → `docker-essentials` skill
- שרת ישיר → `pm2` או `systemd`
- Railway / Fly.io → deploy via their CLI
</step>

<step name="document">
**README.md מינימלי:**

```
# [project-name]

תיאור קצר (2 שורות).

## Quick Start
[3-5 פקודות]

## API
[endpoints אם יש]

## Reinstall
[איך להתקין מחדש מ-0]
```

**לא לתעד:** היסטוריה, הערות מיותרות, דברים שבקוד.
</step>

<step name="final_verification">
- [ ] scope מאושר על ידי המשתמש
- [ ] stack נבחר על פי decision tree
- [ ] scaffold scripts הורצו בהצלחה
- [ ] `npm start` עובד, `/health` מחזיר 200
- [ ] המקרה המרכזי נבדק ועובד
- [ ] secrets לא בקוד (`.env` בלבד)
- [ ] README עם quick start
- [ ] `.env.example` קיים
- [ ] `.gitignore` כולל `.env` ו-`node_modules`
- [ ] deploy מתועד (איפה, איך)
</step>

</steps>

<output>
## Artifact
- פרויקט עובד ב-`<project-name>/`
- README + .env.example + .gitignore
- סקריפט הרצה (`npm start` / `python src/main.py`)
- אם deploy: URL זמני + הוראות גישה

## Format
- תיקיית פרויקט חדשה
- `package.json` / `requirements.txt`
- `src/index.js` / `src/main.py`
- `README.md`, `.env.example`, `.gitignore`

## Location
- Standard project directory (e.g. `~/projects/<name>/` or as the user specifies)
</output>

<acceptance-criteria>
- [ ] scope מאושר
- [ ] stack נבחר (Node.js / Python / React)
- [ ] סקריפטים רצים בהצלחה
- [ ] `npm start` / `python src/main.py` עובד
- [ ] `/health` מחזיר 200
- [ ] המקרה המרכזי נבדק ידנית
- [ ] README מסביר איך להתחיל
- [ ] `.env.example` קיים (בלי secrets)
- [ ] secrets לא בקוד
- [ ] deploy תועד
</acceptance-criteria>
