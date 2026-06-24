---
name: onboarding-sequence
description: 5-email drip campaign to drive activation and retention in first 2 weeks
---

# Onboarding Sequence

5 מיילים ב-14 ימים מ-signup. מטרה: להפוך משתמש רשום למשתמש פעיל.

## ה-flow

```
Day 0: Welcome (ראה welcome-email-template.md)
Day 1: Quick win (הישג ראשון)
Day 3: Feature discovery (feature שלא הכירו)
Day 7: Success story (case study של משתמש דומה)
Day 14: Check-in (איך אתה מסתדר?)
```

## Email 1 — Quick Win (יום 1)

**מטרה**: לעזור למשתמש להשיג ערך ראשון תוך 5 דקות.

```
Subject: Your first [result] in 5 minutes

Hi [FirstName],

Yesterday you signed up for [Product]. Want to see it in action?

Here's the fastest path to your first [result]:

1. [Step 1 — 30 seconds]
2. [Step 2 — 1 minute]
3. [Step 3 — 2 minutes]

[Button: Try it now →]

Most users see their first [result] in under 5 minutes.

— [Name]
```

## Email 2 — Feature Discovery (יום 3)

**מטרה**: להראות feature שמשתמשים מצליחים בו הכי הרבה.

```
Subject: The [feature] you'll wish you knew about sooner

Hi [FirstName],

Quick tip: [feature] is the most popular thing in [Product].

Here's what it does: [one-line description].

Here's why users love it: [specific benefit with numbers].

[Button: Try [feature] →]

— [Name]
```

## Email 3 — Success Story (יום 7)

**מטרה**: social proof. משתמש דומה שהצליח.

```
Subject: How [Similar User] went from [before] to [after]

Hi [FirstName],

Quick story for you.

[User name] was in the same spot you were a week ago. They were
struggling with [same problem].

Three days ago, they [specific result — concrete numbers].

What changed? [One thing they did differently in Product].

[Button: See how they did it →]

— [Name]
```

## Email 4 — Check-in (יום 14)

**מטרה**: להבין מה עובד, מה לא. אסוף feedback.

```
Subject: How's it going, [FirstName]?

Hi [FirstName],

It's been two weeks since you signed up for [Product].

Quick question: how's it going? Just hit reply with one of these:

- "It's great" — and I'll send you advanced tips
- "I'm stuck on X" — and I'll help you unblock
- "Not for me" — and I'll cancel your account, no questions asked

Either way, I want to hear from you.

— [Name]
```

## Conditions

- עצור את הרצף אם המשתמש ביצע את הפעולה העיקרית
- אל תשלח מייל אם המשתמש ביקש "no emails"
- Track: open rate, click rate, conversion to activation

## verification

- [ ] כל מייל עם subject שלא נחתך ב-Gmail (≤50 תווים)
- [ ] preview text שמשלים את ה-subject
- [ ] CTA אחד בכל מייל
- [ ] אישי: שם, מה עשו עד עכשיו
- [ ] תזמון: לא יותר מדי מוקדם, לא נשכח

## אנטי-patterns

❌ "We have exciting news" (אין דבר מרגש יותר מלהגיד למה הם צריכים)
❌ 3 CTAs באותו מייל (החלטה = אי-פעולה)
❌ "Just checking in" (בלי ערך)
❌ מיילים ארוכים עם תמונות מצורפות

_footer: customer-support-templates/tasks/onboarding-sequence.md · customer-support-templates v0.1.0_
