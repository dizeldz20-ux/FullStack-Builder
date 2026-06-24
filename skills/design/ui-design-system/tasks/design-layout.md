<purpose>
The first phase of UI design — create an ASCII wireframe of the page. This is the most important phase because it forces structure before pixel-level work.
</purpose>

<user-story>
As the user who wants to design a new UI, I want to first see the layout as a wireframe (no styling, no code), so we can agree on structure before I start coding.
</user-story>

<when-to-use>
- "תתחיל מ-wireframe"
- "תראה לי את המבנה של העמוד"
- Before any new page or significant UI change

NOT for: small UI tweaks (color change, font size) — skip straight to implementation.
</when-to-use>

<context>
None — this task is self-contained.
</context>

<references>
@frameworks/layout-patterns.md (ready-made wireframes for common page types)
@frameworks/component-patterns.md (component code for after the wireframe is approved)
</references>

<steps>

<step name="identify_page_type">
What kind of page are we designing?

| Type | Examples |
|---|---|
| **Landing page** | Marketing, product home, pricing, about |
| **Dashboard** | Admin, analytics, user portal |
| **Form page** | Login, signup, settings, checkout |
| **Detail page** | Blog post, product detail, profile |
| **List page** | Search results, table of items |
| **Modal/overlay** | Confirmation, quick action |

Pick one. Each has a different default structure.
</step>

<step name="list_sections">
In order, top to bottom, what sections does this page need?

**Landing page** typically has: Header → Hero → Features → Social proof → Pricing → FAQ → Final CTA → Footer
**Dashboard** typically has: Top nav → Sidebar → Main content (stats + table)
**Form page** typically has: Logo → Title → Form fields → Submit button → Secondary link

Not every page needs every section. **Pick what's right for THIS page.**
</step>

<step name="sketch_wireframe">
Use ASCII art to draw the layout. 30 seconds max.

**Template:**

```text
┌─────────────────────────────────────┐
│         HEADER / NAV BAR            │
├─────────────────────────────────────┤
│                                     │
│            HERO SECTION             │
│         (Title + CTA)               │
│                                     │
├─────────────────────────────────────┤
│   FEATURE   │  FEATURE  │  FEATURE  │
│     CARD    │   CARD    │   CARD    │
├─────────────────────────────────────┤
│            FOOTER                   │
└─────────────────────────────────────┘
```

**Rules:**
- Use `─`, `│`, `┌`, `┐`, `└`, `┘` for boxes
- Use words for content (no styling)
- Keep it high-level (sections, not components)
- One wireframe per page (or per major change)

**Use @frameworks/layout-patterns.md** for ready-made wireframes if the page type is common.
</step>

<step name="get_approval">
**DO NOT code before the user approves.**

Show the wireframe to the user. Ask:
- "האם המבנה הזה עובד?"
- "משהו חסר? משהו מיותר?"
- "סדר הסקציות הגיוני?"

If the user says "yes" → continue to phase 2 (theme).
If the user says "change X" → redo the wireframe, get approval again.
</step>

</steps>

<output>
## Artifact
ASCII wireframe (text), approved by the user.

## Format
- In chat (easiest)
- In a `.md` file
- Rendered to image (if needed for stakeholders)

## Location
Stored in the project's design folder, or in chat.
</output>

<acceptance-criteria>
- [ ] Wireframe is in ASCII (not styled HTML)
- [ ] All sections are listed in order
- [ ] Wireframe is approved by the user
- [ ] Component list is clear (header, hero, cards, etc.)
</acceptance-criteria>
