# PRD Examples

Three worked examples showing what good vs bad PRDs look like. Used during `/prd-generator` to calibrate "what good looks like" and to push back on vague / invented / scope-crept content.

---

## Example 1: GOOD — Restaurant Table Booking (full, ready for build)

```markdown
# PRD: Restaurant Table Booking

**Slug:** restaurant-table-booking
**Date:** 2026-06-24
**Owner:** the user
**Status:** Draft
**Version:** 0.1.0

---

## TL;DR

אפליקציית web שמאפשרת ללקוחות של מסעדות בודדות בתל אביב להזמין שולחן בלי להתקשר. הזמנה בתוך 30 שניות, אישור מיידי, בלי חיוג. Core feature: בחירת תאריך + שעה + מספר סועדים + אישור.

**Core feature (one line):** הזמנת שולחן end-to-end עם אישור אוטומטי.

---

## Problem Statement

הזמנת שולחן במסעדה בתל אביב דורשת היום חיוג טלפון בשעות הפעילות (12:00-23:00). בעלי המסעדה לא תמיד עונים (במיוחד בשעות העומס), והלקוח מתייאש ובוחר מסעדה אחרת. אובדן הזמנות = אובדן הכנסה.

**Current workaround:** חיוג טלפון. בעל המסעדה מקבל טלפון, רושם בפנקס או ב-Google Calendar.
**Why it fails:** 30%+ מהשיחות בשעות העומס לא נענות → אובדן הזמנות. אין visibility למסעדה על הביקוש.

---

## Target User

| Field | Value |
|-------|-------|
| Name | Rotem (Primary) |
| Age range | 25-40 |
| Role | לקוח של מסעדות יוקרה בתל אביב, אוהב לתכנן ארוחות מראש |
| Location | תל אביב ומרכז |
| Tech comfort | high |
| Current tool | טלפון למסעדה + Google Calendar |
| Why they'll switch | מהיר יותר, לא צריך לחייג, רואה זמינות מיידית |

**Primary user:** Rotem
**Secondary users:** בעלי מסעדות (Owner dashboard)

---

## Goals & Non-Goals

### Goals (MVP)
- לקוח יכול להזמין שולחן ב-3 קליקים, פחות מ-30 שניות
- בעל המסעדה מקבל אישור מיידי ב-email
- 50 הזמנות בחודש הראשון מ-1 מסעדת pilot

### Non-Goals (MVP)
- תשלום מקדמה (deposit)
- בחירת שולחן ספציפי (location במסעדה)
- הזמנה לקבוצות של 8+
- Loyalty / rewards program

---

## Core Feature (MVP)

**Feature name:** הזמנת שולחן end-to-end
**Why this is the core:** בלי זה, אין מוצר. כל השאר זה נחמדות.
**Success definition:** לקוח בוחר תאריך, שעה, מספר סועדים, לוחץ "הזמן" → רואה אישור + מקבל email.

### Sub-capabilities (still part of MVP)
- בחירת מסעדה (single restaurant ל-MVP, לא marketplace)
- בחירת תאריך + שעה מ-availability calendar של המסעדה
- הזנת שם + טלפון + email
- אישור מיידי ב-email
- ביטול הזמנה (עד שעתיים לפני)

---

## User Flow

| Step | User Action | System Response | Notes |
|------|-------------|-----------------|-------|
| 1 | נכנס ל-`table.example.co.il` | רואה hero + טופס הזמנה | Single page, no nav |
| 2 | בוחר תאריך (DatePicker) | רואה שעות פנויות | Reject עבר |
| 3 | בוחר שעה + מספר סועדים | מאשר בחירה | |
| 4 | ממלא שם + טלפון + email | Validate inline | |
| 5 | לוחץ "הזמן" | רואה "אישור + מספר הזמנה" + email נשלח | |

**Entry point:** `table.example.co.il` (direct URL, no marketing site for MVP)
**Exit / success state:** דף אישור עם מספר הזמנה + "ביטול עד שעתיים לפני"

---

## Edge Cases & Failure Modes

| Scenario | Expected Behavior | Priority |
|----------|-------------------|----------|
| Network unavailable | Disable submit, show "אין חיבור — נסה שוב" | P0 |
| API returns 5xx | Retry once, then "לא הצלחנו — נסה שוב או חייג" | P0 |
| Email invalid | Inline error: "מייל לא תקין" | P0 |
| תאריך/שעה בעבר | Disabled in UI | P0 |
| Email send fails | Show success but warn "לא שלחנו email — שמור את המספר" | P0 |
| הזמנה זהה באותו slot | Allow overbooking? No — reject 409, suggest slot סמוך | P0 |
| מסעדה סגורה ביום מסוים | Disable יום ב-DatePicker | P1 |
| Concurrent same action (double-click) | Idempotency by client request ID | P1 |
| ביטול פחות משעתיים לפני | Disable cancel button, show "חייג למסעדה" | P1 |

---

## Acceptance Criteria

- [ ] לקוח יכול להזמין שולחן ב-3 קליקים (תאריך → שעה → פרטים → אישור)
- [ ] זמן מ-end של ה-flow עד אישור < 30 שניות
- [ ] email עם אישור נשלח תוך 10 שניות מאישור
- [ ] כאשר API מחזיר 500, המשתמש רואה הודעת שגיאה ברורה (לא stack trace)
- [ ] ביטול הזמנה עובד עד שעתיים לפני ההזמנה
- [ ] ביטול פחות משעתיים לפני מציג "חייג למסעדה" (לא מאפשר ביטול)
- [ ] כפתור submit disabled כשאין חיבור
- [ ] 50 הזמנות בחודש הראשון עוברות ללא data loss
- [ ] Idempotency: double-click יוצרת רק 1 הזמנה

---

## Success Metrics

| Metric | Target | Timeframe | How to Measure |
|--------|--------|-----------|----------------|
| הזמנות מ-Pilot restaurant | 50 | 30 יום | DB query |
| זמן מ-end-to-end (קליק → אישור) | < 30 שניות p95 | always | Analytics event |
| Conversion rate (visits → הזמנה) | 20% | always | Analytics event |
| ביטול אחרי שעתיים | < 5% | always | DB query |

**Primary success indicator:** 50 הזמנות ב-30 יום מ-Pilot restaurant.

---

## Out of Scope (MVP)

- **תשלום מקדמה:** דורש Stripe + flow שלם; דוחה ל-V1.1
- **הזמנה לקבוצות 8+:** דורש flow נפרד; V1.1
- **Marketplace של מסעדות:** single restaurant ל-MVP; V1.1
- **Mobile app:** web responsive בלבד; native דוחה ל-V2
- **Loyalty program:** V2
- **SMS notifications:** email בלבד; SMS V1.1

---

## Technical Constraints

- **Stack:** To be decided by `build-product` (suggest: Next.js + Postgres + Resend)
- **Database:** Postgres (Supabase suggested)
- **Hosting:** Cloudflare Pages (suggested)
- **External APIs:** Resend (email)
- **Compliance:** Privacy Protection Law (Israel) — collect minimal data, allow deletion
- **Performance target:** < 500ms p95 server response
- **Other:** Hebrew RTL UI from day 1

---

## Assumptions

- `[inferred]` יש מסעדת pilot מוכנה לפרסם את הקישור — needs confirmation from owner
- `[inferred]` Resend הוא ה-email provider — cost-effective, Hebrew-friendly templates
- `[user-stated]` ב-MVP רק 1 מסעדה, לא marketplace
- `[inferred]` הזמנות נשמרות ל-90 יום (V1.1: user-facing export)

---

## Open Questions

### OQ-1: Authentication for restaurant owner
- **Context:** הזמנות צריכות להגיע לבעל המסעדה. איך הוא מתחבר?
- **Blocks:** Owner dashboard (out of MVP scope אבל נצטרך לדעת)
- **Suggested resolution:** Email magic link via Supabase Auth. רק בעל המסעדה הרשום.
- **Priority:** P1 (P0 אם owner dashboard in MVP)

### OQ-2: Email template language
- **Context:** email אישור — עברית, אנגלית, או שניהם?
- **Blocks:** Email content design
- **Suggested resolution:** עברית בלבד ל-MVP (Rotem הוא היעד). אנגלית ב-V1.1.
- **Priority:** P2

### OQ-3: Deposit on Saturday reservations
- **Context:** הזמנות לשבת במסעדות יוקרה — לרוב דורשים מקדמה. כללנו ב-Out of Scope, אבל אולי צריך?
- **Blocks:** Pilot launch readiness
- **Suggested resolution:** ודא עם בעל המסעדה. אם כן → move from Out of Scope, add to Core.
- **Priority:** P0

---

## Handoff Notes

**To `build-product`:**
- התחל מ-Step 1 → 5 ב-User Flow. כל sub-capability הוא part of MVP.
- Out of Scope = אל תבנה את זה. גם אם "נראה קל". במיוחד deposit.
- Edge cases P0 = חובה. P1 = רצוי.
- אם OQ-3 לא נסגר (deposit on Saturday) → עצור ושאל.

**To `writing-plans`:**
- Acceptance Criteria = בסיס ל-tasks.
- User Flow = סדר vertical slice: end-to-end הזמנה → אחר כך email → אחר כך cancel.
- Technical Constraints: Next.js + Postgres + Resend, Cloudflare Pages.

---

*PRD generated by prd-generator skill · Built with Skillsmith*
```

**Why this PRD is good:**
- ✅ User persona is specific (Rotem, 25-40, תל אביב, tech comfort high)
- ✅ Core feature is ONE thing (הזמנת שולחן)
- ✅ Out of Scope is explicit and detailed (6 items)
- ✅ Success metric has numbers (50 ב-30 יום, < 30 שניות)
- ✅ Edge cases cover Network / Empty / Invalid Input / Auth (categories from spec)
- ✅ Acceptance criteria are testable (- [ ] items)
- ✅ Open Questions are enumerated with priority
- ✅ No invented features (no login for customer, no loyalty, no social)
- ✅ Handoff notes are explicit
- ✅ `restaurant-table-booking` is kebab-case, max 4 words

---

## Example 2: BAD — "The Notion Killer" (vague, scope-crept, no metrics)

```markdown
# PRD: BetterNote

**Slug:** better-note
**Date:** 2026-06-20
**Owner:** the user
**Status:** Draft
**Version:** 0.1.0

---

## TL;DR

אפליקציה לכתיבת notes שעושה את מה שNotion לא עושה טוב.

---

## Problem Statement

Notion הוא איטי, מבלבל, ויש בו יותר מדי features.

---

## Target User

אנשים שרוצים לכתוב notes.

---

## Goals & Non-Goals

### Goals
- להיות טובים יותר מNotion
- ממשק נקי
- מהיר

### Non-Goals
- לא רוצים להיות מורכבים

---

## Core Feature (MVP)

הכל. נעשה את כל מה שצריך.

### Sub-capabilities
- Login
- Profile
- Dashboard
- Real-time collaboration
- AI features
- Mobile app
- Desktop app
- Integrations (Slack, Notion, Google Drive, Trello, Asana)
- Templates
- Public sharing
- Version history

---

## User Flow

המשתמש נכנס → רואה dashboard → יוצר note → עורך → שומר.

---

## Edge Cases

לטפל בשגיאות.

---

## Acceptance Criteria

- [ ] אפליקציה עובדת
- [ ] ממשק נחמד
- [ ] מהירה

---

## Success Metrics

המון אנשים ישתמשו.

---

## Out of Scope

רק features שלא צריך עכשיו.

---

## Technical Constraints

נחליט אחר כך.

---

## Open Questions

- איך עושים login?
- צריך גם mobile?
- כמה זמן יקח?

---

*PRD generated by prd-generator skill · Built with Skillsmith*
```

**Why this PRD is bad (and the skill should refuse to produce something like this):**

| Issue | Why it's a problem | How the skill should push back |
|-------|-------------------|-------------------------------|
| "Better than Notion" | Notion does 50 things. What 1 thing? | Q4 push-back: "איזה 1 feature?" |
| Persona: "אנשים" | Everyone = no one | Q2 push-back: "מי ספציפית?" |
| Goals: "להיות טובים יותר" | Unmeasurable | Q8 push-back: "תן מספר" |
| 11 sub-capabilities | Not MVP, that's V3 | Refuse to enumerate, force choice |
| Core Feature: "הכל" | Defeats purpose of "core" | Q4 push-back: "אחד, לא הכל" |
| User Flow: 4 vague words | No actual flow | Q5 push-back: "צעד-צעד, מה המערכת עושה?" |
| Edge Cases: "לטפל בשגיאות" | Not a real edge case | Q6 push-back: "מה קורה כש-X? תאר התנהגות" |
| Success Metrics: "המון אנשים" | No number | Q8 push-back: "כמה? מתי?" |
| Non-Goals: vague | Doesn't help scope discipline | Q7 push-back: "3 features שאתה מתפתה אבל לא צריך" |
| Open Questions: 3 random | Not prioritized, not contextual | Q10 format: P0/P1/P2 + Context + Blocks |
| Tech Constraints: "נחליט אחר כך" | This is a PRD, not a thought bubble | Q9: ask explicitly, default to "TBD by `build-product`" |

**Lesson for the skill:** When the user pushes back against specific answers with "I'll decide later" — surface that as an OQ with Priority P0 (it's blocking). Never silently accept vague answers.

---

## Example 3: MID (correctable) — "WhatsApp reminders for dentists"

A PRD that's mostly good but has 3 specific issues the skill should catch.

```markdown
# PRD: DentalRemind

**Slug:** dental-remind
**Date:** 2026-06-22
**Owner:** the user
**Status:** Draft
**Version:** 0.1.0

---

## TL;DR

Bot WhatsApp ששולח תזכורות לפגישות לרופאי שיניים. הרופא מזין תור → המטופל מקבל WhatsApp יום לפני.

**Core feature (one line):** תזכורת WhatsApp אוטומטית יום לפני פגישה.

---

## Problem Statement

מטופלים שוכחים מתורים. רופאי שיניים מאבדים הכנסה.

**Current workaround:** צוות הקליניקה מתקשר ידנית יום לפני.
**Why it fails:** גוזל זמן, לא scalable.

---

## Target User

| Field | Value |
|-------|-------|
| Name | Dr. Cohen |
| Role | רופא שיניים עם קליניקה פרטית |
| Location | ישראל |
| Tech comfort | medium |
| Current tool | Excel + צוות שמתקשר |
| Why they'll switch | אוטומטי, חוסך זמן צוות |

**Primary user:** Dr. Cohen (clinic owner)
**Secondary users:** מטופלים (receive reminders)

---

## Goals & Non-Goals

### Goals (MVP)
- 10 קליניקות רשומות תוך 30 יום
- 90% מההודעות נמסרות (delivery rate)

### Non-Goals (MVP)
- תזמון פגישות (רק תזכורות)
- תשלום דרך המערכת
- סנכרון עם תוכנת ניהול קליניקה

---

## Core Feature (MVP)

**Feature name:** שליחת תזכורת WhatsApp אוטומטית
**Why this is the core:** בלי זה, אין מוצר.
**Success definition:** כל פגישה שמוזנת למערכת → המטופל מקבל WhatsApp 24 שעות לפני.

### Sub-capabilities
- רופא יוצר חשבון (email + password)
- רופא מזין פגישה (שם מטופל + תאריך + שעה + טלפון)
- תזכורת נשלחת 24 שעות לפני
- רופא רואה log של הודעות שנשלחו

---

## User Flow

[4 steps, table format — abbreviated]

---

## Edge Cases

[7 rows, P0/P1 — abbreviated]

---

## Acceptance Criteria

[8 items — abbreviated]

---

## Success Metrics

| Metric | Target |
|--------|--------|
| קליניקות רשומות | 10 ב-30 יום |
| delivery rate | 90% |

**Primary success indicator:** 10 קליניקות רשומות.

---

## Out of Scope

- תזמון פגישות
- תשלום
- סנכרון ל-software קיים
- multi-language (עברית בלבד)

---

## Technical Constraints

- **Stack:** To be decided by `build-product`
- **External APIs:** WhatsApp Business API (GreenAPI)
- **Hosting:** Cloudflare
- **Compliance:** Privacy Protection Law

---

## Assumptions

- `[inferred]` WhatsApp Business API דרך GreenAPI זה הפתרון הסביר
- `[inferred]` delivery rate של 90% הוא הסטנדרט ב-GreenAPI

---

## Open Questions

### OQ-1: GreenAPI vs direct WhatsApp Business
- **Context:** GreenAPI זו דרך אחת, אבל יש גם direct API
- **Blocks:** Tech choice
- **Suggested resolution:** Default to GreenAPI (easier). Direct only if scale.
- **Priority:** P1

### OQ-2: האם המטופל צריך לאשר קבלת תזכורות?
- **Context:** WhatsApp Business דורש opt-in
- **Blocks:** Legal compliance
- **Suggested resolution:** הודעה ראשונה עם opt-in keyword
- **Priority:** P0

---

## Handoff Notes

**To `build-product`:** התחל מ-WhatsApp integration. כל flow סביב זה.

**To `writing-plans`:** Acceptance Criteria = basis.

---

*PRD generated by prd-generator skill · Built with Skillsmith*
```

**Issues the skill should catch (and fix):**

| # | Issue | Fix |
|---|-------|-----|
| 1 | OQ-1 marked P1, but **blocks the tech stack decision** | Bump to P0. Tech choice is MVP-critical. |
| 2 | **Acceptance Criteria "abbreviated"** — the actual file needs 5-15 real items | Re-expand. Skill should refuse to abbreviate. |
| 3 | **No User Persona for secondary user (מטופל)** — they receive the messages, they matter | Add a secondary persona table for the patient. |
| 4 | **Out of Scope** has 4 items but doesn't say **why not** or **when** | Expand to format: **{feature}:** {why not} + {when if known} |
| 5 | **Success metric for delivery rate** is 90% — but how to measure when GreenAPI only reports "delivered" not "read"? | Reframe metric: "WhatsApp delivery success (API status = delivered), target 95%" — measurable. |

**This PRD is "almost ready"** — the skill should fix the 5 issues, run quality checklist, and ship.

---

*Reference maintained by prd-generator skill · Built with Skillsmith*
