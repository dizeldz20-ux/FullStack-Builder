# When to Call a Lawyer · v0.1.0

> ⚠️ **DISCLAIMER / כתב ויתור**
> **This is template boilerplate, not legal advice. Consult a lawyer before going to production.**
> זהו תבנית בסיסית (boilerplate), לא ייעוץ משפטי. התייעץ עם עורך דין לפני הפעלה בפרודקשן.
> רשימה זו אינה ממצה — אם יש ספק, התייעץ.

## למה הרשימה הזו / Why this list exists

Templates שלנו מיועדים ל-MVP של SaaS שלא נוגע ברגולציה מורכבת.
Our templates are for MVPs that don't touch complex regulation.

אם אתה באחד מהמקרים למטה, **עצור וקח עורך דין לפני launch**.
If you're in any of these situations, **stop and get a lawyer before launch**.

זה לא כישלון — זה אחריות. וזה גם חובה חוקית ברוב המקרים.
This isn't failure — it's responsibility. And it's also legally required in most cases.

---

## 🚨 תמיד עורך דין / Always a lawyer

### 1. You're in a regulated industry
- **Health / medical** → HIPAA (US), or equivalents in EU/IL
- **Finance / banking / payments** → PCI-DSS, GLBA, financial regulator licenses
- **Education (K-12 students)** → FERPA (US), COPPA, GDPR Art. 8
- **Children's products** (under 13 US, under 16 EU) → special rules
- **Insurance** → various state regulations
- **Law / legal services** → professional privilege rules
- **Pharma / medical devices** → FDA / CE marking implications
- **Gambling / adult content** → license + age verification + jurisdictional restrictions

**Why:** industry-specific laws add layers on top of GDPR/CCPA. The templates here don't cover them.

### 2. You handle "special categories" of data (GDPR Art. 9)
- Health data
- Racial or ethnic origin
- Political opinions
- Religious or philosophical beliefs
- Trade union membership
- Genetic data
- Biometric data (for identification)
- Sex life or sexual orientation

**Why:** requires explicit consent, higher security, often DPO mandatory.

### 3. You do automated decision-making with legal or significant effects (GDPR Art. 22)
- Credit scoring
- Hiring decisions
- Insurance pricing
- Access to services

**Why:** requires explanation, human review, and specific safeguards.

### 4. You do large-scale systematic monitoring
- Ad networks
- Cross-site tracking
- Workplace monitoring
- Public area surveillance (CCTV at scale)

**Why:** triggers mandatory DPO appointment + DPIA requirement.

---

## 🚨 כנראה עורך דין / Probably a lawyer

### 5. You sell to enterprise / B2B customers in EU
Enterprise customers will have their own DPA, security questionnaires, and contract requirements.
לקוחות ארגוניים ידרשו DPA משלהם, שאלוני אבטחה, ודרישות חוזה.

**Specifically:**
- Their legal team will send you redlines. You need a lawyer who can respond.
- They may require specific certifications (SOC2, ISO27001).
- They'll want specific insurance coverage (cyber liability, E&O).
- They'll want audit rights, indemnification caps, liability carve-outs.

**Template that's NOT enough:** `tasks/dpa-template.md` is a starting point, not a final contract for an enterprise deal.

### 6. You handle payments at scale
PCI-DSS scope depends on integration model:
- **Stripe Elements / Checkout** → most PCI scope stays with Stripe. Lower risk.
- **Stripe.js tokenization** → some scope on you.
- **Raw cardholder data** → full PCI-DSS scope. You need a QSA.

**If you process > 6M transactions/year or > 1M Visa transactions** → Visa's Global Registry Listing may apply.

### 7. You're publicly traded or planning an IPO
SEC disclosure requirements + SOX compliance + heightened data governance.

### 8. You have employees (not just contractors) in the EU/UK/IL
- Employment contracts must be jurisdiction-specific
- Works councils, GDPR employee monitoring rules
- Local statutory requirements

### 9. You transfer data to countries without adequacy (China, Russia, India, most of LatAm)
- Cross-border data localization rules may apply
- Need specific transfer mechanism + legal opinion
- China PIPL, Russia 152-FZ, India DPDP Act have specific requirements

### 10. You use AI/ML for decisions about people
- EU AI Act (2024) classifications: prohibited, high-risk, limited risk
- Automated employment decisions, credit scoring, biometric ID — high risk
- Disclosure obligations, human oversight requirements, bias audits

### 11. You're a "data broker" or sell data
Multiple US state laws (Vermont, Texas, Oregon) have broker registration requirements.
GDPR requires explicit consent.

### 12. You had a data breach
- 72-hour notification to supervisory authority
- Specific content requirements
- Need breach coach / cyber-insurance adjuster
- **Don't lawyer-up after the fact. Have counsel on retainer.**

---

## 🚨 כדאי עורך דין / Should probably lawyer

### 13. You're launching in a new jurisdiction
Each country adds:
- Local language requirements for privacy policy
- Local cookie / ePrivacy rules
- Local data residency rules
- Local consumer protection laws (right of withdrawal, etc.)
- Local employment laws (if hiring)

### 14. You have open-source dependencies that copy user data
If a vendor's SDK scrapes or exfiltrates data, you may be liable. License review + DPA review needed.

### 15. Your service stores user-generated content at scale
DMCA (US) / equivalent safe harbor requires:
- Designated agent registration
- Takedown procedure
- Repeat infringer policy

---

## 🚨 אולי לא צריך עורך דין (אבל כן אם...) / Maybe you don't (but still if...)

You might be OK with templates only if **ALL** of these are true:

- [ ] You're a solo founder / tiny team
- [ ] Your service is B2B SaaS, not consumer
- [ ] You have < 1000 users
- [ ] No special categories of data (no health, biometrics, etc.)
- [ ] No automated decisions about people
- [ ] No employees in EU/UK/IL (just contractors)
- [ ] You use Stripe / similar for payments (not raw cardholder data)
- [ ] No minors
- [ ] You're not in a regulated industry
- [ ] You're not planning to raise VC / sell the company soon

**Even then:** have a lawyer review before public launch. Many offer a "doc review" for $500-2000.

---

## How to find a lawyer / איפה מוצאים

### Privacy-specialized firms
- **OneTrust DataGuidance** — directory
- **IAPP directory** — https://iapp.org/about/why-iapp/member-directory/
- **Your local Bar Association** — privacy section
- **YC's GC list** — for startups; ask your batch

### Israel
- **פורום הגנת הפרטיות של לשכת עורכי הדין**
- **רשות הגנת הפרטיות** — PPA website has some guidance

### Cost ranges (very rough, 2026)

| Service | Range USD |
|---|---|
| Doc review of our templates | $500-2,000 |
| Custom Privacy Policy | $1,500-5,000 |
| Custom Terms of Service | $1,500-5,000 |
| DPA negotiation per customer | $2,000-10,000 |
| Full legal stack (privacy + ToS + DPA + IP assignment) | $5,000-25,000 |
| Annual ongoing legal counsel (startup retainer) | $5,000-30,000/yr |

Cost of NOT having a lawyer when you needed one: a GDPR fine is **€20M or 4% of revenue**. Pick your battles.

---

## Templates vs. lawyer — decision tree

```
START → Are you in a regulated industry? (health/finance/etc.)
  ├─ YES → LAWYER (always)
  └─ NO → Do you handle special categories of data?
        ├─ YES → LAWYER (always)
        └─ NO → Do you do automated decision-making with significant effects?
              ├─ YES → LAWYER (probably)
              └─ NO → Do you have enterprise customers in EU?
                    ├─ YES → LAWYER (for DPA negotiation per customer)
                    └─ NO → Are you launching with public users?
                          ├─ YES → Templates + lawyer review ($500-2k)
                          └─ NO (closed beta) → Templates might be enough
                                                for now; lawyer before
                                                public launch
```

---

## Final note

**Templates exist to get you to "good enough for a first conversation with a lawyer," not "good enough for production."**

If your instinct is "I should ask a lawyer," ask a lawyer.
If you're reading this thinking "I don't think I need one for my specific case," you're probably right — but **document why you don't**, so you can show good-faith effort later.

Regulators don't expect founders to be lawyers. They expect founders to:
1. Make reasonable efforts to comply
2. Know when they're out of their depth
3. Document their decisions
4. Get professional help when needed

This skill helps with #1 and #3. It does not replace #2 and #4.

---

_footer: privacy-tos-generator/references/when-to-call-a-lawyer.md · v0.1.0_