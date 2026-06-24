<purpose>
Translate the wireframe + theme + animations into working code (Tailwind + Flowbite + Lucide). This is the final phase of UI design.
</purpose>

<user-story>
As the user, I want the design translated to code, ready to deploy, so I have a working UI that matches the plan.
</user-story>

<when-to-use>
- After the wireframe + theme + animations are approved
- When you have all 3 artifacts and are ready to code

NOT for: no approved design yet (do phases 1-3 first).
</when-to-use>

<context>
None
</context>

<references>
@frameworks/component-patterns.md (ready-to-use component code)
@frameworks/responsive-breakpoints.md (mobile-first breakpoints)
@frameworks/accessibility-checklist.md (WCAG AA)
</references>

<steps>

<step name="setup_dependencies">
For prototypes, use CDN. For production, install via npm.

**Prototype (CDN):**
```html
<script src="https://cdn.tailwindcss.com"></script>
<link href="https://cdn.jsdelivr.net/npm/flowbite@2.0.0/dist/flowbite.min.css" rel="stylesheet">
<script src="https://cdn.jsdelivr.net/npm/flowbite@2.0.0/dist/flowbite.min.js"></script>
<script src="https://unpkg.com/lucide@latest"></script>
```

**Production (npm):**
```bash
npm install tailwindcss flowbite lucide
```

Add Tailwind config to recognize Flowbite + oklch colors.
</step>

<step name="apply_theme">
Paste the CSS variables from phase 2 into the project:

```css
:root {
  --background: oklch(1 0 0);
  --foreground: oklch(0.145 0 0);
  /* ... etc */
}
```

Configure Tailwind to use these:
```js
// tailwind.config.js
module.exports = {
  theme: {
    extend: {
      colors: {
        background: 'var(--background)',
        foreground: 'var(--foreground)',
        primary: 'var(--primary)',
        /* ... */
      }
    }
  }
}
```
</step>

<step name="translate_wireframe">
For each section in the wireframe, write the HTML/JSX.

Use semantic HTML: `<header>`, `<main>`, `<nav>`, `<section>`, `<article>`, `<footer>`.

Use @frameworks/component-patterns.md for ready-to-use patterns.
</step>

<step name="apply_animations">
Translate the micro-syntax to CSS or Framer Motion.

**Example: `hover: 200ms ease-out [Y0→-2, shadow↗]`**

CSS:
```css
.btn {
  transition: transform 200ms ease-out, box-shadow 200ms ease-out;
}
.btn:hover {
  transform: translateY(-2px);
  box-shadow: 0 6px 12px 0 oklch(0 0 0 / 0.1);
}
```

Tailwind:
```html
<button class="transition-all duration-200 ease-out hover:-translate-y-0.5 hover:shadow-md">
  Click me
</button>
```
</step>

<step name="make_responsive">
Mobile-first. Default styles are mobile, override with `md:`, `lg:`, etc.

```html
<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
  <div class="card">...</div>
  <div class="card">...</div>
  <div class="card">...</div>
</div>
```

**Always test on mobile** (or use the browser at 375px width).
</step>

<step name="accessibility_pass">
Use @frameworks/accessibility-checklist.md:

- [ ] All interactive elements have focus rings
- [ ] Color contrast ≥ 4.5:1
- [ ] All inputs have labels
- [ ] All images have alt text
- [ ] Buttons have descriptive text
- [ ] Keyboard navigation works (Tab, Enter, Escape)
- [ ] Modal traps focus
- [ ] Headings form a hierarchy
- [ ] Semantic HTML
</step>

<step name="verify_in_browser">
Open the page in a real browser. Test:
- Mobile (375px)
- Tablet (768px)
- Desktop (1280px)
- Light mode
- Dark mode (if applicable)
- Hover states
- Click states
- Loading states
</step>

</steps>

<output>
## Artifact
Working UI code, responsive, accessible, matching the design plan.

## Format
- HTML / JSX files
- CSS variables
- Tailwind config
- Lucide icons initialized

## Location
The project directory.
</output>

<acceptance-criteria>
- [ ] Theme variables applied
- [ ] Wireframe translated to semantic HTML
- [ ] Animations match the micro-syntax plan
- [ ] Mobile-first responsive
- [ ] Light + dark mode work
- [ ] Lucide icons (not emoji)
- [ ] Accessibility checklist passed
- [ ] Tested in real browser at 3 sizes
</acceptance-criteria>
