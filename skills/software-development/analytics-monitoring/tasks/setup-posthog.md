---
name: setup-posthog
type: task
version: 0.1.0
description: |
  התקנת PostHog (או Plausible כחלופה קלה) למעקב אירועים, session replay,
  ופאנל משתמשים. בחירה בין כלים מתועדת ב-references/.
related_skills:
  - analytics-monitoring
  - supabase-auth-patterns
---

# setup-posthog / התקנת PostHog (או Plausible)

## מטרה

להבין מי משתמש במוצר, באיזה flow הם נופלים, ומה מקדם conversion.
בניגוד ל-Sentry שתופס שגיאות, PostHog/Plausible מספקים תמונה התנהגותית.

## החלטה: PostHog או Plausible

| צורך | כלי |
|------|------|
| event tracking, funnels, cohorts | PostHog |
| session replay | PostHog |
| רק pageviews ו-traffic | Plausible |
| רוצה self-hosted / EU | Plausible |
| תקציב $0 בלי compromise | Plausible |

פרטים מלאים ב-`references/posthog-vs-plausible-vs-google-analytics.md`.

## אופציה A — PostHog בפרונטאנד

### התקנה

```bash
pnpm add posthog-js
```

### קונפיג

```ts
// lib/posthog.ts
import posthog from "posthog-js";

export function initPostHog() {
  if (typeof window === "undefined") return;
  if (posthog.__loaded) return;

  posthog.init(process.env.NEXT_PUBLIC_POSTHOG_KEY!, {
    api_host: process.env.NEXT_PUBLIC_POSTHOG_HOST || "https://us.i.posthog.com",
    person_profiles: "identified_only", // רק אחרי login
    capture_pageview: false, // נעשה ידנית ב-app router
    capture_pageleave: true,
    autocapture: false, // explicit events בלבד — מדויק יותר
  });
}
```

```tsx
// app/providers.tsx
"use client";
import { useEffect } from "react";
import { initPostHog } from "@/lib/posthog";

export function PostHogProvider({ children }: { children: React.ReactNode }) {
  useEffect(() => { initPostHog(); }, []);
  return <>{children}</>;
}
```

### שליחת events

```ts
import posthog from "posthog-js";

// pageview ידני ב-app router
posthog.capture("$pageview", { $current_url: window.location.href });

// events עסקיים
posthog.capture("order_created", { order_id: id, total_cents });
posthog.capture("checkout_started", { cart_size });
posthog.capture("feature_used", { feature: "export_csv" });
```

### זיהוי משתמש אחרי login

```ts
import posthog from "posthog-js";

// אחרי Supabase sign-in
posthog.identify(user.id, {
  plan: user.plan,
  signup_date: user.createdAt,
});

// ב-logout
posthog.reset();
```

### Server-side (Cloudflare Workers)

```bash
pnpm add posthog-node
```

```ts
import { PostHog } from "posthog-node";

const ph = new PostHog(env.POSTHOG_API_KEY, {
  host: "https://us.i.posthog.com",
});

await ph.capture({
  distinctId: user.id,
  event: "api_call",
  properties: { endpoint: "/api/orders", latency_ms },
});

await ph.shutdown(); // flush לפני סגירה
```

## אופציה B — Plausible (קל ופשוט)

### התקנה ב-Next.js

```tsx
// app/layout.tsx
import Script from "next/script";

export default function RootLayout({ children }) {
  return (
    <html>
      <head>
        <Script
          defer
          data-domain="yourdomain.com"
          src="https://plausible.io/js/script.js"
          strategy="afterInteractive"
        />
      </head>
      <body>{children}</body>
    </html>
  );
}
```

### Custom events ב-Plausible

```ts
window.plausible?.("signup_completed", { props: { plan: "pro" } });
window.plausible?.("export_csv");
```

### עם Cloudflare / reverse proxy

אם רוצים להסתיר את ה-domain מ-Plausible (מניעת adblockers):

```ts
// /app/api/event/route.ts
export async function POST(req: Request) {
  const body = await req.json();
  const res = await fetch("https://plausible.io/api/event", {
    method: "POST",
    headers: { "Content-Type": "application/json", "User-Agent": req.headers.get("user-agent")! },
    body: JSON.stringify({ ...body, domain: "yourdomain.com" }),
  });
  return new Response(null, { status: res.status });
}
```

ב-script-tag:
```tsx
<Script
  src="/api/event/script.js"
  data-api="/api/event"
/>
```

## משתני סביבה

```bash
# PostHog
NEXT_PUBLIC_POSTHOG_KEY=phc_...
NEXT_PUBLIC_POSTHOG_HOST=https://us.i.posthog.com
POSTHOG_API_KEY=phc_... # server-side

# Plausible
# רק domain + script src, אין key ציבורי
```

## checklist

- [ ] posthog.init רק בצד לקוח (typeof window check)
- [ ] identify אחרי login, reset ב-logout
- [ ] events מתועדים ב-PostHog/Hog UI תוך דקה
- [ ] person_profiles: identified_only
- [ ] PII (email/name) לא נשלח ב-event properties

_footer: analytics-monitoring/tasks/setup-posthog.md · v0.1.0_
