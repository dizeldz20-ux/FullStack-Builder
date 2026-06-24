---
name: faq-generator
description: Turn recurring questions into a searchable FAQ page
---

# FAQ Generator

הפוך שאלות חוזרות לעמוד FAQ מסודר. חוסך זמן לך ולמשתמשים.

## ה-flow

### 1. אסוף שאלות

מאיפה:
- Support tickets / emails
- Live chat logs
- Discord/Slack channels
- GitHub issues (label: question)
- Twitter mentions
- Sales calls notes

### 2. מיין לפי תדירות

```
שאלה 1 (נשאלה 47 פעמים) → עמוד FAQ
שאלה 2 (נשאלה 23 פעמים) → עמוד FAQ
שאלה 3 (נשאלה 12 פעמים) → עמוד FAQ
שאלה 4 (נשאלה 5 פעמים) → inline doc
שאלה 5 (נשאלה 2 פעמים) → לא נכנסת, רק אם תחזור
```

### 3. כתוב תשובה

כל FAQ entry:

```markdown
## [Question in user's words]

[One-sentence direct answer]

[Step-by-step if needed]

[Link to deep-dive doc if needed]

[Last updated: YYYY-MM-DD]
```

## דוגמה

### ❌ FAQ גרוע

> **Q: How do I export?**
>
> A: Yes, you can export your data. To do this, go to Settings → Export → Select format → Click Export. If you have any issues, contact support.

### ✅ FAQ טוב

> ## How do I export my data?
>
> 1. Click your avatar (top-right) → **Settings**
> 2. Click **Export** in the left sidebar
> 3. Choose format: CSV / JSON / PDF
> 4. Click **Generate export** — file will be emailed within 5 minutes
>
> Exports include everything: projects, tasks, comments, attachments.
> Files larger than 100MB are split into multiple downloads.
>
> [Full export documentation →]
>
> Last updated: 2026-06-24

## categories

ארגן לפי topic, לא אלפבתי:

```
Getting Started
├── How do I sign up?
├── What's the free tier?
└── How do I invite my team?

Billing
├── How do I upgrade?
├── Can I get a refund?
└── What payment methods do you accept?

Features
├── How do I export?
├── Can I integrate with X?
└── Is there an API?

Troubleshooting
├── Login not working
├── Performance issues
└── Data not syncing
```

## features נוספות

### Search

```html
<input type="search" placeholder="Search FAQ..." />
```

### Voting

```
[👍 Helpful] [👎 Not helpful]
[View counter: 234 views]
```

→ מזהה entries שלא עוזרים וצריך לשפר.

### Related questions

```markdown
## Related
- How do I reset my password?
- How do I change my email?
- How do I delete my account?
```

## verification

- [ ] כל entry מתחיל ב-direct answer
- [ ] step-by-step עם מספרים
- [ ] "last updated" date
- [ ] search עובד
- [ ] "Was this helpful?" feedback
- [ ] קישור ל-deep-dive docs אם רלוונטי
- [ ] mobile-readable

## אנטי-patterns

❌ "Click here for more information" (איפה?)
❌ תשובה של 3 פסקאות (קצר!)
❌ "Contact support for help" (אם זה התשובה, למה ה-FAQ קיים?)
❌ FAQ שלא מתעדכן (למחוק entries ישנים)
❌ "Yes" / "No" בלי הסבר

_footer: customer-support-templates/tasks/faq-generator.md · customer-support-templates v0.1.0_
