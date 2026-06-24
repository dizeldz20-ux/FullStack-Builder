---
name: setup-cost-alerts
type: task
version: 0.1.0
description: |
  התראות עלויות על Cloudflare (Workers, R2, D1), OpenAI (tokens),
  ו-Supabase. מונע חשבונות שמתפוצצים בגלל bug או traffic חריג.
related_skills:
  - analytics-monitoring
  - cloudflare-deploy
---

# setup-cost-alerts / התראות עלויות

## מטרה

Production cost blow-up הוא failure mode אמיתי. דוגמאות שקרו:
- Worker בלולאה אינסופית → מיליוני בקשות בלילה אחד
- OpenAI קריאה ללא max_tokens → חשבונות של אלפי דולרים
- Supabase row בטבלת logs שגדל ללא גבול

הסקיל מגדיר alerts מוקדמים לפני שהחשבון מתפוצץ.

## Cloudflare — Workers + R2 + D1

### Billing alerts

1. Cloudflare Dashboard → Account → Billing → Billing Profile
2. Alerts → Create alert:
   - **Workers requests**: $X (למשל $50)
   - **Workers duration**: $X
   - **R2 storage**: $X
   - **R2 operations**: $X (Class A/B)
   - **D1 rows read**: $X
   - **D1 rows written**: $X

3. Channel: email + webhook ל-Slack

### Workers usage notifications

Settings → Notifications:
- Daily summary של Workers usage
- 80% של quota החינמי → warning
- 100% של quota → critical

### הגנה בקוד — hard limits

```ts
// ב-worker, לפני עבודה כבדה
const dailyBudget = parseInt(env.DAILY_BUDGET_CENTS || "500");
const spent = parseInt((await env.KV.get("spent:" + today)) || "0");

if (spent >= dailyBudget) {
  return new Response("Daily limit reached", { status: 429 });
}

// increment
await env.KV.put("spent:" + today, String(spent + estimatedCost), {
  expirationTtl: 86400 * 7, // נשמור שבוע לבדיקות
});
```

### Hard limits ב-wrangler.toml

```toml
[limits]
# הגבלת CPU time לכל request — מונע runaway loops
# (זה לא קיים ב-wrangler, אבל אפשר לבדוק ב-runtime)
```

## OpenAI — usage ו-tokens

### Hard limit ב-OpenAI dashboard

1. https://platform.openai.com/usage → Limits
2. Hard limit: $X (למשל $100/חודש)
3. Soft limit (email): 50% מ-hard limit

### הגנה בקוד — token budget

```ts
async function callOpenAI(prompt: string, env: Env) {
  // בדיקת budget יומי
  const spent = parseInt((await env.KV.get("openai:spent:" + today())) || "0");
  const dailyLimit = parseInt(env.OPENAI_DAILY_LIMIT_CENTS || "1000");

  if (spent >= dailyLimit) {
    throw new Error("OpenAI daily limit reached");
  }

  // תמיד max_tokens — לעולם לא בלי
  const completion = await openai.chat.completions.create({
    model: "gpt-4o-mini",
    messages: [{ role: "user", content: prompt }],
    max_tokens: 500, // ← חובה
  });

  const costCents = estimateCost(completion.usage);
  await env.KV.put(
    "openai:spent:" + today(),
    String(spent + costCents),
    { expirationTtl: 86400 * 7 }
  );

  return completion;
}

function estimateCost(usage: { prompt_tokens: number; completion_tokens: number }) {
  // gpt-4o-mini pricing דוגמה — לעדכן מחירים
  const inputCents = (usage.prompt_tokens / 1_000_000) * 15;
  const outputCents = (usage.completion_tokens / 1_000_000) * 60;
  return Math.ceil(inputCents + outputCents);
}
```

### ניטור ב-Sentry

```ts
// תיעוד של כל קריאה כיותר יקרה מהצפוי
Sentry.setContext("openai", {
  prompt_tokens: usage.prompt_tokens,
  completion_tokens: usage.completion_tokens,
  cost_cents: costCents,
});
```

## Supabase — DB size ו-bandwidth

### Alerts ב-Supabase dashboard

1. Project Settings → Billing → Usage
2. הגדר email alerts ב:
   - DB size > X GB
   - Bandwidth > Y GB
   - Monthly active users > Z (אם רלוונטי)

### Proactive — ניטור בקוד

```sql
-- בדיקת גודל טבלאות
SELECT
  schemaname || '.' || tablename AS table_name,
  pg_size_pretty(pg_total_relation_size(schemaname || '.' || tablename)) AS size,
  pg_total_relation_size(schemaname || '.' || tablename) AS bytes
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY bytes DESC
LIMIT 20;
```

### Data retention אוטומטי

```sql
-- מחיקת logs ישנים מעל 30 יום
DELETE FROM app_logs WHERE created_at < NOW() - INTERVAL '30 days';
```

או ב-Cron Worker:

```ts
export default {
  async scheduled(event, env) {
    const cutoff = new Date(Date.now() - 30 * 86400_000).toISOString();
    await env.DB.prepare("DELETE FROM app_logs WHERE created_at < ?")
      .bind(cutoff)
      .run();
  },
};
```

## סיכום thresholds מומלצים

| שירות | Alert ב- | Hard limit ב- |
|--------|----------|---------------|
| Cloudflare Workers | $50 | $200 |
| Cloudflare R2 storage | $20 | $50 |
| OpenAI | $50/day | $100/day |
| Supabase DB | 5 GB | 8 GB |
| Sentry events | 50K/day | 100K/day |

המספרים תלויים בגודל המוצר. העיקרון: alert ב-50% מ-hard limit.

## checklist

- [ ] Cloudflare billing alerts פעילים
- [ ] OpenAI hard limit מוגדר ב-dashboard
- [ ] dailyBudget בקוד לכל קריאה יקרה
- [ ] max_tokens תמיד מוגדר ב-OpenAI calls
- [ ] Supabase usage alerts פעילים
- [ ] retention policy אוטומטי ל-logs

_footer: analytics-monitoring/tasks/setup-cost-alerts.md · v0.1.0_
