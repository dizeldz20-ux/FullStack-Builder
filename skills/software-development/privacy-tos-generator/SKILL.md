---
name: privacy-tos-generator
type: skill
version: 1.0.0
description: |
  מחולל מסמכים משפטיים למוצר SaaS — גנרוטור מוכן לשימוש ל-Privacy Policy (GDPR/CCPA), Terms of Service, Cookie Banner, ו-DPA ללקוחות B2B.
  Boilerplate legal docs generator for SaaS — privacy policies, terms of service, cookie banners, and data processing agreements. GDPR + CCPA aware.
  Hebrew guidance + English legal text.
  Audience: solo founders / indie hackers who freeze at "I don't know what to write." You don't have to know — answer the questionnaire.
related_skills:
  - build-product
  - prd-generator
  - supabase-auth-patterns
  - cloudflare-deploy
tags:
  - legal
  - privacy
  - gdpr
  - ccpa
  - compliance
  - boilerplate
  - saas
---

# privacy-tos-generator · v0.1.0

> ⚠️ **DISCLAIMER / כתב ויתור**
> **This is template boilerplate, not legal advice. Consult a lawyer before going to production.**
> זהו תבנית בסיסית (boilerplate), לא ייעוץ משפטי. התייעץ עם עורך דין לפני הפעלה בפרודקשן.
> מסמכים אלה אינם מהווים תחליף לייעוץ משפטי מקצועי, ואינם מותאמים אישית למוצר שלך.

## מה הסקיל עושה / What this skill does

מייצר baseline מסמכים משפטיים שאפשר לשלוח לעורך דין לעיון — לא מסמכים סופיים.
Generates baseline legal documents that can be sent to a lawyer for review — not final, ship-ready docs.

**מסמכים שהסקיל מייצר / Documents generated:**

| מסמך / Document | תיאור / Description | קובץ / File |
|---|---|---|
| Privacy Policy | מדיניות פרטיות GDPR/CCPA-aware מתוך 15 שאלות | `tasks/privacy-policy-from-questionnaire.md` |
| Terms of Service | תנאי שימוש עם placeholders | `tasks/terms-of-service-template.md` |
| Cookie Banner | קופי + קוד לפי אזור (EU / CA / IL / global) | `tasks/cookie-banner-generator.md` |
| DPA | הסכם עיבוד נתונים ללקוחות B2B | `tasks/dpa-template.md` |
| GDPR/CCPA Ref | מה החוק בעצם דורש | `frameworks/gdpr-ccpa-requirements.md` |
| Lawyer Escalation | מתי חייב עורך דין | `references/when-to-call-a-lawyer.md` |

## איך משתמשים / How to use

### Step 1 — Answer the 15 questions
Open `tasks/privacy-policy-from-questionnaire.md`. Answer the 15 questions about what data you collect, where you store it, who can see it, etc. Plain language — "we collect email + we use Supabase" is fine.

### Step 2 — Generate Privacy Policy
The questionnaire outputs a filled Privacy Policy draft. Drop it on your site at `/privacy`.

### Step 3 — Generate Terms of Service
Open `tasks/terms-of-service-template.md`. Replace `[BRACKETED PLACEHOLDERS]` with your specifics.

### Step 4 — Cookie Banner
Open `tasks/cookie-banner-generator.md`. Pick your region (EU/CA/IL/Global). Copy the banner copy + minimal JS implementation.

### Step 5 — DPA (only if B2B)
If you have business customers processing their users' data through your service, open `tasks/dpa-template.md`. Send to their legal team for review.

### Step 6 — Lawyer review
Open `references/when-to-call-a-lawyer.md`. If any of those cases apply to you → hire a lawyer before launch.

## What this skill does NOT do

- ❌ Not a substitute for a lawyer
- ❌ Not jurisdiction-specific beyond the frameworks it covers (GDPR EU, CCPA California, IL Privacy Law)
- ❌ Not a HIPAA / GLBA / FERPA / PCI-DSS template (different beast)
- ❌ Not a contractual agreement for high-risk industries (health, finance, minors)
- ❌ Not updated in real-time as laws change

## What this skill DOES do

- ✅ Get you from "blank page paralysis" to "draft we can iterate on"
- ✅ Surface the 80% of clauses every SaaS privacy policy needs
- ✅ Force you to think through what you actually collect
- ✅ Provide cookie banner code that won't get you sued on day one in EU
- ✅ Produce a DPA you can hand to your first enterprise prospect

## Related skills

- **build-product** — use before this skill to know what your product does
- **prd-generator** — PRD should mention data flows, this skill fills the legal gaps
- **supabase-auth-patterns** — if you use Supabase, your data storage answers live there
- **cloudflare-deploy** — your privacy policy should be on your deployed domain, not localhost

## Quick start

```bash
# Read the questionnaire
cat ~/.hermes/skills/software-development/privacy-tos-generator/tasks/privacy-policy-from-questionnaire.md

# Answer it, paste into the template at the bottom of that file
# Output lands in /privacy on your site
```

## Versions

- **v0.1.0** (current) — initial release. Covers GDPR + CCPA + IL Privacy Law. English-only legal boilerplate, bilingual guidance.

---

_footer: privacy-tos-generator/SKILL.md · v0.1.0_