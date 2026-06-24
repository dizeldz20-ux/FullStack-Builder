<purpose>
Run the FULL 4-phase UI design flow: Layout → Theme → Animation → Implementation. Use this for new products / new pages / significant UI changes.
</purpose>

<user-story>
As the user who wants to design a complete UI from scratch, I want one command that walks me through all 4 phases (wireframe → theme → animations → code), so I get a consistent, well-designed UI without having to think about which skill to load.
</user-story>

<when-to-use>
- "תעצב לי [landing page / dashboard / form]"
- "אני רוצה UI חדש"
- "תבנה לי UI מ-אפס"

NOT for: small UI tweaks (color change, font size) — just edit the existing component.
</when-to-use>

<context>
None — this task is self-contained.
</context>

<references>
@frameworks/layout-patterns.md (during phase 1)
@frameworks/theme-templates.md (during phase 2)
@frameworks/animation-micro-syntax.md (during phase 3)
@frameworks/component-patterns.md (during phase 4)
@frameworks/font-catalog.md (during phase 2)
@frameworks/responsive-breakpoints.md (during phase 4)
@frameworks/accessibility-checklist.md (during phase 4)
@references/quick-reference.md (copy-paste)
</references>

<steps>

<step name="phase1_layout" priority="first">
**Goal:** ASCII wireframe of the page in 30 seconds.

1. **Identify the page type** (landing, dashboard, form, pricing, blog)
2. **Sketch the sections** in order (header → content → footer)
3. **Add content placeholders** (headline, subhead, CTA, cards)
4. **Show the user** and get explicit approval before coding

**Use @frameworks/layout-patterns.md** for ready-made wireframes (landing, dashboard, form, pricing, blog).

**Output:** ASCII wireframe (in chat, in a file, or screenshot if rendered)

**Wait for the user's "yes" or "change X" before phase 2.**

</step>

<step name="phase2_theme">
**Goal:** Pick the theme + customize colors/fonts/spacing.

1. **Pick a starting theme:**
   - Modern Dark (default — Vercel/Linear style)
   - Neo-Brutalism (90s revival, opinionated)
   - Glassmorphism (premium, needs colorful bg)

2. **Customize if needed** (brand colors, industry, audience)

3. **Set the font** (Inter default, or override based on theme)

4. **Define spacing + shadows** (4px base, subtle shadows by default)

**Use @frameworks/theme-templates.md** for the 3 ready-to-use CSS variable sets.

**Output:** the chosen theme's CSS variables + font stack + spacing scale, written to the project.

</step>

<step name="phase3_animations">
**Goal:** Plan every animation using micro-syntax BEFORE coding.

1. **List every animated element** (button hovers, card entries, page transitions, loading states)
2. **For each, write the micro-syntax:**
   - `selector: duration easing [property: from → to]`
3. **Plan stagger** for lists/grids (30-50ms per item)
4. **Pick the right easing** (ease-out for entries, ease-in for exits, linear for loops)

**Use @frameworks/animation-micro-syntax.md** for the full notation guide + common patterns.

**Output:** a list of micro-syntax animations, ready to translate to CSS.

</step>

<step name="phase4_implementation">
**Goal:** Write the code based on phases 1-3.

1. **Set up the project** (Next.js / Vite / plain HTML)
2. **Add Tailwind + Flowbite + Lucide** (via CDN for prototypes, npm for production)
3. **Translate the wireframe** to JSX/HTML
4. **Apply the theme** (paste the CSS variables from phase 2)
5. **Apply the animations** (translate micro-syntax to CSS/Framer Motion)
6. **Make it responsive** (mobile-first, breakpoints from Tailwind)
7. **Accessibility pass** (semantic HTML, focus states, alt text, ARIA)

**Use @frameworks/component-patterns.md** for ready-to-use component code (cards, buttons, forms, nav, modals).

**Output:** working UI code, ready to deploy.

</step>

<step name="final_verification">
- [ ] Wireframe was created and approved by the user
- [ ] Theme was picked and CSS variables defined
- [ ] Animations were planned with micro-syntax
- [ ] Code is responsive (mobile, tablet, desktop)
- [ ] Both light and dark mode work (if applicable)
- [ ] Icons use Lucide (not emoji)
- [ ] Accessibility: focus rings, semantic HTML, alt text, ARIA labels
- [ ] No generic bootstrap blue
- [ ] Spacing is consistent (4px base)
- [ ] Animations are subtle (150-400ms)
- [ ] Shadows are subtle (not heavy)
- [ ] Real placeholder images (Unsplash / placehold.co, not made-up URLs)
</step>

</steps>

<output>
## Artifact
A complete UI: wireframe + theme + animations + working code.

## Format
- `wireframe.md` (or in chat)
- `theme.css` (CSS variables, ready to paste)
- `animations.md` (micro-syntax list)
- Component code (in the project)

## Location
The project directory (whatever the user is working on).
</output>

<acceptance-criteria>
- [ ] All 4 phases completed in order
- [ ] the user approved the wireframe before coding
- [ ] Theme is one of the 3 templates (or a documented override)
- [ ] Every animation has a micro-syntax plan
- [ ] Code uses Tailwind + Flowbite + Lucide
- [ ] Mobile-first responsive
- [ ] Accessibility checklist passed
- [ ] No anti-patterns (no bootstrap blue, no emoji icons, no heavy shadows, etc.)
</acceptance-criteria>
