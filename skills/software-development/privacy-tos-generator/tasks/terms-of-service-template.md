# Terms of Service Template · v0.1.0

> ⚠️ **DISCLAIMER / כתב ויתור**
> **This is template boilerplate, not legal advice. Consult a lawyer before going to production.**
> זהו תבנית בסיסית (boilerplate), לא ייעוץ משפטי. התייעץ עם עורך דין לפני הפעלה בפרודקשן.
> תנאי שימוש אלה הם תבנית כללית ועשויים שלא להתאים למוצר שלך.

## מה זה / What is this

Terms of Service (ToS) — תנאי שימוש — הסכם בין הספק למשתמש.
This is the contract between you (the service provider) and your user.

מבנה קלאסי ל-SaaS: הגדרות, רישוי, מה אסור, תשלום, אחריות, סיום, סמכות שיפוט.
Standard SaaS structure: definitions, license, acceptable use, payment, warranty, termination, governing law.

---

## Placeholders — replace these

לפני publish, חפש `[LIKE_THIS]` והחלף.
Before publishing, find every `[LIKE_THIS]` and replace.

- `[COMPANY_NAME]` — your legal entity name
- `[SERVICE_NAME]` — product name
- `[DOMAIN]` — your website domain
- `[COUNTRY]` — country of incorporation
- `[STATE]` — state / province
- `[ADDRESS]` — registered address
- `[JURISDICTION]` — governing law & venue (e.g. "State of Delaware, USA")
- `[EFFECTIVE_DATE]` — when these terms take effect
- `[CONTACT_EMAIL]` — legal/ToS contact (often legal@ or privacy@)
- `[PRICE]` — pricing model summary (or "as posted on [URL]")
- `[REFUND_DAYS]` — refund window (e.g. "14") or "no refunds"
- `[MIN_AGE]` — minimum age (typically 16 or 18)

---

## The Template

```markdown
# Terms of Service

**Effective date:** [EFFECTIVE_DATE]
**Last updated:** [EFFECTIVE_DATE]

These Terms of Service ("Terms") govern your access to and use of [SERVICE_NAME]
(the "Service"), operated by [COMPANY_NAME] ("[COMPANY]", "we", "us").

By accessing or using the Service, you agree to be bound by these Terms.
If you do not agree, do not use the Service.

## 1. Definitions

- **"Service"** — [SERVICE_NAME], including all related websites, APIs, and
  software provided by [COMPANY].
- **"User"** or **"you"** — any individual or entity that accesses or uses the Service.
- **"Account"** — the registered account you create to access the Service.
- **"Content"** — any data, text, image, or other material you submit to the Service.

## 2. Eligibility

You must be at least [MIN_AGE] years old to use the Service. By using the
Service, you represent that you meet this requirement. If you are using the
Service on behalf of an organization, you represent that you have authority
to bind that organization to these Terms.

## 3. Account registration

You may need to register for an account. You agree to:
- Provide accurate, current, and complete information
- Maintain the security of your account credentials
- Promptly notify us at [CONTACT_EMAIL] if you suspect unauthorized access
- Accept responsibility for all activities under your account

## 4. License and acceptable use

### 4.1 License
Subject to these Terms, [COMPANY] grants you a limited, non-exclusive,
non-transferable, revocable license to access and use the Service for your
internal business or personal purposes.

### 4.2 Restrictions
You agree NOT to:
- Reverse engineer, decompile, or attempt to extract the source code of the Service
- Use the Service to build a competing product
- Resell, sublicense, or redistribute the Service without our written permission
- Upload malicious code, spam, or content that infringes third-party rights
- Use the Service in violation of any applicable law
- Attempt to gain unauthorized access to the Service or its related systems
- Use the Service to harass, harm, or impersonate others
- Scrape the Service at scale without our written permission

## 5. Fees and payment

### 5.1 Fees
The Service is offered at the prices posted at [PRICE_URL]. We may change
prices with [30] days notice. Continued use after the change constitutes
acceptance.

### 5.2 Billing
Paid plans are billed in advance via Stripe or other payment processor we
designate. You authorize us to charge your payment method for all fees.

### 5.3 Refunds
[Choose one:]
- "[COMPANY_NAME] offers a [REFUND_DAYS]-day money-back guarantee for new
  subscriptions, no questions asked."
- "All fees are non-refundable except where required by law."

### 5.4 Taxes
Fees are exclusive of taxes. You are responsible for any applicable taxes.

## 6. Intellectual property

### 6.1 Our IP
The Service, including its design, code, and content (excluding your Content),
is owned by [COMPANY] and protected by intellectual property laws. We grant
you the license in Section 4; we retain all other rights.

### 6.2 Your Content
You retain ownership of Content you upload to the Service. You grant us a
worldwide, non-exclusive, royalty-free license to host, copy, transmit, and
process your Content solely to operate the Service for you.

### 6.3 Feedback
If you provide feedback or suggestions, we may use them without restriction
or compensation.

## 7. Confidentiality

Each party may access confidential information of the other. Both parties
agree to protect such information with reasonable care and not use it for
purposes outside these Terms. This section survives termination.

## 8. Privacy

Your use of the Service is also governed by our [Privacy Policy](/privacy),
which is incorporated into these Terms by reference.

## 9. Third-party services

The Service may integrate with third-party services (e.g. Stripe, Supabase,
OpenAI). We are not responsible for those services. Your use of them is
governed by their respective terms.

## 10. Termination

### 10.1 By you
You may stop using the Service at any time. To delete your account, contact
[CONTACT_EMAIL] or use the in-product deletion flow.

### 10.2 By us
We may suspend or terminate your account if:
- You breach these Terms
- Your use poses a security or legal risk
- We are required to do so by law
- We discontinue the Service (with reasonable notice)

### 10.3 Effect
Upon termination, your right to use the Service ends. Sections that by their
nature should survive (payment obligations, IP, disclaimers, limitations of
liability, indemnity, dispute resolution) will survive.

## 11. Disclaimers

THE SERVICE IS PROVIDED "AS IS" AND "AS AVAILABLE" WITHOUT WARRANTIES OF ANY
KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, NON-INFRINGEMENT, AND
ACCURACY OF RESULTS.

WE DO NOT WARRANT THAT THE SERVICE WILL BE UNINTERRUPTED, ERROR-FREE, OR
SECURE, OR THAT DEFECTS WILL BE CORRECTED.

## 12. Limitation of liability

TO THE MAXIMUM EXTENT PERMITTED BY LAW, [COMPANY] AND ITS OFFICERS,
EMPLOYEES, AND AGENTS WILL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL,
SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES, OR ANY LOSS OF PROFITS,
REVENUE, DATA, OR GOODWILL.

OUR TOTAL LIABILITY FOR ANY CLAIM ARISING FROM OR RELATED TO THESE TERMS
WILL NOT EXCEED THE GREATER OF (A) THE AMOUNTS YOU PAID US IN THE 12 MONTHS
PRECEDING THE CLAIM, OR (B) USD $100.

Some jurisdictions do not allow the limitation of certain damages; in those
jurisdictions, the limitations above apply to the maximum extent permitted.

## 13. Indemnification

You agree to indemnify, defend, and hold harmless [COMPANY] from any claims,
liabilities, damages, and expenses (including reasonable legal fees) arising
from (a) your use of the Service, (b) your Content, or (c) your violation
of these Terms or any law.

## 14. Dispute resolution

### 14.1 Informal resolution
Before filing a claim, you agree to contact us at [CONTACT_EMAIL] and
attempt to resolve the dispute informally for 30 days.

### 14.2 Arbitration (US, optional)
[Choose one:]

**Option A — Arbitration:**
Any dispute will be resolved by binding arbitration administered by the
American Arbitration Association under its Commercial Arbitration Rules.
Arbitration will take place in [JURISDICTION]. You waive the right to a
jury trial and to participate in a class action.

**Option B — Courts:**
These Terms are governed by the laws of [JURISDICTION]. Any dispute will be
resolved exclusively in the courts located in [JURISDICTION].

### 14.3 Exceptions
Either party may seek injunctive relief in court to protect intellectual
property or confidential information.

## 15. Changes to these Terms

We may update these Terms. We will notify you of material changes via email
or in-product notice at least [14] days before they take effect. Continued
use after the effective date constitutes acceptance.

## 16. General

- **Entire agreement:** These Terms + Privacy Policy are the entire agreement
  between us regarding the Service.
- **Severability:** If any provision is held unenforceable, the rest remains
  in effect.
- **No waiver:** Failure to enforce any right does not waive that right.
- **Assignment:** You may not assign these Terms without our consent. We may
  assign them in connection with a merger or sale.
- **Force majeure:** We are not liable for delays caused by events beyond
  our reasonable control.

## 17. Contact

[COMPANY_NAME]
[ADDRESS]
[COUNTRY]
Email: [CONTACT_EMAIL]

© [YEAR] [COMPANY_NAME]. All rights reserved.
```

---

## Checklist / רשימת בדיקה

- [ ] החלפת כל ה-[PLACEHOLDERS] / replaced all placeholders
- [ ] בחרת אסטרטגיית dispute resolution (Arbitration או Courts) / chose dispute strategy
- [ ] בחרת מדיניות refunds / chose refund policy
- [ ] הגדרת גיל מינימלי / set minimum age
- [ ] קישור ל-Privacy Policy / link to Privacy Policy
- [ ] **שלחת לעורך דין / sent to a lawyer** ← חובה / mandatory

---

## טיפים / Tips

1. **Don't copy Stripe's ToS verbatim** — they have different risk profile than you.
2. **If your ToS is "by using the Service you agree"**, that's browsewrap. Some
   jurisdictions (especially EU) require a clickwrap ("I agree" button) for
   enforceability on material terms.
3. **Arbitration clause is one-sided if you reserve "we can go to court but
   you can't"** — courts have struck these down. Keep it symmetric or skip it.
4. **Don't promise SLAs in the ToS** — make them a separate SLA doc if you offer one.
5. **If you sell to EU consumers**, you have additional mandatory rights (14-day
   withdrawal, etc.) — see `frameworks/gdpr-ccpa-requirements.md`.

---

_footer: privacy-tos-generator/tasks/terms-of-service-template.md · v0.1.0_