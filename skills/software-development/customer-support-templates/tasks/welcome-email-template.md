---
name: welcome-email-template
description: First email after signup — sets tone, shows value, drives activation
---

# Welcome Email Template

המייל הראשון אחרי הרשמה. הכי חשוב — מגדיר את הטון לכל מה שיבוא אחריו.

## עקרונות

- **שלח מייד** (תוך 5 דקות מ-signup, לא יום אחרי)
- **אישי** — שם + מה הם רשמו אליו
- **קצר** — 5 שורות, לא יותר
- **CTA ברור** — צעד אחד שהם יכולים לעשות עכשיו
- **לא features** — value

## English Template

```
Subject: Welcome to [Product], [FirstName] 👋

Hi [FirstName],

Thanks for signing up for [Product]. You're in.

Here's how to get the most out of it in the next 5 minutes:

→ [Single most important action — e.g., "Connect your first project"]

[Button: Get Started]

If you get stuck, just reply to this email. I read every reply.

— [Your name], founder of [Product]
```

## Hebrew Template

```
Subject: ברוכים הבאים ל-[מוצר], [שם] 👋

היי [שם],

תודה שנרשמת ל-[מוצר]. אתה בפנים.

הנה איך להפיק את המקסימום ב-5 הדקות הבאות:

→ [הפעולה הכי חשובה — למשל "חבר את הפרויקט הראשון שלך"]

[כפתור: בואו נתחיל]

אם נתקעת, פשוט תענה למייל הזה. אני קורא כל תגובה.

— [השם שלך], מייסד [מוצר]
```

## מה להתאים אישית

- `[FirstName]` / `[שם]` — מה-DB
- `[Single most important action]` — מה שמבדיל מוצר מוצלח ממוצר שלא משתמשים בו
- `[Button text]` — action verb, לא "לחץ כאן"
- Tone: רשמי vs חברי לפי הקהל

## verification

- [ ] נשלח תוך 5 דקות מ-signup
- [ ] יש שם פרטי
- [ ] CTA ברור אחד
- [ ] "I read every reply" — אם זה לא נכון, אל תכתוב
- [ ] עובד ב-HTML + plain text fallback
- [ ] נבדק ב-Gmail, Outlook, Apple Mail

## אנטי-patterns

❌ "Dear valued customer"
❌ "We are pleased to inform you"
❌ 10 features בולטים
❌ קובץ PDF מצורף "Getting Started Guide" (מי יפתח אותו?)
❌ "Click here to verify your email" (תעשה את זה ב-onboarding, לא ב-welcome)

_footer: customer-support-templates/tasks/welcome-email-template.md · customer-support-templates v0.1.0_
