<purpose>
הראיון המובנה של ה-prd-generator: 8-10 שאלות בסדר קבוע שמטרתן לחלץ מהמשתמש את כל המידע שנדרש כדי לכתוב PRD שמוכן ל-`build-product` ול-`writing-plans`.
</purpose>

<user-story>
As a founder/PM, I want to be asked 8-10 sharp questions in a fixed order, so that I give the right answers in one pass and the generated PRD has no critical gaps.
</user-story>

<when-to-use>
- User runs `/prd-generator new`
- User explicitly asks "תכתוב PRD" / "תעשה לי spec" / "תייצר מסמך דרישות"
- Always loaded at the start of every PRD generation session

</when-to-use>

<context>
@../tasks/prd-template.md (the artifact this interview feeds into — keep this open mentally so each answer maps to a section)
</context>

<references>
@../frameworks/open-questions-catalog.md (when a question is fuzzy, pick the matching entry from the catalog)
@../references/prd-examples.md (rare — only if the user wants to see a worked example mid-interview)
</references>

<steps>

<step name="warmup_one_liner" priority="first">
**שאלה 1 — The one-liner (sanity check).**

> "תן לי משפט אחד שמתאר את המוצר. לא 'זה כמו X רק עם Y' — רק מה הוא עושה ולמי. אם אין לך משפט אחד, יש לך רעיון, לא מוצר."

דוגמאות של תשובות טובות:
- ✅ "App למסעדות שמאפשר ללקוחות להזמין שולחן בלי לחייג"
- ✅ "CLI tool למפתחים שמוחק קבצים ישנים מ-`node_modules` אוטומטית"
- ❌ "משהו כמו Notion אבל טוב יותר" → "Notion עושה 50 דברים. איזה 1 מהם אתה רוצה לעשות טוב יותר?"

**Wait for the one-liner.**

</step>

<step name="user_persona">
**שאלה 2 — Who is the user.**

> "מי בדיוק המשתמש? לא 'אנשים' או 'מפתחים' — מי ספציפית. גיל, תפקיד, מיקום, מה הוא עושה היום במקום מה שהמוצר שלך יעשה."

הוצא את התשובה מ-"כולם" → "ספציפי":
- ❌ "מפתחים" → "מפתחי full-stack בודדים שעובדים על TypeScript וכותבים ב-VS Code"
- ❌ "עסקים קטנים" → "בעלי מסעדות עם 1-3 סניפים בתל אביב שלא משתמשים ב-Google Forms"

**Wait for user definition.**

</step>

<step name="core_problem">
**שאלה 3 — The pain.**

> "מה הבעיה הקונקרטית שהמשתמש הזה פותר היום? לא 'חוסר יעילות' — מה הוא באמת עושה עכשיו, ואיפה זה כואב?"

Push-back rules:
- אם התשובה היא "אין כלום, הוא לא עושה את זה היום" → "איך הוא בכלל חי בלי זה? מה ה-workaround הידני?"
- אם התשובה היא "משתמש ב-X" → "מה לא טוב ב-X? תן 2 דברים ספציפיים."

**Wait for pain description.**

</step>

<step name="mvp_feature_set">
**שאלה 4 — The one thing that has to work.**

> "אם היית צריך להראות למשתמש את המוצר ולהגיד 'זה עובד, תשלם' — מה ה-feature היחיד שחייב לעבוד? לא 5 features. אחד. אם אתה לא יכול לבחור אחד, זה אומר שאתה לא יודע מה ה-core."

Examples of good answers:
- ✅ "הזמנת שולחן בלי לחייג — כל השאר הוא bonus"
- ✅ "מחיקת `node_modules` לפי גודל, אוטומטית, בלי prompt"
- ❌ "Login + profile + dashboard + search + notifications" → "זה 5 מוצרים. בחר אחד."

**Wait for the core feature.**

</step>

<step name="user_flow">
**שאלה 5 — The happy path.**

> "תאר את ה-flow מהרגע שהמשתמש פותח את ה-app ועד שהוא מסיים את ה-[feature משאלה 4]. צעד-צעד. כמה שלבים, מה קורה בכל שלב."

Push-back:
- אם ה-flow קצר מדי (1-2 צעדים) → "יש עוד שלבים. מה קורה לפני שהוא רואה את התוצאה? טעינה? ולידציה? שמירה?"
- אם ה-flow ארוך מדי (8+ צעדים) → "זה לא MVP. מה אפשר לחתוך?"

**Wait for the flow.**

</step>

<step name="edge_cases">
**שאלה 6 — What breaks.**

> "מה המקרים שה-flow שלך לא מטפל בהם? מה קורה כש-[X] לא קיים, לא נטען, או נכשל?"

סוגי edge cases שחייבים לעלות:
- **Network failures** — מה אם אין אינטרנט? אם ה-API מחזיר 500?
- **Empty states** — מה קורה כשאין נתונים? (משתמש חדש, חיפוש ריק)
- **Invalid input** — מה אם המשתמש מזין משהו לא חוקי?
- **Permissions/Auth** — מה אם הוא לא logged in? אם ה-token פג?
- **Concurrent** — מה אם 2 משתמשים עושים את אותו דבר באותו זמן? (לרוב לא רלוונטי ל-MVP, אבל תשאל)

**Wait for edge cases.**

</step>

<step name="out_of_scope">
**שאלה 7 — What's NOT in the MVP.**

> "מה בכוונה לא ב-MVP? איזה features אתה יודע שתצטרך בעוד 6 חודשים אבל לא עכשיו?"

זו השאלה הכי קשה — רוב האנשים מדלגים עליה. אם המשתמש לא נותן תשובה:
- "תגיד 3 דברים שאתה מתפתה להוסיף אבל יודע שלא צריך עכשיו. גם אם זה נשמע חשוב."

**Wait for out-of-scope list.**

</step>

<step name="success_criteria">
**שאלה 8 — How do you know it works.**

> "איך אתה יודע שה-MVP הצליח? לא 'יהיו משתמשים' — מספר, מדד, תאריך. 'תוך 30 יום 50 אנשים ישלמו' / 'יהיו 100 רשומים בשבוע הראשון' / 'הזמנתי יהיה ב-5 שניות'."

אם התשובה היא איכותית בלבד ("יהיה טוב") → "תן מספר. כל דבר שאפשר למדוד."

**Wait for success metric.**

</step>

<step name="tech_constraints">
**שאלה 9 — Constraints (optional but recommended).**

> "יש constraints טכניים שכבר ידועים לך? Stack קיים שחייבים להשתמש בו? API חיצוני שכבר בחרת? Compliance (GDPR / HIPAA / רגולציה ישראלית)?"

אם אין → "אז הסקיל הבא (`build-product`) יחליט. OK."

**Wait for constraints or "no".**

</step>

<step name="open_questions_check">
**שאלה 10 — Surfacing the unknowns.**

> "יש עוד משהו שאתה יודע שאתה לא יודע? שאלה שאתה לא יכול לענות עליה עכשיו אבל היא קריטית?"

עבור על התשובות ל-9 השאלות הקודמות. לכל פער, שאל:
- "אתה יודע לענות על זה עכשיו, או שזה Open Question?"

פלט סופי של צעד זה = רשימת Open Questions ממוספרת (OQ-1, OQ-2, ...) שייכתב בסעיף Open Questions ב-PRD.

**Wait for the final open questions list.**

</step>

<step name="confirmation">
לפני שמתחילים לכתוב:

> "יש לי 10 תשובות. הולך לייצר `plans/PRD-<name>.md` עכשיו. השם של המוצר יהיה `[X]` (מה-one-liner), תקן אותי אם לא. אישור?"

**Wait for confirmation. If user adjusts the name, use the new name for the file.**

</step>

</steps>

<output>
## Artifact
A complete set of answers to all 10 questions, captured in the conversation, ready to be fed into `@tasks/generate-prd.md`.

## Location
- Captured in conversation memory (not written to disk yet)
- Will be assembled into `plans/PRD-<slug>.md` by `@tasks/generate-prd.md`

## Minimum answer quality
- Every question has at least one concrete sentence (not "TBD")
- Vague answers like "יהיה טוב" are pushed back on immediately, never accepted
- Open questions are explicitly enumerated, not hidden
</output>

<acceptance-criteria>
- [ ] All 10 questions asked in order (no skipping, no reordering)
- [ ] No "TBD" / "נראה לאחר מכן" answers accepted — push-back applied
- [ ] Core feature (Q4) is exactly one feature, not a list
- [ ] User flow (Q5) is 2-7 steps, not a wall of prose
- [ ] Out-of-scope (Q7) has at least 2 items
- [ ] Success metric (Q8) has a number
- [ ] Open questions (Q10) are enumerated (OQ-1, OQ-2, ...)
- [ ] User confirmed the product name + file path before generation starts
</acceptance-criteria>

---

*Task maintained by prd-generator skill · Built with Skillsmith*
<!-- skillsmith_version: 1.0.0 -->
