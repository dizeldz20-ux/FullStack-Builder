---
name: analytics-monitoring
type: skill
version: 1.0.0
description: |
  הקמת ניטור אחרי פריסה: Sentry לשגיאות, PostHog/Plausible לאנליטיקה,
  BetterStack לזמינות, התראות עלויות ל-Cloudflare/OpenAI, ודאשבורד תפעולי.
  תופס בעיות בייצור לפני שמשתמשים מתלוננים.

  Post-deploy monitoring: Sentry errors, PostHog/Plausible analytics,
  BetterStack/UptimeRobot uptime, cost alerts (Cloudflare, OpenAI),
  and an ops dashboard. Catch production issues before users complain.
related_skills:
  - build-product
  - cloudflare-deploy
  - e2e-testing
  - supabase-auth-patterns
---

# analytics-monitoring / ניטור ואנליטיקה

## מטרה / Purpose

הסקיל מגדיר את שכבת הניטור של מוצר אחרי פריסה. בלי ניטור אין דרך לדעת
שמשהו נשבר עד שמשתמש פותח טיקט. הסקיל מכסה ארבע שכבות:

1. **Errors (Sentry)** — תפיסת exceptions בפרונטאנד, בקאנד, וב-Workers
2. **Analytics (PostHog / Plausible)** — מי משתמש, במה, ולמה נופלים
3. **Uptime (BetterStack / UptimeRobot)** — בדיקה שהאתר עונה מכל העולם
4. **Cost alerts (Cloudflare / OpenAI)** — הגנה מחשבונות שמתפוצצים

## מתי להשתמש / When to use

- אחרי שהמוצר עלה לפרודקשן וצריך לדעת שהוא באוויר
- כשמוסיפים endpoint חדש ורוצים לראות מי מגיע אליו
- כשמשלבים OpenAI / LLM וצריך להגביל חשבונות
- כשמעבירים Workers לפרודקשן ורוצה Sentry מובנה

## מבנה הסקיל / Structure

```
analytics-monitoring/
├── SKILL.md                                  # הקובץ הזה
├── tasks/
│   ├── setup-sentry.md                       # התקנת Sentry בכל שכבה
│   ├── setup-posthog.md                      # PostHog או Plausible
│   ├── setup-uptime-monitoring.md            # BetterStack + /health
│   └── setup-cost-alerts.md                  # התראות עלויות
├── frameworks/
│   ├── alerting-rules.md                     # מתי alert vs log
│   └── dashboard-patterns.md                 # מה להראות בדאשבורד
└── references/
    └── posthog-vs-plausible-vs-google-analytics.md  # השוואת כלים
```

## עקרונות מנחים / Guiding principles

### עלות מול ערך
Sentry, Plausible ו-BetterStack כולם מציעים tiers חינמיים שמספיקים
ל-MVP. אל תשלם על משהו שאפשר לקבל בחינם. PostHog נכנס רק כשצריך
session replay או funnels.

### כל התראה חייבת action
אם התראה לא מובילה לפעולה — היא רעש. כל rule שמוגדר כאן מקושר
לפעולה אוטומטית או לפעולה ידנית ברורה.

### PII מחוץ לכלי הניטור
אל תשלח אימייל, שם, או כתובת ל-Sentry/PostHog. רק IDs ומטא-דאטה.
Supabase Auth מספק user_id בלבד, וזה מה שעובר.

## סדר הקמה מומלץ / Setup order

```bash
# 1. uptime קודם — אם האתר למטה, כל השאר מיותר
# 2. Sentry שני — תופס שגיאות מהרגע הראשון
# 3. Analytics שלישי — כשיש כבר שגיאות, צריך להבין מי נתקל
# 4. Cost alerts אחרון — ברגע שיש שימוש אמיתי
```

## קישורים / Links

- Sentry: https://sentry.io
- PostHog: https://posthog.com
- Plausible: https://plausible.io
- BetterStack: https://betterstack.com/uptime
- UptimeRobot: https://uptimerobot.com
- Cloudflare Billing: dashboard → Billing → Alerts

## Quick reference — minimal stack ל-MVP

```bash
# 1. /health endpoint ב-Worker
# 2. BetterStack → monitor ל-/health מ-2 regions
# 3. Sentry → SDK בפרונט + Worker, sendDefaultPii: false
# 4. PostHog → init בפרונט, identify אחרי Supabase login
# 5. Cloudflare billing alerts → $50 / $200
# 6. OpenAI hard limit → $100/חודש + max_tokens בכל קריאה
```

עלות כוללת: $0 עד 1K משתמשים פעילים.

## מה לא בסקיל / Out of scope

- APM מלא (DataDog, NewRelic) — כבד ויקר ל-MVP
- Logging מבוסס ELK/OpenSearch — Cloudflare Logs מספיקים
- Synthetic monitoring (פעולות משתמש מלאות) — ב-MVP עדיף session replay
- Real User Monitoring נפרד — Sentry Performance + Web Vitals מספיקים
- Status page פנימי מותאם — BetterStack מספק בחינם

## Anti-patterns

❌ **להוסיף Sentry ואז לא להגדיר beforeSend** → רעש של ResizeObserver ו-chrome-extension errors
❌ **לשלוח PII ל-PostHog** → בעיית GDPR ואמון משתמשים
❌ **alert על כל error** → alert fatigue תוך יום
❌ **להתקין UptimeRobot ולחשוב שהאתר בריא** → הוא בודק רק HTTP 200, לא flow עסקי
❌ **לשכוח `max_tokens` ב-OpenAI** → חשבון של אלפי דולרים
❌ **להגדיר alert בלי runbook** → אף אחד לא יודע מה לעשות כשהוא מופעל
❌ **דאשבורד עם 50 widgets** → אף אחד לא מסתכל עליו, יותר גרוע מבלי

_footer: analytics-monitoring/SKILL.md · v0.1.0_
