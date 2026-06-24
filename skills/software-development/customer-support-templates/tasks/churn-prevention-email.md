---
name: churn-prevention-email
description: Email sent when user signals intent to cancel — last chance to save them
---

# Churn Prevention Email

נשלח כשמשתמש לוחץ "Cancel" או שולח "I want to cancel". ההזדמנות האחרונה להציל.

## עקרונות

- **לא להתחנן** — מכבדים את ההחלטה
- **לא להציע הנחה אוטומטית** — שואלים קודם למה
- **להציע חלופות אמיתיות** — downgrade, pause, skip
- **להקל על חזרה** — אפשר לחזור בלי להתחיל מ-0

## English Template

```
Subject: Before you go — quick question

Hi [FirstName],

I saw you clicked "Cancel" on your [Product] account.

Before we cancel, can you tell me why? Just hit reply with one
of these:

- **Too expensive** → I can show you our [cheaper plan / annual discount]
- **Not using it** → Want to pause instead of cancel? Free for 3 months.
- **Missing feature** → Tell me what's missing. I might be able to help.
- **Found something better** → Who? (I want to know for the team)
- **Other** → Tell me in one line.

If I don't hear back in 3 days, I'll process the cancellation.
Your data stays safe for 90 days in case you want to come back.

— [Name], founder
```

## Hebrew Template

```
Subject: לפני שאתה עוזב — שאלה קצרה

היי [שם],

ראיתי שלחצת "בטל" על החשבון שלך ב-[מוצר].

לפני שאני מבטל, אפשר לספר לי למה? פשוט תענה עם אחת מאלה:

- **יקר מדי** → יש לנו תוכנית [זולה יותר / הנחה שנתית]
- **לא משתמש** → רוצה להקפיא במקום לבטל? חינם ל-3 חודשים.
- **חסר פיצ'ר** → תגיד לי מה חסר. אולי אני יכול לעזור.
- **מצאתי משהו טוב יותר** → מי? (אני רוצה לדעת לצוות)
- **אחר** → תגיד בשורה אחת.

אם לא אשמע תוך 3 ימים, אעבד את הביטול.
המידע שלך נשמר 90 יום למקרה שתרצה לחזור.

— [שם], מייסד
```

## הצעדים אחרי

| תשובת משתמש | מה לעשות |
|-------------|---------|
| "יקר מדי" | שלח קישור ל-downgrade או annual discount (20% off) |
| "לא משתמש" | הצע pause ל-3 חודשים |
| "חסר פיצ'ר" | תענה אישית, אולי אפשר לעזור |
| "מצאתי משהו אחר" | תודה על הכנות, בקש feature comparison |
| "אחר" | תקרא אישית, אל תשלח template |
| אין תשובה תוך 3 ימים | בטל בכבוד |

## verification

- [ ] נשלח תוך 24 שעות מלחיצה על Cancel
- [ ] אישי (לא "Dear user")
- [ ] 5 אופציות, לא 10
- [ ] tone מכבד (לא "אל תלך!")
- [ ] data retention policy ברור (90 יומ)
- [ ] easy comeback path

## אנטי-patterns

❌ "Are you sure?!" (כן, הוא בטוח)
❌ "We'll miss you!" (רגשי מדי)
❌ "Special 50% off just for you!" (אוטומטי, מוריד ערך)
❌ "Click here to stay" (פאסיב)
❌ "We're sad to see you go" (לא עוזר)

_footer: customer-support-templates/tasks/churn-prevention-email.md · customer-support-templates v0.1.0_
