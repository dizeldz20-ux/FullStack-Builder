<purpose>
Pick a theme + customize colors, fonts, spacing. Use one of the 3 ready-to-use templates (Modern Dark, Neo-Brutalism, Glassmorphism) or override.
</purpose>

<user-story>
As the user, I want to pick the visual style for my product and have the CSS variables ready to paste, so I don't have to design colors and fonts from scratch.
</user-story>

<when-to-use>
- "תבחר ערכת צבעים"
- "אני רוצה Vercel style / 90s / glassmorphism"
- After the wireframe is approved

NOT for: theme is already decided (just edit the variables).
</when-to-use>

<context>
None
</context>

<references>
@frameworks/theme-templates.md (the 3 ready-to-use themes)
@frameworks/font-catalog.md (Google Fonts)
</references>

<steps>

<step name="pick_theme">
**Default: Modern Dark** (Vercel/Linear style). Use it unless the user has a specific preference.

| Theme | When to use |
|---|---|
| **Modern Dark** | SaaS, B2B, dev tools, most products |
| **Neo-Brutalism** | Personal site, creative tool, opinionated product |
| **Glassmorphism** | Premium product, fintech, AI, needs colorful bg |

Ask the user only if it's a strong preference ("I want brutalist" or "make it feel premium"). Otherwise, default to Modern Dark.
</step>

<step name="set_font">
**Default: Inter** (sans) + JetBrains Mono (code).

Override based on the theme:
- Neo-Brutalism → DM Sans + Space Mono
- Glassmorphism → Inter (no override)
- Marketing page → Outfit or Plus Jakarta Sans
- Long-form content → add a serif (Merriweather, Lora)
</step>

<step name="define_css_variables">
**Output: a `:root { ... }` block ready to paste into the project.**

```css
:root {
  /* from the chosen theme */
  --background: ...;
  --foreground: ...;
  --primary: ...;
  /* etc */

  /* fonts */
  --font-sans: Inter, system-ui, sans-serif;
  --font-mono: JetBrains Mono, monospace;

  /* radius (rounded vs sharp) */
  --radius: 0.625rem;  /* or 0 for brutalist */
}
```

**Use @frameworks/theme-templates.md** for the full variable set.
</step>

<step name="set_dark_mode">
If the product should support dark mode:

```css
@media (prefers-color-scheme: dark) {
  :root {
    --background: oklch(0.145 0 0);
    --foreground: oklch(0.985 0 0);
    /* etc */
  }
}
```

**Always design both light and dark from the start.** Don't "add dark mode later."
</step>

<step name="get_approval">
Show the user the chosen theme + the CSS variables. Ask:
- "הערכה הזו טובה?"
- "הצבעים מתאימים?"
- "הפונט נכון?"

Then move to phase 3 (animations).
</step>

</steps>

<output>
## Artifact
CSS variables (`:root` block) + font stack + radius.

## Format
A single `theme.css` file or a code block.

## Location
In the project's CSS / styles directory.
</output>

<acceptance-criteria>
- [ ] Theme is one of the 3 templates (or documented override)
- [ ] All CSS variables defined
- [ ] Font stack set
- [ ] Radius set
- [ ] Dark mode handled (if applicable)
- [ ] the user approved the visual style
</acceptance-criteria>
