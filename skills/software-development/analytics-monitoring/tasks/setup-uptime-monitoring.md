---
name: setup-uptime-monitoring
type: task
version: 0.1.0
description: |
  הקמת uptime monitoring עם BetterStack או UptimeRobot, ובניית
  endpoint /health שבודק DB + cache + תלות חיצוניות.
related_skills:
  - analytics-monitoring
  - cloudflare-deploy
---

# setup-uptime-monitoring / ניטור זמינות

## מטרה

לדעת תוך דקה אם האתר למטה. בלי זה, משתמשים מגלים לפני הצוות.
הסקיל מכסה שני חלקים:

1. `/health` endpoint שבודק את המערכת אמיתית (לא רק HTTP 200)
2. שירות חיצוני שבודק את ה-endpoint כל 30 שניות

## שלב 1 — בניית /health endpoint

### גרסה מינימלית (Cloudflare Worker)

```ts
// routes/health.ts
export async function handleHealth(env: Env): Promise<Response> {
  const checks = {
    status: "ok",
    timestamp: new Date().toISOString(),
    checks: {
      database: "unknown",
      cache: "unknown",
      upstream: "unknown",
    },
  };

  let httpStatus = 200;

  // DB check
  try {
    const { error } = await env.DB.prepare("SELECT 1").first();
    if (error) throw error;
    checks.checks.database = "ok";
  } catch (err) {
    checks.checks.database = "down";
    checks.status = "degraded";
    httpStatus = 503;
  }

  // KV check
  try {
    await env.CACHE.get("health:probe");
    checks.checks.cache = "ok";
  } catch {
    checks.checks.cache = "down";
  }

  return new Response(JSON.stringify(checks), {
    status: httpStatus,
    headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}
```

### גרסה מורחבת (Node / Hono)

```ts
import { db } from "@/lib/db";
import { redis } from "@/lib/redis";

export async function GET() {
  const [dbOk, redisOk] = await Promise.all([
    db.select().from(healthCheck).limit(1).then(() => true).catch(() => false),
    redis.ping().then(() => true).catch(() => false),
  ]);

  const allOk = dbOk && redisOk;
  return Response.json(
    { status: allOk ? "ok" : "degraded", db: dbOk, redis: redisOk, ts: Date.now() },
    { status: allOk ? 200 : 503 }
  );
}
```

### כללים

- **לא לבדוק authentication** — ה-monitoring service צריך גישה
- **לא לעשות work כבד** — הבדיקה רצה כל 30 שניות
- **להחזיר 503** כשמשהו לא תקין, לא 200 עם status: degraded בגוף
- **להחזיר JSON** — קל לדבג מהר

## שלב 2 — BetterStack Uptime (מומלץ)

למה BetterStack ולא UptimeRobot:
- בדיקות מ-multiple regions (אירופה, ארה"ב, אסיה)
- HTTPS monitor עם בדיקת תוכן
- Status page מובנה בחינם
- Webhook + Slack + Email native

### התקנה

1. https://betterstack.com/uptime → sign up
2. Monitors → Create monitor
3. הגדרות:
   - URL: `https://yourdomain.com/health`
   - Check interval: 30 seconds
   - Regions: US, EU (לפחות 2)
   - Expected status: 200
   - Request method: GET
   - Request timeout: 5 seconds

4. Alerting → Add channel:
   - Email
   - Slack webhook
   - PagerDuty (אם רלוונטי)

5. Heartbeat recovery:
   - Escalation policy: notify after 2 failed checks (1 minute)

### Status page (חינם)

BetterStack מאפשר status page ציבורי ב-`status.yourdomain.com`:

```toml
# Cloudflare DNS
status.yourdomain.com CNAME betterstack-status-pages.betteruptime.com
```

זה נותן למשתמשים לראות בעצמם אם השירות למטה בלי לפתוח טיקט.

## שלב 3 — UptimeRobot (אלטרנטיבה)

פשוט יותר, אבל רק US regions בחינם:

1. https://uptimerobot.com → sign up
2. Add New Monitor → HTTP(s)
3. URL: `https://yourdomain.com/health`
4. Monitoring Interval: 5 minutes (חינם) / 1 minute (pro)
5. Alert Contacts: email + Slack webhook

### מתי לבחור UptimeRobot

- תקציב $0 מוחלט
- רוב המשתמשים בארה"ב
- לא צריך status page

## שלב 4 — Smoke test נוסף (cron)

בנוסף ל-monitoring חיצוני, כדאי smoke test פנימי שרץ כל 5 דקות:

```ts
// wrangler.toml
[triggers]
crons = ["*/5 * * * *"]

// src/index.ts
export default {
  async scheduled(event, env, ctx) {
    const endpoints = ["/health", "/api/version"];
    for (const path of endpoints) {
      const res = await fetch(`https://yourdomain.com${path}`);
      if (!res.ok) {
        console.error(`smoke test failed: ${path} → ${res.status}`);
        // אפשר לשלוח ל-Sentry
      }
    }
  },
};
```

## שלב 5 — מה לנטר מעבר ל-/health

| מה | URL | סיבה |
|----|-----|------|
| Frontend | `/` | זמינות בסיסית |
| API | `/health` | תקינות תלויות |
| API deep | `/api/critical-flow` | smoke test של flow עסקי |
| Worker | `/health` | Workers uptime |
| Static | `https://cdn.yourdomain.com/asset.js` | CDN |

## checklist

- [ ] /health מחזיר 200 כשהכל תקין, 503 אחרת
- [ ] BetterStack monitor פעיל מ-2 regions
- [ ] Alert channel מוגדר (email + Slack)
- [ ] Status page ציבורי ב-`status.yourdomain.com`
- [ ] Smoke test cron פעיל
- [ ] Incident response procedure מתועד ב-runbook

_footer: analytics-monitoring/tasks/setup-uptime-monitoring.md · v0.1.0_
