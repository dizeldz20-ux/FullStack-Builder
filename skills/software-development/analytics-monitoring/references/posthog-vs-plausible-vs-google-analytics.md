---
name: posthog-vs-plausible-vs-google-analytics
type: reference
version: 0.1.0
description: |
  השוואה מעשית בין PostHog, Plausible ו-Google Analytics.
  מתי לבחור כל אחד, מחירים, יתרונות וחסרונות.
related_skills:
  - analytics-monitoring
---

# posthog-vs-plausible-vs-google-analytics / השוואת כלי אנליטיקה

## השוואה מהירה

| קריטריון | PostHog | Plausible | Google Analytics 4 |
|----------|---------|-----------|-------------------|
| עלות MVP | חינם עד 1M events | חינם עד 10K pageviews | חינם |
| מעבר tier בתשלום | $0.00031/event | $9/חודש ל-100K | חינם תמיד |
| Privacy-first | ✅ (cookieless option) | ✅ (cookieless) | ❌ (cookies + consent) |
| GDPR בלי cookie banner | ✅ | ✅ | ❌ |
| Session replay | ✅ (built-in) | ❌ | ❌ |
| Funnels | ✅ | ❌ | ✅ |
| Cohorts | ✅ | ❌ | ✅ |
| Self-host | ✅ | ✅ (community) | ❌ |
| עובד בלי cookie consent | ✅ | ✅ | ❌ |
| Real-time events | ✅ (sec latency) | ❌ (30min delay) | ✅ |
| Cloud / EU region | ✅ | ✅ | ❌ (US) |

## PostHog — למוצרים שצריכים product analytics

### מתי לבחור

- רוצה funnels, retention, cohorts
- צריך session replay (לראות מה משתמשים עושים)
- רוצה A/B testing built-in (feature flags)
- מוצר SaaS שצריך להבין activation

### יתרונות

- **All-in-one** — events, funnels, replay, feature flags, surveys
- **HogQL** — שפת SQL לכל ה-data
- **Open source** — self-host אפשרי
- **EU hosting** — `eu.i.posthog.com`
- **API מלא** — אפשר לבנות דאשבורדים מותאמים

### חסרונות

- מורכב יותר מ-Plausible
- Pricing מבוסס events — יכול להיות יקר בקנה מידה
- Overkill לאתר תדמית או בלוג

### Pricing

- **Free**: 1M events/חודש + 5K session recordings
- **Pay-as-you-go**: $0.00031/event אחרי
- **Team**: $450/חודש — features מתקדמים

## Plausible — לאתרים פשוטים ופרטיות

### מתי לבחור

- אתר תדמית / landing page / בלוג
- רוצה רק לדעת כמה אנשים נכנסו ומאיפה
- חשוב שאין cookie banner (EU customers)
- תקציב קטן וקבוע

### יתרונות

- **קל מאוד** — script אחד, אפס config
- **Privacy-first** — בלי cookies, בלי consent banner
- **Page weight** — script קטן (1KB)
- **Predictable pricing** — $9-29/חודש בלי הפתעות
- **Open source** — self-host אפשרי (community edition)

### חסרונות

- אין funnels, cohorts, session replay
- אין real-time (delay של 30 דקות)
- אין custom events מורכבים (רק name + props פשוטים)
- אין user-level analytics

### Pricing

- **Free**: 10K pageviews/חודש
- **Growth**: $9/חודש — 100K pageviews
- **Business**: $29/חודש — 500K pageviews
- **Enterprise**: מותאם

## Google Analytics 4 — כשאין ברירה

### מתי לבחור

- חייבים אינטגרציה עם Google Ads
- צריכים cross-device tracking מתקדם
- עובדים בארגון שכבר ב-GCP
- רוצים נתוני דמוגרפיה (גיל, מגדר, תחומי עניין)

### יתרונות

- חינם לחלוטין
- אקוסיסטם ענק — integrations עם הכל
- Machine learning built-in (anomaly detection)
- BigQuery export חינם

### חסרונות

- **GDPR nightmare** — חייב cookie consent banner
- **Data ב-Google servers** — ארה"ב, בעייתי ל-EU
- **מורכב** — UI עמוס, קשה ללמוד
- **לא שקוף** — אלגוריתם "smart" שמסתיר data
- **Sampling** — מדגם ב-data sets גדולים
- **Delayed** — events מגיעים תוך 24-48 שעות

### Pricing

- חינם (בתמורה ל-data שלך)

## decision tree

```
האם אתה צריך funnels / cohorts / replay?
├── כן → PostHog
└── לא
    ├── רוצה רק pageviews בלי cookie banner?
    │   ├── כן → Plausible
    │   └── לא
    │       ├── חייב Google Ads integration?
    │       │   ├── כן → GA4
    │       │   └── לא → PostHog (יש events מספיקים)
    │       └── EU customers עם רגולציה → Plausible
```

## setup cost (זמן הקמה)

| כלי | זמן ל-MVP | זמן ל-Production |
|-----|-----------|------------------|
| PostHog | 30 דקות | 4 שעות (כולל session replay + funnels) |
| Plausible | 5 דקות | 15 דקות (אם self-host אז +2 שעות) |
| Google Analytics 4 | 30 דקות | 8 שעות (מורכב, דורש consent mgmt) |

## recommendation לפי סוג מוצר

| סוג מוצר | המלצה | סיבה |
|----------|-------|------|
| SaaS B2B | PostHog | funnels + replay = הכרחי |
| Marketplace | PostHog | צריך cohorts ו-segmentation |
| Consumer app | PostHog | session replay לחוויית משתמש |
| Landing page | Plausible | פשטות + privacy |
| בלוג / docs | Plausible | זול ופשוט |
| E-commerce (ללא Google Ads) | Plausible + PostHog | pageviews פלוס funnel checkout |
| E-commerce (עם Google Ads) | GA4 + PostHog | Ads attribution פלוס product analytics |
| Internal tool | PostHog (self-host) | data לא יוצא החוצה |

## המלצה לרוב המקרים

לרוב המוצרים ב-MVP: **PostHog**. גם אם לא צריך הכל עכשיו,
הגמישות שווה את המורכבות הנוספת. כשהמוצר גדל ומתברר שצריך רק pageviews,
אפשר להוסיף Plausible בנוסף (script נפרד, $9/חודש).

GA4 — רק אם חייבים.

## checklist בחירה

- [ ] הוחלט כלי אחד ראשי (לא לערבב)
- [ ] מוגדר event taxonomy (אילו events נשלחים, באילו שמות)
- [ ] הוגדר retention (כמה זמן data נשמר)
- [ ] נכלל ב-privacy policy
- [ ] budget alerts מוגדרים (כדי לא להתפוצץ על events)

_footer: analytics-monitoring/references/posthog-vs-plausible-vs-google-analytics.md · v0.1.0_
