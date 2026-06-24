---
name: help-users-ask-good-questions
description: Templates and guides to teach users how to file better bug reports and support requests
---

# Help Users Ask Good Questions

רוב הבאגים שמדווחים גרועים: "זה לא עובד". אתה מבזבז שעות רק בלהבין מה קרה. עזור למשתמשים לדווח טוב יותר.

## "How to File a Bug" — User-Facing Page

### Template

```markdown
# Found a bug? Help us fix it faster.

A good bug report saves us both time. Here's how:

## 1. What happened?

In one sentence: "When I click X, Y happens instead of Z."

**Bad**: "It's broken"
**Good**: "When I click 'Save' on a project, I get a 500 error"

## 2. What did you expect to happen?

"Save should save my changes and return to the project list."

## 3. How can we reproduce it?

1. Go to https://app.example.com/projects/abc
2. Click "Edit"
3. Change the name
4. Click "Save"
5. See error

## 4. Environment

- Browser: Chrome 120 on Mac
- Account email: you@example.com (we'll look up your account)
- Time of occurrence: 2026-06-24 14:32 UTC

## 5. Attachments

- Screenshot (Cmd+Shift+4 on Mac, Win+Shift+S on Windows)
- Browser console errors (F12 → Console tab → copy errors)

## Submit

[Button: Send bug report]

We respond within 24 hours.
```

## in-app error reporting

### "Report this error" button

```tsx
<button onClick={reportError}>
  Report this error
</button>

async function reportError() {
  const error = lastSeenError;
  await fetch('/api/error-reports', {
    method: 'POST',
    body: JSON.stringify({
      message: error.message,
      stack: error.stack,
      url: window.location.href,
      userAgent: navigator.userAgent,
      userId: currentUser.id,
      timestamp: new Date().toISOString(),
    }),
  });
  toast.success('Thanks — we got the report');
}
```

### Auto-capture via Sentry

```typescript
Sentry.init({
  dsn: process.env.SENTRY_DSN,
  beforeSend(event) {
    // attach user-friendly context
    event.user = { id: currentUser.id, email: currentUser.email };
    return event;
  },
});

// User clicks "Report" — capture explicit event
function reportButtonClick() {
  Sentry.captureMessage('User reported issue', 'info');
}
```

## Tier 2: Common Patterns + Pre-filled Reports

### "Login not working"

```markdown
## Login not working

Try these in order:

1. **Reset password**: https://app.example.com/forgot-password
2. **Clear cookies** for app.example.com
3. **Try incognito mode**
4. **Try a different browser**

Still not working? [Click here to send a report →]
```

### "Performance issues"

```markdown
## App is slow

Quick checks:

1. **Close other tabs** (each tab uses memory)
2. **Reload the page** (Ctrl+Shift+R for hard reload)
3. **Check your internet speed**: https://fast.com

If still slow after these, send a report with:
- Your browser + version
- What you were doing when it got slow
- Screenshot of browser task manager (Shift+Esc in Chrome)

[Send report →]
```

## Tier 3: Status Page + Proactive Updates

### statuspage.io template

```markdown
## Current status

✅ All systems operational
[Last updated: 2 minutes ago]

### Recent incidents
- **2026-06-20**: Email delivery delays (resolved in 23 min)
- **2026-06-15**: Login API outage (resolved in 1h 12min)

Subscribe to updates:
[Email] [SMS] [Webhook]
```

## Email Template for "I sent you a bug, no response"

```markdown
Subject: Re: [Original subject]

Hi [FirstName],

Thanks for reporting [issue]. I wanted to give you an update:

**What we found**: [brief technical summary]

**What we're doing**: [action plan]

**Expected fix**: [timeframe]

If you have more info to add, just reply.

— [Name]
```

## verification

- [ ] "How to file a bug" page נגיש מ-3 מקומות (footer, error page, settings)
- [ ] in-app "Report this error" עובד
- [ ] Sentry/PostHog מקבל את הדיווחים
- [ ] tier-2 self-service patterns קיימים
- [ ] status page נגיש ומתעדכן
- [ ] תגובה תוך 24 שעות (או תודה אוטומטית)

## מדדים

- Mean time to first response (MTTR)
- % bugs שמגיעים עם steps to reproduce
- % users שמוצאים תשובה ב-FAQ בלי לפתוח ticket
- NPS ב-support (אחרי ticket)

## אנטי-patterns

❌ "Describe the issue" (איך? עם מילים? ציור?)
❌ "What version are you using?" (אוטומטי, צריך להיות בדיווח)
❌ "Send logs" (איזה logs? איפה?)
❌ תגובה רק אחרי 5 ימי עבודה
❌ "We're looking into it" (איפה? מתי?)

_footer: customer-support-templates/references/help-users-ask-good-questions.md · customer-support-templates v0.1.0_
