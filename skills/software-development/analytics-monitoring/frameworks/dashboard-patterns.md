---
name: dashboard-patterns
type: framework
version: 0.1.0
description: |
  מה להראות בדאשבורד תפעולי. חמש שכבות: live status, errors,
  performance, business metrics, costs. עם דוגמאות קונקרטיות.
related_skills:
  - analytics-monitoring
---

# dashboard-patterns / מה להראות בדאשבורד

## עקרון מנחה

דאשבורד תפעולי הוא לא תצוגת נתונים — הוא **תמונת מצב שמאפשרת החלטה**.
כל מספר בדאשבורד צריך לענות על שאלה: "האם המוצר בריא עכשיו?"

## חמש שכבות

### שכבה 1 — Live status (top of dashboard)

**שאלה**: "המוצר באוויר עכשיו?"

ארבעה מסכים פשוטים, בגדלים שווים:

- 🟢 **Frontend** — `https://yourdomain.com` → 200?
- 🟢 **API** — `/health` → 200?
- 🟢 **Auth** — Supabase auth endpoint → 200?
- 🟢 **Database** — last query <1s?

מקור: BetterStack monitors + cron health checks.

**כלל**: מסך אדום = תקרא ל-incident. מסך ירוק = הכל בסדר. אין גווני ביניים.

### שכבה 2 — Errors (Sentry)

**שאלה**: "כמה שגיאות יש, ואילו?"

- **Error rate** — sparkline של אחוז הבקשות שנכשלו (24h)
- **Top 5 errors** — רשימה עם count + affected users
- **New errors today** — diff מאתמול
- **Errors by release** — אם הגרסה החדשה מוסיפה errors

דוגמת widget:
```
Error rate (24h)        0.42%   [sparkline]
Top errors:
  1. TypeError: undefined in cart          342 events   89 users
  2. 502 from upstream payment             127 events   42 users
  3. Timeout in /api/search                 98 events   31 users
```

### שכבה 3 — Performance

**שלאלה**: "האם המוצר מהיר מספיק?"

- **p50 / p95 / p99 latency** לכל endpoint עיקרי
- **Apdex score** — מדד חוויית משתמש סטנדרטי
- **Slowest pages** — top 5 דפים עם ה-LCP הגרוע ביותר
- **Web Vitals** — LCP, FID, CLS (מה-frontend)

מקור: Sentry Performance + Plausible/PostHog + Lighthouse CI.

**threshold**: אם p95 > 2s → אדום. p95 > 1s → צהוב. אחרת ירוק.

### שכבה 4 — Business metrics (PostHog)

**שאלה**: "האם משתמשים משיגים את מה שהמוצר אמור לספק?"

- **DAU / WAU / MAU** — מספר משתמשים פעילים
- **Activation rate** — אחוז משתמשים שעשו את הפעולה העיקרית
- **Retention** — אחוז שחזרו אחרי D1, D7, D30
- **Conversion funnel** — signup → first action → paying
- **Session replay samples** — 5-10 רנדומליים מהיום

השכבה הזו משתנה בין מוצרים. עיקרון: בחר 5-7 מספרים שמשקפים בריאות.

דוגמאות:
- אם המוצר הוא SaaS: trial → paid conversion
- אם המוצר הוא marketplace: listings / searches / matches
- אם המוצר הוא content: reads / scroll depth / shares

### שכבה 5 — Costs (cloud spend)

**שאלה**: "כמה אנחנו מוציאים, ולאן?"

טבלה פשוטה:

| שירות | היום | השבוע | החודש | תקציב |
|--------|------|-------|--------|--------|
| Cloudflare Workers | $2.30 | $14.50 | $48.20 | $200 |
| OpenAI | $1.80 | $11.40 | $34.10 | $100 |
| Supabase | $0.00 | $0.00 | $25.00 | $25 |
| Sentry | $0.00 | $0.00 | $0.00 | $26 |
| **סה"כ** | $4.10 | $25.90 | $107.30 | $351 |

**threshold**: אם חודשי > 80% מתקציב → צהוב. > 100% → אדום.

## כללי עיצוב

### Less is more
- מקסימום 20 widgets על המסך
- אם צריך יותר — יש dashboard נפרד ל-deep dive

### Numbers, not graphs (למעט trends)
- מספר ברור חשוב מגרף יפה
- sparkline ליד מספר = מגמה בלי לקחת מקום

### צבעים משמעותיים
- 🟢 ירוק = תקין
- 🟡 צהוב = שים לב
- 🔴 אדום = תגיב עכשיו
- ⚪ אפור = אין מידע / לא רלוונטי

לא יותר מדי צבעים — מסך מלא אדום לא אומר כלום.

## כלים מומלצים לבניית הדאשבורד

| צורך | כלי |
|------|------|
| דאשבורד תפעולי פנימי | Grafana + Cloudflare Analytics Engine |
| דאשבורד מהיר בלי infra | PostHog dashboards |
| status page ציבורי | BetterStack / Instatus |
| weekly business review | PostHog / Plausible |

## דוגמת stack מינימלי

למוצר ב-MVP:
1. **BetterStack** — status page + uptime alerts (חינם)
2. **Sentry** — errors + performance (חינם עד 5K events/חודש)
3. **PostHog** — events + funnels (חינם עד 1M events/חודש)
4. **Grafana Cloud** — dashboard אחד מאוחד (חינם tier)

עלות: $0 בחודשים הראשונים.

## checklist לפני שמוסיפים widget

- [ ] הוא עונה על שאלה ברורה
- [ ] מוגדר threshold (ירוק/צהוב/אדום)
- [ ] יש מקור נתון יציב (לא widget שמתנתק פעם בשבוע)
- [ ] מישהו יסתכל עליו (אחרת — להוריד)

_footer: analytics-monitoring/frameworks/dashboard-patterns.md · v0.1.0_
