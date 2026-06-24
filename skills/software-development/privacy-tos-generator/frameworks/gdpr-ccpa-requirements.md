# GDPR / CCPA / IL Privacy Law — What the Laws Actually Require · v0.1.0

> ⚠️ **DISCLAIMER / כתב ויתור**
> **This is template boilerplate, not legal advice. Consult a lawyer before going to production.**
> זהו תבנית בסיסית (boilerplate), לא ייעוץ משפטי. התייעץ עם עורך דין לפני הפעלה בפרודקשן.
> סיכום זה אינו מקיף; חוקים אלה מורכבים ומתפתחים.

## למה צריך להבין / Why understand this

כדי לדעת מה ה-template אמור לכסות, ולזהות מתי צריך עורך דין.
To know what your templates should cover, and to recognize when you need a lawyer.

זה reference, לא תחליף ל-ICO / CNIL / EDPB guidance.
This is a reference, not a substitute for ICO / CNIL / EDPS guidance.

---

## 🇪🇺 GDPR (EU + EEA + UK)

**Full name:** General Data Protection Regulation (EU 2016/679) + UK GDPR.
**Applies to:** any org processing personal data of people in the EEA/UK, regardless of where the org is based.

### 7 principles (Art. 5)

1. **Lawfulness, fairness, transparency** — must have legal basis; tell people what you're doing.
2. **Purpose limitation** — collect for specified, explicit purposes; don't repurpose.
3. **Data minimization** — collect only what you need.
4. **Accuracy** — keep it correct; rectify on request.
5. **Storage limitation** — keep only as long as needed.
6. **Integrity & confidentiality** — security.
7. **Accountability** — **you must prove** you comply. Documentation is required.

### 6 legal bases (Art. 6)

| Basis | When |
|---|---|
| (a) Consent | Freely given, specific, informed, unambiguous. Easy to withdraw. |
| (b) Contract | Needed to perform a contract with the data subject. |
| (c) Legal obligation | Required by law. |
| (d) Vital interests | Life-threatening situations. Rare. |
| (e) Public task | Public authorities. |
| (f) Legitimate interests | You have a real business need, balanced against the person's rights. Document the LIA. |

For SaaS, you'll mostly use (b) contract + (a) consent + (f) legitimate interest.

### Data Subject rights (Chapter III, Arts. 12-22)

| Right | Art. | Practical |
|---|---|---|
| Information | 13-14 | Privacy policy at point of collection |
| Access | 15 | "Send me my data" |
| Rectification | 16 | "Fix this" |
| Erasure | 17 | "Delete me" (with limits) |
| Restrict processing | 18 | "Pause but don't delete" |
| Portability | 20 | Machine-readable export |
| Object | 21 | "Stop using my data for X" |
| Automated decisions | 22 | "No profiling without consent or law" |
| Withdraw consent | 7(3) | As easy as giving it |
| Complain | 77 | To supervisory authority |

**Response time:** without undue delay, max **30 days** (extendable by 60 in complex cases).

### Breach notification (Arts. 33-34)

- **To supervisory authority:** within **72 hours** of becoming aware (if risk to people).
- **To data subjects:** without undue delay (if high risk).

### Fines (Art. 83)

- Up to **€20M or 4% of global annual turnover**, whichever is higher.
- Lesser tier: €10M or 2%.

This is why "boilerplate + lawyer review" is non-negotiable.

### What's mandatory to have on a SaaS site

- [ ] Privacy policy with all required Art. 13-14 info
- [ ] Cookie banner (opt-in for non-essential) — see `cookie-banner-generator.md`
- [ ] DPA signed with B2B customers (Art. 28)
- [ ] Records of processing activities (Art. 30) — internal, not public
- [ ] Security measures documented (Art. 32)
- [ ] Breach response plan (Arts. 33-34)
- [ ] Data Protection Officer (DPO) — only if you do large-scale monitoring or process special categories
- [ ] EU representative (Art. 27) — only if you're outside EEA and processing EEA data
- [ ] International transfer mechanism (Chapter V) — SCCs, adequacy, or BCRs

---

## 🇺🇸 CCPA / CPRA (California)

**Full name:** California Consumer Privacy Act + California Privacy Rights Act (effective 2023).
**Applies to:** businesses that meet thresholds (≥$25M revenue, OR 100k+ consumers, OR 50%+ revenue from selling data).

Different from GDPR in important ways:

| Dimension | GDPR | CCPA/CPRA |
|---|---|---|
| Default | Opt-in for non-essential | Opt-out for most |
| "Sale" definition | Marketing | **Broad** — includes sharing for cross-context ads |
| Penalty model | Up to 4% revenue | $2,500/violation, $7,500/intentional |
| Private right of action | Limited | Yes — for data breaches of certain data |
| Sensitive data | Special category | Separate "sensitive PI" category with right to limit |
| Global Privacy Control | N/A | **Must honor** as opt-out signal |

### Consumer rights

| Right | Detail |
|---|---|
| Know | What you collect, why, who you share with |
| Delete | Erasure (with limits for legal/transactional records) |
| Correct | Rectification |
| Opt out of sale/sharing | Including via GPC browser signal |
| Limit use of sensitive PI | For services not "necessary" |
| Non-discrimination | For exercising rights |

### Response time

**45 days**, extendable by 45 more with notice.

### What's mandatory

- [ ] Privacy policy with CCPA-specific disclosures (categories collected, sold, shared)
- [ ] "Do Not Sell or Share My Personal Information" link in footer
- [ ] Honor Global Privacy Control (GPC) signal
- [ ] Service provider contracts (CCPA term equivalent to GDPR's DPA, but simpler)
- [ ] Records of consumer requests for 24 months

---

## 🇮🇱 Israel Privacy Protection Law

**Full name:** חוק הגנת הפרטיות, 1981 + amendments (most recently Amendment 14 in 2024 aligning toward GDPR).
**Regulator:** רשות הגנת הפרטיות (Privacy Protection Authority, PPA).
**Database registration:** required for any database with personal data.

### Key obligations

- **Database registration** with PPA (with exceptions for small/recent databases).
- **Privacy policy** at the organization level + at point of collection.
- **Consent** for sensitive data (health, sexual orientation, etc.) — broader than GDPR.
- **Data Security Regulations (קב"ע הגנת הפרטיות)** — specific technical/organizational requirements.
- **DPO** may be required depending on database size and sensitivity.
- **Cross-border transfers** — restricted to countries with adequate protection; transfers to other countries require specific approval.
- **Marketing email (חוק התקשורת)** — opt-in for unsolicited commercial messages (Section 30A).

### Differences from GDPR (current state)

- Some legacy obligations are still in transition from pre-2024 amendments.
- Database registration is **more explicit** than GDPR (which doesn't require registration).
- Marketing rules are stricter in some respects (similar to PECR in EU).

---

## When you DON'T need to comply

| Scenario | GDPR | CCPA | Israel |
|---|---|---|---|
| Pure B2B to non-EU businesses | N/A (no EU data subjects) | N/A | N/A |
| < 100k consumers | N/A | Maybe (other thresholds) | N/A |
| No commercial activity (purely personal/hobby) | Possibly exempt | Maybe exempt | Maybe exempt |
| Aggregated fully-anonymized data | Mostly exempt | Mostly exempt | Mostly exempt |

**Don't self-exempt without checking.** If you're in doubt, comply.

---

## Things that often surprise founders

1. **GDPR applies even if you're outside the EU**, if you serve EU data subjects.
2. **"We don't have EU users"** is hard to prove and changes the moment one signs up.
3. **IP addresses are personal data** under GDPR (CJEU Breyer, 2016).
4. **Cookies that track across sessions are not "strictly necessary"** — opt-in required.
5. **CCPA "sale" includes sharing for advertising** — even via pixels.
6. **Privacy policy must be at point of collection**, not just on a footer.
7. **"Legitimate interest" requires a documented assessment (LIA)** — not just a checkbox.
8. **Subprocessors must be listed publicly** — and many forget this.
9. **Privacy by Design (Art. 25)** — must be considered from product inception, not bolted on.
10. **Children's data (under 16 in most EU; under 13 in US COPPA)** has stricter rules.

---

## Resources (read these, don't rely on this doc alone)

- **GDPR full text:** https://gdpr-info.eu/
- **EDPB Guidelines:** https://edpb.europa.eu/our-work-tools/our-documents/guidelines_en
- **ICO (UK):** https://ico.org.uk/for-organisations/
- **CNIL (France):** https://www.cnil.fr/en
- **California AG CCPA:** https://oag.ca.gov/privacy/ccpa
- **Israel PPA:** https://www.gov.il/he/departments/privacy_authority
- **IAPP:** https://iapp.org/ (professional association, good source of summaries)
- **Standard Contractual Clauses (2021/914):** https://eur-lex.europa.eu/eli/dec_impl/2021/914/oj

---

## Checklist — are you in scope?

- [ ] Do you have users in the EEA/UK? → **GDPR likely applies**
- [ ] Are you a CA business with $25M+ revenue, 100k+ consumers, or 50%+ data-sale revenue? → **CCPA likely applies**
- [ ] Do you have a database with personal data of Israeli residents? → **IL Privacy Law likely applies**
- [ ] If any "likely applies" → use the templates in this skill **and** consult a lawyer

---

_footer: privacy-tos-generator/frameworks/gdpr-ccpa-requirements.md · v0.1.0_