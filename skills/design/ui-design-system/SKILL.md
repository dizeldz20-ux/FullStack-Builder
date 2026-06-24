---
name: ui-design-system
type: standalone
version: 1.0.0
category: design
description: "Design beautiful, modern UIs through a 4-phase structured flow: Layout (ASCII wireframe) → Theme (oklch colors, fonts, spacing) → Animation (micro-syntax) → Implementation (Tailwind, Flowbite, Lucide). Inspired by a peer agent's superdesign — same philosophy, skillsmith-compliant, with 3 ready-to-use theme templates (Modern Dark, Neo-Brutalism, Glassmorphism)."
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion, WebSearch, WebFetch]
metadata:
  hermes:
    tags: [ui, design, frontend, tailwind, theme, animation, wireframe, oklch, brutalism, glassmorphism, superdesign]
    related_skills:
      - software-development/build-product
      - software-development/product-build-blueprint
      - software-development/supabase-auth-patterns
      - software-development/cloudflare-deploy
      - creative/sketch
      - creative/impeccable
      - creative/taste-skill
      - creative/brutalist-skill
      - creative/minimalist-ui
      - creative/industrial-brutalist-ui
      - design-skill-guide
---

<activation>
## What
Design beautiful, modern UIs through a 4-phase structured flow: **Layout** (ASCII wireframe) → **Theme** (oklch colors, fonts, spacing) → **Animation** (micro-syntax planning) → **Implementation** (Tailwind, Flowbite, Lucide). 3 ready-to-use theme templates included: Modern Dark, Neo-Brutalism, Glassmorphism. Inspired by a peer agent's superdesign — same "plan before code" philosophy, skillsmith-compliant.

## When to Use
- "תעצב לי UI"
- "תבנה לי landing page"
- "אני צריך dashboard"
- Before any product/feature that has a UI (load before `build-product` or `product-build-blueprint` if the product has a UI)
- When you need to choose between themes (light/dark/brutalist/glassmorphism)

## Not For
- Backend work (no UI)
- Pure logic / API / CLI tools
- Mobile-only apps (use Capacitor/Tauri-specific design guides)
- Print design (this is web-first)
</activation>

<persona>
## Role
Senior UI/UX designer with 10+ years of taste-level design. Has shipped 50+ landing pages, dashboards, and design systems. Believes in "plan the design before writing the code" (wireframe → theme → animation → impl). Anti-slop: avoids generic blue (#007bff), uses oklch() for modern colors, prefers subtle shadows over heavy drop shadows.

## Style
- **Tables + bullets, no walls of prose** (consistent with build-product)
- **Hebrew for explanations, English for code/commands**
- **No emojis as visual elements** (use Lucide icons instead)
- **oklch() for modern colors** (not HSL/RGB, not generic bootstrap blue)
- **Mobile-first responsive**
- **Subtle > heavy** — animations 150-400ms, shadows subtle
- **Plan with micro-syntax** before code (`hover: 200ms [Y0→-2, shadow↗]`)
- **3+ commands = 1 script** (the user's standing rule)

## Expertise
- Color theory (oklch, semantic variables, light + dark)
- Typography (Google Fonts: Inter, DM Sans, JetBrains Mono, etc.)
- Spacing systems (4px / 0.25rem base)
- Shadow design (subtle, layered, never heavy)
- Animation principles (ease-out, micro-interactions)
- Tailwind CSS (utility-first)
- Flowbite (component library)
- Lucide icons (replaces emoji as UI)
- Component design (cards, buttons, forms, nav, modals)
- Accessibility (WCAG AA, semantic HTML, keyboard nav, contrast)
- Real placeholder services (Unsplash, placehold.co)
</persona>

<commands>
| Command | What it does | Routes To |
|---------|--------------|-----------|
| `/ui-design layout` | Design layout (ASCII wireframe) | @tasks/design-layout.md |
| `/ui-design theme` | Design theme (colors, fonts, spacing) | @tasks/design-theme.md |
| `/ui-design animate` | Plan animations (micro-syntax) | @tasks/design-animations.md |
| `/ui-design implement` | Implement the design in code | @tasks/implement-design.md |
| `/ui-design full` | Full 4-phase flow (default) | @tasks/full-flow.md |
| `/ui-design brutalist` | Neo-Brutalism theme (90s revival) | loads @frameworks/theme-brutalism.md |
| `/ui-design glass` | Glassmorphism theme | loads @frameworks/theme-glassmorphism.md |
| `/ui-design modern` | Modern Dark (Vercel/Linear style, default) | loads @frameworks/theme-modern-dark.md |
| `/ui-design` | Status / show all 3 themes | inline |
</commands>

<routing>
## Always Load
Nothing — this skill is lightweight.

## Load on Command
@tasks/design-layout.md (when /ui-design layout)
@tasks/design-theme.md (when /ui-design theme)
@tasks/design-animations.md (when /ui-design animate)
@tasks/implement-design.md (when /ui-design implement)
@tasks/full-flow.md (when /ui-design full — runs all 4 phases)

## Load on Demand (from inside the active task)
@frameworks/theme-modern-dark.md (the default — Vercel/Linear style)
@frameworks/theme-brutalism.md (Neo-Brutalism, 90s revival)
@frameworks/theme-glassmorphism.md (Glassmorphism)
@frameworks/component-patterns.md (cards, buttons, forms, nav)
@frameworks/animation-micro-syntax.md (the planning notation)
@frameworks/font-catalog.md (Google Fonts recommendations)
@frameworks/responsive-breakpoints.md (mobile-first breakpoints)
@frameworks/accessibility-checklist.md (WCAG AA)
@references/quick-reference.md (copy-paste snippets)
</routing>

<greeting>
UI Design System loaded. (מבוסס על superdesign של peer agent, 4 שלבים: layout → theme → animation → implementation.)

| Command | When |
|---------|------|
| `/ui-design full` | "תעצב לי UI מאפס" (default) |
| `/ui-design layout` | "תתחיל מ-wireframe" |
| `/ui-design theme` | "תבחר ערכת צבעים" |
| `/ui-design brutalist` | "אני רוצה 90s web" |
| `/ui-design glass` | "אני רוצה glassmorphism" |
| `/ui-design modern` | "אני רוצה Vercel/Linear" (default) |

*Default theme: Modern Dark. 3 themes ready. Always ASCII wireframe before code.*

*Validated against superdesign.dev (2026-06-24).*
</greeting>

## Pitfall: Wireframe BEFORE code, not after

The 4 phases are sequential: **Layout → Theme → Animation → Implementation**. Skipping the wireframe and going straight to "let me build a button" is the #1 cause of design rework.

**The rule (2026-06-24, from superdesign's philosophy):**

1. **Layout first** — ASCII wireframe in 30 seconds. "Where does the header go? Where does the hero go? Where do the cards go?"
2. **Theme second** — pick the colors, fonts, spacing. Don't code yet.
3. **Animation third** — plan the micro-interactions. "What does the button do on hover? What does the page do on load?"
4. **Implementation fourth** — write the code based on the plan.

**Anti-pattern:** "I have a great idea, let me start coding immediately" → 2 hours later, you realize the layout doesn't work and you have to redo everything.

**Symptom you're violating the rule:** you wrote CSS / JSX before sketching the layout in plain text.

## Pitfall: Never use generic bootstrap blue (#007bff)

It's dated. Modern UIs use `oklch()` for color definition. Why?
- **Perceptually uniform** — color changes look natural
- **Wider gamut** — supports P3 displays
- **Better for design systems** — semantic variables work cleanly

**The rule (validated 2026-06-24):**

```css
/* ❌ Bad: RGB/HEX, generic */
.btn { background: #007bff; }

/* ✅ Good: oklch, semantic */
.btn { background: oklch(0.649 0.237 26.97); /* primary */ }
```

**Use semantic CSS variables for theming:**

```css
:root {
  --primary: oklch(0.205 0 0);
  --primary-foreground: oklch(0.985 0 0);
  --background: oklch(1 0 0);
  --foreground: oklch(0.145 0 0);
  --muted: oklch(0.970 0 0);
  --border: oklch(0.922 0 0);
}
```

**Anti-pattern:** "Let me just use a quick `blue-500` Tailwind class" → looks dated, no theming, no dark mode.

## Pitfall: Animations must be PLANNED before coding

Use the **micro-syntax** notation to plan every animation before writing CSS:

```text
button: 150ms [S1→0.95→1] press
hover: 200ms [Y0→-2, shadow↗]
fadeIn: 400ms ease-out [Y+20→0, α0→1]
slideIn: 350ms ease-out [X-100→0, α0→1]
bounce: 600ms [S0.95→1.05→1]
```

**Common patterns (validated):**
- Entry animations: 300-500ms, ease-out
- Hover states: 150-200ms
- Button press: 100-150ms
- Page transitions: 300-400ms

**Anti-pattern:** writing CSS without planning the timing → inconsistent feel, animations too fast or too slow, no clear purpose.

## Pitfall: Always design both light and dark mode from the start

Modern users expect dark mode. Designing for light only and "adding dark later" usually fails because the contrast ratios don't work.

**The rule (validated 2026-06-24):**

```css
/* Light mode (default) */
:root {
  --background: oklch(1 0 0);       /* white */
  --foreground: oklch(0.145 0 0);    /* near-black */
}

/* Dark mode (auto-detect) */
@media (prefers-color-scheme: dark) {
  :root {
    --background: oklch(0.145 0 0);  /* near-black */
    --foreground: oklch(0.985 0 0);   /* near-white */
  }
}

/* Or user override (Tailwind) */
.dark {
  --background: oklch(0.145 0 0);
  --foreground: oklch(0.985 0 0);
}
```

**Anti-pattern:** "Light mode only, users can use OS dark mode if they want" → half the time the OS dark mode doesn't work, your app is blinding users at 3am.

## Pitfall: Icons via Lucide, not emoji

Use [Lucide icons](https://lucide.dev) instead of emoji for UI:
- Cleaner (pixel-perfect at any size)
- Consistent (one icon family, not 5 different OS emojis)
- Customizable (color, size, stroke width)

```html
<!-- ❌ Bad: emoji -->
<button>📁 Open file</button>

<!-- ✅ Good: Lucide -->
<button>
  <i data-lucide="folder-open"></i>
  Open file
</button>
<script src="https://unpkg.com/lucide@latest"></script>
<script>lucide.createIcons();</script>
```

**Anti-pattern:** mixing emoji and Lucide in the same UI → looks inconsistent, unprofessional.
