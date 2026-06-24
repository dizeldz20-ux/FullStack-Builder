# Privacy Policy from Questionnaire · v0.1.0

> ⚠️ **DISCLAIMER / כתב ויתור**
> **This is template boilerplate, not legal advice. Consult a lawyer before going to production.**
> זהו תבנית בסיסית (boilerplate), לא ייעוץ משפטי. התייעץ עם עורך דין לפני הפעלה בפרודקשן.

## מה זה / What is this

15 שאלות → Privacy Policy draft. ענה בפשטות, ה-template בתחתית יוצא מוכן.
15 questions → Privacy Policy draft. Answer in plain language; the template at the bottom generates from your answers.

מטרה: להוציא אותך מ-"אני לא יודע מה לכתוב" ל-"draft שאפשר לשלוח לעורך דין".
Goal: from "I don't know what to write" to "a draft I can send to a lawyer for review."

---

## השאלון / The Questionnaire

ענה על כל 15. תשובות קצרות מספיקות. דוגמאות בסוגריים.
Answer all 15. Short answers are fine. Examples in parentheses.

### Q1 — Company identity
> מי החברה המפעילה? שם משפטי + מדינת התאגדות + כתובת.
> Who is the operating company? Legal name + country of incorporation + address.
> *(e.g. "Acme Inc., Delaware, USA, 123 Main St, San Francisco, CA 94105")*

### Q2 — Contact for privacy questions
> אימייל/כתובת לפניות פרטיות.
> Email/address for privacy inquiries.
> *(e.g. privacy@acme.com)*

### Q3 — What personal data do you collect?
> רשימה. תחשוב: מה המשתמש ממלא, מה אתה אוסף אוטומטית, מה אתה קונה/מקבל מצד שלישי.
> List. Think: what the user fills in, what you auto-collect, what you buy/receive from third parties.
> *(e.g. "email, name, IP address, browser fingerprint, Stripe customer ID, usage events")*

### Q4 — Why do you collect it? (purposes)
> כל מטרה = שורה. תזכור: contract performance, legitimate interest, consent, legal obligation.
> One purpose per line. Remember: contract performance, legitimate interest, consent, legal obligation.
> *(e.g. "authenticate users → contract; analytics → legitimate interest; marketing email → consent")*

### Q5 — What's your legal basis under GDPR?
> אם אתה לא משרת אירופאים, כתוב N/A. אם כן — איזה basis לכל purpose.
> If you don't serve Europeans, write N/A. If you do — which basis for each purpose.
> *(e.g. "auth → contract (Art. 6(1)(b)); analytics → legitimate interest (Art. 6(1)(f)); email → consent (Art. 6(1)(a))")*

### Q6 — Where do you store data? (geography + provider)
> אזור פיזי + שם הספק. GDPR דורש לדעת אם זה EEA או לא.
> Physical region + provider name. GDPR requires knowing if EEA or not.
> *(e.g. "AWS eu-central-1 (Frankfurt); Supabase EU; Cloudflare global edge")*

### Q7 — Do you use subprocessors / third-party services that touch user data?
> רשימה: Stripe, Postmark, Mixpanel, Google Analytics, OpenAI, Sentry, וכו'.
> List: Stripe, Postmark, Mixpanel, Google Analytics, OpenAI, Sentry, etc.
> *(e.g. "Stripe (payments), Postmark (email), Sentry (errors), Mixpanel (analytics)")*

### Q8 — How long do you keep data?
> retention policy. "כל עוד החשבון פעיל + 30 יום אחרי מחיקה" זה בסדר.
> Retention policy. "As long as account active + 30 days post-deletion" is fine.
> *(e.g. "account data: while active + 30 days after deletion; logs: 90 days; backups: 1 year")*

### Q9 — Do users have rights? (GDPR Art. 15-22, CCPA)
> כן / לא. תאר איך מממשים: טופס, אימייל, זמן תגובה.
> Yes / No. Describe how you implement: form, email, response time.
> *(e.g. "yes — privacy@acme.com, 30-day response, free of charge")*

### Q10 — Do you sell data?
> CCPA מגדיר "sale" בצורה רחבה. "Sell" = גם sharing for advertising. אם כן, חובה opt-out.
> CCPA defines "sale" broadly. "Sell" = sharing for advertising too. If yes, opt-out required.
> *(e.g. "no — we don't sell or share for cross-context advertising")*

### Q11 — Cookies / tracking tech
> איזה סוגים? essential, analytics, marketing, advertising. מה בכל אחד?
> Which types? essential, analytics, marketing, advertising. What's in each?
> *(e.g. "essential: session + CSRF; analytics: Mixpanel; marketing: none; advertising: none")*

### Q12 — Children's data (COPPA, GDPR Art. 8)
> גיל מינימלי לשימוש? אם ידוע שהקהל כולל ילדים, צריך הסכמת הורים.
> Minimum age? If audience includes kids, parental consent needed.
> *(e.g. "16+; we don't knowingly collect from under 16")*

### Q13 — Security measures
> תאר בכנות. encryption at rest/in transit, access controls, breach response.
> Describe honestly. Encryption at rest/in transit, access controls, breach response.
> *(e.g. "TLS 1.3 in transit, AES-256 at rest, SOC2 sub-processors, 72h breach notification")*

### Q14 — International transfers (if outside EEA)
> אם אתה בארה"ב ומשרת EEA — צריך SCCs או EU-US Data Privacy Framework.
> If you're in the US and serve EEA — need SCCs or EU-US DPF.
> *(e.g. "yes — EU-US Data Privacy Framework certified sub-processors; SCCs as fallback")*

### Q15 — Last updated date + change notification
> איך אתה מודיע על שינויים? אימייל, in-app, עדכון העמוד?
> How do you notify changes? Email, in-app, page update?
> *(e.g. "in-app banner + email for material changes; 'Last updated' date at top")*

---

## הפלט / The Output

להלן template שאתה ממלא עם תשובותיך. זה draft, לא מסמך סופי.
Below is a template you fill with your answers. This is a draft, not a final document.

---

```markdown
# Privacy Policy

**Last updated:** [DATE]
**Effective:** [DATE]

This is the privacy policy of **[COMPANY NAME]** ("we", "us", "[COMPANY]"),
[LEGAL ADDRESS], [COUNTRY].

## 1. Who we are / Contact

The data controller is **[COMPANY NAME]** ([legal address]).
For privacy questions: **[CONTACT EMAIL]**.

## 2. What personal data we collect

We collect the following categories of personal data:

- **Account data:** [FROM Q3 — e.g. name, email, password hash]
- **Technical data:** [FROM Q3 — e.g. IP address, browser type, device ID]
- **Usage data:** [FROM Q3 — e.g. pages visited, features used, timestamps]
- **Payment data:** [FROM Q3 — handled by Stripe; we receive tokenized customer ID only]
- **Data from third parties:** [FROM Q7 — e.g. authentication provider profile if SSO]

## 3. Why we collect it (purposes and legal basis)

| Purpose | Data | Legal basis (GDPR) |
|---|---|---|
| [Q4 purpose 1] | [data] | [Q5 basis] |
| [Q4 purpose 2] | [data] | [Q5 basis] |

## 4. How long we keep it

[FROM Q8 — e.g. "Account data: while your account is active. After deletion request,
we remove within 30 days except where retention is required by law (e.g. tax records: 7 years)."]

## 5. Who we share it with (subprocessors)

We share personal data with the following subprocessors:

- **[Vendor]** — [purpose] — [location from Q6]
- [repeat per Q7]

A current list is maintained at [URL].

## 6. International transfers

[FROM Q14 — e.g. "Some subprocessors are located outside the EEA. We rely on the
EU-US Data Privacy Framework and Standard Contractual Clauses as appropriate."]
or "We do not transfer data outside the EEA."

## 7. Your rights

If you are in the EEA / UK, you have the right to:
- Access your personal data (Art. 15)
- Rectify inaccurate data (Art. 16)
- Erase your data ("right to be forgotten", Art. 17)
- Restrict processing (Art. 18)
- Data portability (Art. 20)
- Object to processing (Art. 21)
- Withdraw consent at any time (Art. 7(3))
- Lodge a complaint with your supervisory authority (Art. 77)

If you are in California (CCPA/CPRA), you have the right to:
- Know what personal data we collect and how we use it
- Delete personal data we have collected
- Correct inaccurate personal data
- Opt out of the sale or sharing of personal data (we do not sell — see Q10)
- Limit use of sensitive personal data (we do not collect)
- Non-discrimination for exercising your rights

To exercise any of these rights: **[CONTACT EMAIL from Q2]**. We respond within
**30 days** (45 under CCPA). Free of charge.

## 8. Cookies

[FROM Q11 — list categories, what they do, how to opt out]
See our [Cookie Policy / Cookie Banner] for details.

## 9. Children

[FROM Q12 — e.g. "Our service is not directed at children under 16. We do not
knowingly collect data from children. If you believe we have, contact [email]."]

## 10. Security

[FROM Q13 — describe technical and organizational measures]

In the event of a personal data breach, we will notify affected users and
relevant supervisory authorities within **72 hours** where required by GDPR Art. 33-34.

## 11. Changes to this policy

[FROM Q15 — describe change notification process]

## 12. Jurisdiction-specific addenda

**EEA representative (GDPR Art. 27):** [if you're outside EEA and subject to GDPR, name + address]
**UK representative:** [if applicable]

---

© [YEAR] [COMPANY NAME]. All rights reserved.
```

---

## Checklist לפני publish / Pre-publish checklist

- [ ] ענית על כל 15 השאלות / answered all 15 questions
- [ ] מילאת את כל ה-[BRACKETS] / filled all [BRACKETS]
- [ ] רשימת ה-subprocessors מעודכנת / subprocessor list is current
- [ ] יש עמוד `/privacy` באתר שלך / `/privacy` page exists on your site
- [ ] אימייל privacy@ עובד ועונים תוך X ימים / privacy@ works and is monitored
- [ ] עברת על `references/when-to-call-a-lawyer.md` / reviewed lawyer-escalation list
- [ ] **שלחת לעורך דין לעיון / sent to a lawyer for review** ← חובה / mandatory

---

_footer: privacy-tos-generator/tasks/privacy-policy-from-questionnaire.md · v0.1.0_