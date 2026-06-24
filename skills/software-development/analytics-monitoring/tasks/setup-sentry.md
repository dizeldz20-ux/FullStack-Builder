---
name: setup-sentry
type: task
version: 0.1.0
description: |
  התקנת Sentry SDK בפרונטאנד, בקאנד (Node), וב-Cloudflare Workers.
  כולל טיפול ב-PII, source maps, ו-environment-aware DSN.
related_skills:
  - analytics-monitoring
  - cloudflare-deploy
---

# setup-sentry / התקנת Sentry

## מטרה

לתפוס כל uncaught exception, rejected promise, או שגיאת API בפרודקשן —
בצד הלקוח, בצד השרת, וב-Cloudflare Workers. בלי זה, בעיות עולות רק
מטיקטים של משתמשים.

## שלב 1 — פרויקט ב-Sentry.io

```bash
# צור ארגון ופרויקט ב-sentry.io
# Settings → Projects → Create Project → Next.js / Node / Browser
# העתק את ה-DSN — זה מה שצריך בכל מקום
```

מבנה DSN טיפוסי:
```
https://<key>@o<org>.ingest.sentry.io/<project>
```

## שלב 2 — Sentry בפרונטאנד (Next.js / React)

### התקנה

```bash
pnpm add @sentry/nextjs
npx @sentry/wizard@latest -i nextjs
```

הוויזארד יוצר אוטומטית:
- `sentry.client.config.ts` — config לדפדפן
- `sentry.server.config.ts` — config ל-Node server
- `sentry.edge.config.ts` — config ל-edge runtime
- patches ל-`next.config.js`

### קונפיג ידני (sentry.client.config.ts)

```ts
import * as Sentry from "@sentry/nextjs";

Sentry.init({
  dsn: process.env.NEXT_PUBLIC_SENTRY_DSN,
  environment: process.env.NODE_ENV, // production / staging / preview
  release: process.env.NEXT_PUBLIC_VERCEL_GIT_COMMIT_SHA, // optional

  // דגימה — 10% מה-events מספיקים ל-MVP, מוריד עלויות
  tracesSampleRate: 0.1,

  // אל תשלח PII
  sendDefaultPii: false,

  // סנן רעש מ-extensions
  beforeSend(event) {
    if (event.exception) {
      const err = event.exception.values?.[0];
      if (err?.value?.includes("chrome-extension://")) return null;
      if (err?.value?.includes("ResizeObserver loop")) return null;
    }
    return event;
  },
});
```

### משתני סביבה

```bash
# .env.local — לא לעלות לגיט!
NEXT_PUBLIC_SENTRY_DSN=https://...@....ingest.sentry.io/...
SENTRY_AUTH_TOKEN=sntrys_... # רק ל-CI להעלאת source maps
```

## שלב 3 — Sentry בקאנד (Node / Express / Hono)

```bash
pnpm add @sentry/node
```

```ts
import * as Sentry from "@sentry/node";

Sentry.init({
  dsn: process.env.SENTRY_DSN,
  environment: process.env.NODE_ENV,
  tracesSampleRate: 0.1,
  sendDefaultPii: false,
});

// חובה request handler לפני routes
app.use(Sentry.Handlers.requestHandler());
app.use(Sentry.Handlers.tracingHandler());

// routes...
app.get("/api/orders", handler);

// error handler אחרי routes, לפני error handler גנרי
app.use(Sentry.Handlers.errorHandler());
app.use(defaultErrorHandler);
```

### קונטקסט משתמש

```ts
Sentry.setUser({ id: user.id }); // בלבד, בלי email/name
Sentry.setTag("plan", user.plan);
Sentry.setContext("order", { id: order.id, total: order.total });
```

## שלב 4 — Sentry ב-Cloudflare Workers

```bash
pnpm add @sentry/cloudflare @sentry/core
```

```ts
import * as Sentry from "@sentry/cloudflare";

interface Env {
  SENTRY_DSN: string;
}

export default Sentry.withSentry(
  (env: Env) => ({
    dsn: env.SENTRY_DSN,
    tracesSampleRate: 0.1,
    sendDefaultPii: false,
  }),
  {
    async fetch(request, env, ctx) {
      try {
        return await handleRequest(request, env, ctx);
      } catch (err) {
        Sentry.captureException(err);
        throw err;
      }
    },
  } satisfies ExportedHandler<Env>
);
```

לעדכן `wrangler.toml`:
```toml
[vars]
SENTRY_DSN = "https://...@....ingest.sentry.io/..."

# סודות בפרודקשן
# wrangler secret put SENTRY_AUTH_TOKEN
```

## שלב 5 — Source maps

```bash
pnpm add -D @sentry/cli
```

```json
// package.json
{
  "scripts": {
    "build": "next build && sentry-cli releases new $COMMIT_SHA && sentry-cli sourcemaps upload --release $COMMIT_SHA .next"
  }
}
```

בלי source maps ה-stack traces מציגים שורות ממוזערות.

## שלב 6 — Alerts ב-Sentry

Settings → Alerts → Create Alert Rule:

1. **Errors spike**: when error count > 50 in 5 minutes → email + Slack
2. **New error type**: when first seen error → email digest פעם ביום
3. **Regression**: when fixed error חוזר → Slack מיידי

## checklist

- [ ] DSN מוגדר ב-3 סביבות (frontend/backend/worker)
- [ ] `sendDefaultPii: false` בכל מקום
- [ ] tracesSampleRate ≤ 0.2 בפרודקשן
- [ ] beforeSend מסנן רעש ידוע
- [ ] Source maps עולים ב-CI
- [ ] Alert rule ל-errors spike פעיל

_footer: analytics-monitoring/tasks/setup-sentry.md · v0.1.0_
