---
name: customer-support-templates
type: skill
version: 1.0.0
category: development
description: "תבניות תקשורת עם לקוחות - מיילים, FAQ, בקשות תמיכה. כדי שלא תתחיל מאפס בכל פעם שמישהו שואל שאלה או רוצה לעזוב. Use when writing user-facing emails, onboarding sequences, churn prevention, FAQ pages, or help users file better bug reports."
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion, WebSearch, WebFetch]
related_skills:
  - build-product
  - prd-generator
  - e2e-testing
---

# Customer Support Templates

תבניות מוכנות לתקשורת עם לקוחות — בעברית ובאנגלית. חוסך זמן, נשמע מקצועי, מונע טעויות.

## מתי להשתמש

- ✅ משתמש חדש נרשם → welcome email
- ✅ משתמש לא השלים onboarding → drip campaign
- ✅ משתמר רוצה לבטל → churn prevention
- ✅ קיבלת שאלות דומות → FAQ
- ✅ מישהו מדווח על באג → bug report template
- ✅ רוצה ללמד משתמשים לבקש עזרה טוב יותר

## מה יש בפנים

| קובץ | מה זה |
|------|-------|
| `tasks/welcome-email-template.md` | מייל ראשון אחרי הרשמה |
| `tasks/onboarding-sequence.md` | רצף 5 מיילים להשלמת activation |
| `tasks/churn-prevention-email.md` | מייל כשמשתמש רוצה לעזוב |
| `tasks/faq-generator.md` | משאלות חוזרות → FAQ מסודר |
| `references/help-users-ask-good-questions.md` | תבנית "איך לדווח באג" למשתמשים |

## איך להשתמש

1. תאר את הסיטואציה: "משתמש חדש נרשם היום"
2. פתח את התבנית המתאימה
3. מלא placeholders בפרטי המוצר שלך
4. תרגם בעברית/אנגלית לפי הקהל
5. שלח (אחרי אישור שלך)

## עקרונות

- **קול אנושי**: לא "Dear valued customer" אלא "היי [שם]"
- **קצר**: מייל של 5 שורות עדיף על מייל של 500 מילים
- **ברור**: מה הצעד הבא שהמשתמש צריך לעשות
- **אמפתי**: "אני מבין שזה מתסכל" עדיף על "Error 500"
- **ממוקד פעולה**: כל מייל מסתיים ב-CTA ברור

_footer: customer-support-templates/SKILL.md · customer-support-templates v0.1.0_
