---
name: alerting-rules
type: framework
version: 0.1.0
description: |
  מתי לשלוח alert (Slack/Email/PagerDuty) ומתי רק log.
  חמש רמות חומרה עם דוגמאות קונקרטיות מ-Sentry, BetterStack, OpenAI.
related_skills:
  - analytics-monitoring
---

# alerting-rules / מתי alert ומתי log

## הבעיה

alert fatigue הוא הסיכון הגדול ביותר לכל מערך ניטור.
אם מקבלים 50 התראות ביום, אף אחד לא קורא אף אחת.
אם אף התראה לא מגיעה — אותו דבר.

## העיקרון המנחה

**כל alert חייב action ברורה.**

- "יש שגיאה" → לא alert. תמיד יש שגיאות.
- "יש שגיאה שמשפיעה על >10% מהמשתמשים" → alert.
- "יש שגיאה אחרי deploy של היום" → alert.
- "יש שגיאה שלא ראינו אותה קודם" → log digest.

## חמש רמות חומרה

### L1 — Critical (page on-call)

**ערוץ**: PagerDuty / טלפון + Slack
**תגובה**: תוך 5 דקות
**סיבה**: משתמשים לא יכולים להשתמש במוצר

דוגמאות:
- `/health` מחזיר 503 במשך יותר מ-2 דקות
- error rate > 50% במשך 5 דקות
- OpenAI hard limit הגיע — שירות חסום לכולם
- DB connection pool מלא
- Auth provider למטה (Supabase / Clerk)

### L2 — High (Slack alert, no page)

**ערוץ**: Slack #incidents
**תגובה**: תוך 30 דקות בשעות עבודה
**סיבה**: חלק מהמשתמשים מושפעים, או שמשהו יקרה מתקרב לגבול

דוגמאות:
- error rate > 5% במשך 10 דקות
- /health מחזיר degraded (DB איטי, אבל לא למטה)
- OpenAI daily spend > 70% מ-limit
- Cloudflare Workers usage > 80% של תקציב יומי
- latency p95 > SLA (למשל >2s)

### L3 — Medium (Slack thread, no immediate action)

**ערוץ**: Slack thread תחת הודעה יומית
**תגובה**: תוך כמה שעות
**סיבה**: משהו לא תקין אבל לא דחוף

דוגמאות:
- error rate עלה מ-0.1% ל-1% בלי deploy
- new error type ראשון נראה (digest יומי)
- Disk usage > 70%
- DB query חדש איטי ב-p95

### L4 — Low (daily digest email)

**ערוץ**: email digest פעם ביום ב-09:00
**תגובה**: תוך יום עבודה
**סיבה**: מידע שכדאי לדעת אבל לא דחוף

דוגמאות:
- top 10 errors השבוע
- MAU / DAU trends
- Lighthouse score ירד מתחת ל-80
- רשימת endpoints איטיים

### L5 — Info (log only)

**ערוץ**: structured logs, queryable
**תגובה**: אין
**סיבה**: מידע שאפשר לחפש בו אחר כך

דוגמאות:
- כל API call בפרודקשן
- כל session start
- רוב ה-business events
- performance traces

## מתי alert ומתי log — מטריצת החלטה

```
              | משתמשים מושפעים | לא משפמעים
--------------+------------------+--------------
blocking      | L1 alert         | L2 alert
degraded      | L2 alert         | L3 digest
edge case     | L3 digest        | L5 log
```

## דוגמאות קונקרטיות מ-Sentry

### Alert rule: errors spike (L1)

```yaml
name: "Errors spike (critical)"
when: event.type == "error"
condition: |
  count(events) > 100 AND
  count(events, 5m) > count(events, 1h ago, 5m) * 3
actions:
  - slack: "#incidents"
  - pagerduty: "on-call-primary"
```

### Alert rule: new error first-seen (L3)

```yaml
name: "New error type"
when: event.type == "error" AND isFirstSeen == true
condition: count(events) > 5
actions:
  - email digest: 09:00 daily
```

### Alert rule: regression (L2)

```yaml
name: "Error regression"
when: |
  event.type == "error" AND
  event.release == latest AND
  isRegression == true
actions:
  - slack: "#incidents"
```

## עקרונות

1. **לא alert בלי runbook** — כל alert מקושר לדף שמסביר מה לעשות
2. **לא alert בלי owner** — צריך ברור מי אחראי
3. **Auto-resolve** — אם התנאי הסתיים, ה-alert נסגר אוטומטית
4. **Weekly review** — כל שבוע לעבור על ה-alerts ולראות מה היה noise
5. **אם alert חוזר 3 פעמים בשבוע בלי action** — להפוך ל-info או לתקן את הבעיה

## checklist לפני שמוסיפים alert חדש

- [ ] יש runbook מקושר
- [ ] יש owner ברור
- [ ] התנאי נבדק בעבר (לא alert על משהו שקרה פעם אחת)
- [ ] התנאי מוביל לפעולה (לא רק לידיעה)
- [ ] auto-resolve מוגדר
- [ ] נכלל ב-weekly review

_footer: analytics-monitoring/frameworks/alerting-rules.md · v0.1.0_
