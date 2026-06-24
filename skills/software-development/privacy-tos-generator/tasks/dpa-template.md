# Data Processing Agreement (DPA) Template · v0.1.0

> ⚠️ **DISCLAIMER / כתב ויתור**
> **This is template boilerplate, not legal advice. Consult a lawyer before going to production.**
> זהו תבנית בסיסית (boilerplate), לא ייעוץ משפטי. התייעץ עם עורך דין לפני הפעלה בפרודקשן.
> DPA הוא הסכם מורכב; ה-template הזה נקודת פתיחה בלבד.

## מתי צריך DPA / When you need a DPA

אם לקוחות שלך (B2B) מעלים את **המשתמשים שלהם** למוצר שלך — אתה ה-Data Processor שלהם.
If your B2B customers upload **their users'** data to your product — you are their Data Processor.

לדוגמה: אתה בונה CRM, לקוח מעלה רשימת לקוחות שלו. הוא ה-Controller, אתה ה-Processor.
Example: you build a CRM, customer uploads their customer list. They are Controller, you are Processor.

GDPR Art. 28 **מחייב** חוזה בכתב בין Controller ל-Processor עם סעיפים מסוימים.
GDPR Art. 28 **requires** a written contract between Controller and Processor with specific clauses.

תבנית זו מבוססת על דרישות GDPR Art. 28 + סעיפי SCCs הסטנדרטיים של ה-EU Commission.
This template covers GDPR Art. 28 + the EU Commission Standard Contractual Clauses (SCCs).

---

## Placeholders

- `[COMPANY_NAME]` — your company (Processor)
- `[CUSTOMER_NAME]` — the B2B customer (Controller)
- `[SERVICE_NAME]` — your product
- `[EFFECTIVE_DATE]`
- `[JURISDICTION]` — governing law
- `[SUBPROCESSOR_LIST_URL]` — where the live subprocessor list is hosted
- `[SECURITY_MEASURES_URL]` — your security page / SOC2 report location
- `[BREACH_NOTIFICATION_HOURS]` — typically 24 or 48
- `[DATA_RETURN_DAYS]` — typically 30

---

## The Template

```markdown
# Data Processing Agreement (DPA)

This Data Processing Agreement ("DPA") is entered into between:

**[CUSTOMER_NAME]** ("Controller")
and

**[COMPANY_NAME]** ("Processor")

and forms part of the [Master Service Agreement / Terms of Service] between
the parties (the "Agreement").

**Effective date:** [EFFECTIVE_DATE]

## 1. Definitions

- **"Personal Data"** — has the meaning given in GDPR Art. 4(1).
- **"Processing"** — has the meaning given in GDPR Art. 4(2).
- **"Data Subject"** — an identified or identifiable natural person.
- **"Subprocessor"** — any third party engaged by Processor to process
  Personal Data on behalf of Controller.
- **"Controller", "Processor", "Supervisory Authority"** — as defined in GDPR Art. 4.

Capitalized terms not defined here have the meanings given in the Agreement.

## 2. Subject and duration of Processing

### 2.1 Subject
Processor will process Personal Data only for the purpose of providing the
Service to Controller, as described in the Agreement and any
Statement of Work.

### 2.2 Duration
Processing will continue for the term of the Agreement. Upon termination,
Processor will delete or return Personal Data per Section 8.

### 2.3 Categories of Data
- **Data Subjects:** [e.g. Controller's end users / customers / employees]
- **Categories of Personal Data:** [e.g. name, email, usage data]
- **Special categories:** [None / list any GDPR Art. 9 data]

## 3. Controller's instructions

Processor will:
- Process Personal Data only on documented instructions from Controller,
  including with regard to transfers (unless required by EU or Member State law)
- Inform Controller if, in Processor's opinion, an instruction infringes GDPR

Controller instructs Processor to process Personal Data as necessary to
provide the Service per the Agreement.

## 4. Confidentiality

Processor ensures that persons authorized to process Personal Data have
committed to confidentiality or are under a statutory obligation of
confidentiality.

## 5. Security of Processing (Art. 32)

Processor implements appropriate technical and organizational measures to
ensure a level of security appropriate to the risk, including:

- Encryption of Personal Data in transit (TLS 1.2+) and at rest (AES-256)
- Ongoing confidentiality, integrity, availability, and resilience of systems
- Regular testing and evaluation of effectiveness
- Access controls based on least-privilege and role
- Pseudonymization where applicable

Full description available at: [SECURITY_MEASURES_URL]

## 6. Subprocessors

### 6.1 General authorization
Controller provides a general authorization for Processor to engage
Subprocessors, subject to the requirements of this Section.

### 6.2 Current list
A current list of Subprocessors is published at: [SUBPROCESSOR_LIST_URL]

### 6.3 Notification of changes
Processor will notify Controller of any intended changes concerning the
addition or replacement of Subprocessors at least [30] days in advance.
Controller may object on reasonable data protection grounds; if the parties
cannot resolve the objection, Controller may terminate the affected services.

### 6.4 Subprocessor obligations
Processor imposes on each Subprocessor data protection terms no less
protective than those in this DPA, including sufficient guarantees to
implement appropriate technical and organizational measures.

## 7. Assistance to Controller

Processor will, taking into account the nature of processing, assist
Controller by appropriate technical and organizational measures (including
security incident response) to fulfill Controller's obligations to:

- Respond to Data Subject requests under GDPR Chapter III (access, deletion,
  portability, etc.)
- Conduct Data Protection Impact Assessments (Art. 35)
- Consult with Supervisory Authorities (Art. 36)
- Notify breaches (Art. 33-34)

If Controller's request is repetitive or excessive, Processor may charge a
reasonable fee.

## 8. Data Subject rights

Processor will, on Controller's request, provide reasonable assistance to
help Controller respond to Data Subject requests, as described in Section 7.

## 9. Personal Data breach notification

Processor will notify Controller without undue delay, and in any event
within [BREACH_NOTIFICATION_HOURS] hours, after becoming aware of a Personal
Data breach affecting Controller's Personal Data. The notification will
include, to the extent available:

- Nature of the breach (categories and approximate numbers of Data Subjects/records)
- Name and contact details of Processor's contact point
- Likely consequences
- Measures taken or proposed to address the breach and mitigate adverse effects

## 10. Return or deletion at end of processing

At the choice of Controller, upon termination of the Agreement, Processor will:

(a) Return Personal Data to Controller in a commonly used machine-readable format, or
(b) Delete Personal Data, including all copies,

unless Union or Member State law requires storage of the Personal Data.

Deletion will be completed within [DATA_RETURN_DAYS] days of termination.

## 11. Audit rights

Processor will make available to Controller all information necessary to
demonstrate compliance with this DPA, and allow audits, including
inspections, conducted by Controller or another auditor mandated by
Controller, with reasonable prior notice and during business hours, subject
to confidentiality obligations.

Audits are limited to once per [12-month] period unless a Personal Data
breach has occurred or a competent Supervisory Authority requires otherwise.

## 12. International transfers (Chapter V)

If Personal Data is transferred outside the EEA, UK, or other jurisdiction
with an adequacy decision, Processor will implement appropriate safeguards,
which may include:

- Standard Contractual Clauses (EU Commission Decision 2021/914)
- UK International Data Transfer Addendum (where applicable)
- EU-US Data Privacy Framework certification of recipient

Processor's current transfer mechanisms are documented at [TRANSFER_MECHANISMS_URL].

## 13. Liability

Liability under this DPA is subject to the limitation of liability set
forth in the Agreement, except where such limitation is prohibited by GDPR
or applicable law.

## 14. Order of precedence

In the event of conflict between this DPA and the Agreement regarding the
processing of Personal Data, this DPA prevails.

## 15. Governing law

This DPA is governed by the laws of [JURISDICTION], without regard to
conflict-of-laws principles.

## 16. Standard Contractual Clauses (if applicable)

If the SCCs (Module 2: Controller-to-Processor) are incorporated by
reference or attached, they apply to any transfer of Personal Data from
the EEA to a jurisdiction without an adequacy decision.

Annexes to the SCCs (Annex I: list of parties; Annex II: technical and
organizational measures; Annex III: subprocessors) are attached as
Appendices A, B, and C.

---

## Signatures

**CONTROLLER:** [CUSTOMER_NAME]

By: __________________________
Name:
Title:
Date:

**PROCESSOR:** [COMPANY_NAME]

By: __________________________
Name:
Title:
Date:
```

---

## Appendices (attach separately)

### Appendix A — List of Parties (SCCs Annex I.A)

| Role | Name | Address | Contact | Signature |
|---|---|---|---|---|
| Controller | [CUSTOMER] | [ADDR] | [DPO EMAIL] | — |
| Processor | [COMPANY] | [ADDR] | [DPO EMAIL] | — |

### Appendix B — Technical and Organizational Measures (SCCs Annex II)

Reference your security page: `[SECURITY_MEASURES_URL]`

### Appendix C — Subprocessors (SCCs Annex III)

Reference your subprocessor list: `[SUBPROCESSOR_LIST_URL]`

---

## Checklist / רשימת בדיקה

- [ ] החלפת כל ה-[PLACEHOLDERS] / replaced placeholders
- [ ] צירפת את 3 ה-Appendices / attached 3 appendices
- [ ] רשימת Subprocessors מעודכנת / subprocessor list current
- [ ] breach notification timeline מקובל עליך / breach notification timeline acceptable
- [ ] audit rights לא רחבות מדי / audit rights not too broad
- [ ] סעיף 12 (transfers) רלוונטי / Section 12 relevant (if cross-border)
- [ ] **עורך דין שלך עיין + עורך דין של הלקוח עיין / your lawyer + customer's lawyer reviewed**

---

## טיפים / Tips

1. **DPA is non-negotiable for B2B SaaS in EU.** Prospects will ask. Have it ready.
2. **Many enterprise customers will send their own DPA.** Have yours ready as a counter-proposal.
3. **SCCs (Module 2 or 3)** — if you sub-process outside EEA, you need SCCs in your DPA. The text is long; lawyers prefer to incorporate by reference to the EU Commission Decision 2021/914.
4. **Don't promise specific security certifications unless you have them.** Saying "SOC2 Type II" when you don't have it is fraud.
5. **Audit clause** — limit to once per year, with notice, during business hours, at Controller's expense. Otherwise you'll be in audit hell.

---

_footer: privacy-tos-generator/tasks/dpa-template.md · v0.1.0_