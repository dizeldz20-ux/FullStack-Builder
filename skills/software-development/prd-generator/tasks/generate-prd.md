<purpose>
לקחת את 10 התשובות מ-`@tasks/interview-questions.md` ולייצר מהן קובץ PRD מובנה ב-`plans/PRD-<name>.md` שמוכן להיות consumed על ידי `build-product` ו-`writing-plans`.
</purpose>

<user-story>
As a founder/PM, I want my interview answers turned into a structured PRD file, so that the next skill (`build-product`) can pick it up and start building without asking the same questions again.
</user-story>

<when-to-use>
- After `/prd-generator new` interview is complete and confirmed
- When user pastes a set of 10 answers from a previous interview and asks to assemble them
- NEVER run this task standalone — always preceded by `interview-questions.md`

</when-to-use>

<context>
@../tasks/interview-questions.md (the source — 10 answers)
@../tasks/prd-template.md (the target structure — copy this verbatim, fill placeholders)
@../frameworks/prd-quality-checklist.md (self-review at the end)
@../frameworks/open-questions-catalog.md (cross-reference any OQ-N to a catalog entry)
@../references/prd-examples.md (only if a "what good looks like" check is needed)
</context>

<references>
@../frameworks/prd-quality-checklist.md (Phase 3 — self-audit)
</references>

<steps>

<step name="derive_metadata" priority="first">
**צעד 1 — Derive file metadata.**

מהתשובות:
- **Product name (slug)**: מ-Q1 one-liner → הפוך ל-kebab-case, מקסימום 4 מילים. דוגמה: "App להזמנת שולחנות במסעדות" → `restaurant-table-booking`.
- **Date**: תאריך היום (YYYY-MM-DD).
- **Owner**: שם המשתמש (default: "the user" אם לא צוין).
- **File path**: `plans/PRD-<slug>.md`

אם קובץ עם אותו שם קיים → הוסף סיומת `-v2`, `-v3` וכו'. לא לדרוס.

**Verify the directory exists:** `mkdir -p plans` (relative to CWD).

</step>

<step name="load_template">
**צעד 2 — Load the template.**

Load @../tasks/prd-template.md. עותק verbatim של המבנה. כל סעיף ב-template = placeholder למלא.

הכלל: **לא לסטות מהמבנה של ה-template**. גם אם ה-PRD קצר — כל הסעיפים חייבים להופיע. סעיף ריק = "ראה Open Questions" + reference ל-OQ-N.

</step>

<step name="fill_sections">
**צעד 3 — Fill each section from the answers.**

מיפוי קבוע של Q-N → section:

| Q | תשובה | Section ב-PRD |
|---|-------|----------------|
| Q1 | one-liner | TL;DR + Product Name |
| Q2 | user persona | Target User |
| Q3 | pain | Problem Statement |
| Q4 | core feature | Core Feature (MVP) — רק feature אחד |
| Q5 | user flow | User Flow |
| Q6 | edge cases | Edge Cases & Failure Modes |
| Q7 | out-of-scope | Out of Scope (MVP) |
| Q8 | success metric | Success Metrics |
| Q9 | tech constraints | Technical Constraints (או "To be decided by `build-product`") |
| Q10 | open questions | Open Questions (OQ-1, OQ-2, ...) |

**כללי כתיבה:**
- **Inferrable vs Invented:** אם Q-N לא ענה על משהו שה-template דורש (למשל "Assumptions") — תכתוב את זה ב-Assumptions, אבל סמן בסימן `[inferred]` בתחילת הפסקה. אם זה לא ניתן ל-infer (למשל target price) → Open Question.
- **No invented features:** אם המשתמש לא הזכיר login, אל תכתוב login. אם הוא הזכיר רק "dashboard" בלי לפרט → "Dashboard (details TBD — see OQ-3)".
- **Tables > bullets** לכל דבר שיש בו 3+ שדות.
- **Hebrew body, English for tech terms.** "API", "endpoint", "MVP", "flow" — באנגלית. כל השאר בעברית.

</step>

<step name="open_questions_format">
**צעד 4 — Format Open Questions section.**

כל OQ-N:
```markdown
### OQ-1: [שאלה קצרה]
- **Context:** [למה זה עלה, איזה סעיף ב-PRD זה חוסם]
- **Blocks:** [איזה sections / decisions ממתינים לתשובה]
- **Suggested resolution:** [איך לברר — research, spike, ask user]
- **Priority:** [P0 / P1 / P2] — P0 = חוסם MVP, P1 = חוסם V1.1, P2 = nice-to-know
```

לכל OQ, בדוק אם יש התאמה ב-@../frameworks/open-questions-catalog.md. אם כן — ציין את ה-catalog entry.

</step>

<step name="acceptance_criteria_extraction">
**צעד 5 — Extract acceptance criteria from Q5 (flow) + Q6 (edge cases).**

עבור כל צעד ב-user flow → צרף `- [ ]` criterion שאומר "משתמש יכול לעשות X".
עבור כל edge case ב-Q6 → צרף "- [ ] כאשר X קורה, המערכת Y" criterion.

Acceptance Criteria section מכיל בין 5-15 items. אם יש יותר — חתוך non-essential. אם פחות — הוסף מ-Q6 (edge cases).

</step>

<step name="self_audit" priority="last">
**צעד 6 — Self-audit against quality checklist.**

Load @../frameworks/prd-quality-checklist.md. עבור על כל הסעיפים. אם משהו חסר:
1. תקן inline
2. אם לא ניתן לתקן (חסר מידע) → הוסף OQ-N

לפני שמסיימים, הרץ mentally:
- [ ] TL;DR עונה על "מי, מה, למה" ב-2 משפטים?
- [ ] Out of Scope מכיל 2+ items?
- [ ] כל flow step יש לו acceptance criterion?
- [ ] Edge cases מכוסים (לפחות 3: network, empty, invalid input)?
- [ ] Success metric has a number?
- [ ] Open Questions ממוספרים ויש להם priority?
- [ ] User persona is specific, not "אנשים"?
- [ ] אין features שלא הוזכרו ב-Q4 (no invention)?

</step>

<step name="write_and_confirm">
**צעד 7 — Write the file + report.**

1. **Write:** `plans/PRD-<slug>.md` עם התוכן המלא.
2. **Show the user:** הצג path + 5 השורות הראשונות + 5 השורות האחרונות + רשימת ה-Open Questions.
3. **Suggest next step:** "ה-PRD מוכן. הצעד הבא — `/build-product new` (יטען את ה-PRD אוטומטית). או `/plan` אם רק רוצה implementation plan בלי build."

</step>

</steps>

<output>
## Artifact
A complete PRD markdown file, written to `plans/PRD-<slug>.md`, structured per `@tasks/prd-template.md`, ready for handoff to `build-product` / `writing-plans`.

## File structure
- `plans/` directory (created if missing)
- `PRD-<slug>.md` — kebab-case slug, max 4 words
- Versioning: if file exists → `-v2`, `-v3` suffix

## Minimum content
- All template sections present (no missing sections, even if empty)
- Open Questions enumerated OQ-1 ... OQ-N with priority
- Acceptance criteria extracted from flow + edge cases
- No invented features (only what was stated in Q4)

</output>

<acceptance-criteria>
- [ ] File written to `plans/PRD-<slug>.md`
- [ ] All template sections present
- [ ] Open Questions enumerated OQ-1 ... OQ-N
- [ ] Acceptance criteria: 5-15 items, extracted from flow + edge cases
- [ ] No invented features — every feature traces to Q4 or explicit user statement
- [ ] User informed of: path, Open Questions list, suggested next step
- [ ] No overwrite of existing file (versioned with -v2, -v3)
</acceptance-criteria>

---

*Task maintained by prd-generator skill · Built with Skillsmith*
<!-- skillsmith_version: 1.0.0 -->
