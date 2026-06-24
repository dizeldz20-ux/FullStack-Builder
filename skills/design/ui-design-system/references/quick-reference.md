# Quick Reference — UI Design System

> copy-paste patterns and decisions

## The 4 Phases

1. **Layout** — ASCII wireframe first (30 sec). Get the user's approval.
2. **Theme** — Pick Modern Dark (default) / Neo-Brutalism / Glassmorphism. Adjust variables.
3. **Animation** — Plan with micro-syntax (`hover: 200ms [Y0→-2, shadow↗]`).
4. **Implementation** — Tailwind + Flowbite + Lucide. Translate the plan to code.

## Pick a Theme

| Product type | Theme |
|---|---|
| SaaS, B2B, dev tools | **Modern Dark** (default) |
| Marketing site, friendly app | Modern Dark |
| Personal site, creative tool | **Neo-Brutalism** |
| Premium, fintech, AI | **Glassmorphism** (requires colorful bg) |
| Kids, casual | Modern Dark + Poppins font |

## Tailwind CDN (for prototypes)

```html
<script src="https://cdn.tailwindcss.com"></script>
```

## Flowbite (component library)

```html
<link href="https://cdn.jsdelivr.net/npm/flowbite@2.0.0/dist/flowbite.min.css" rel="stylesheet">
<script src="https://cdn.jsdelivr.net/npm/flowbite@2.0.0/dist/flowbite.min.js"></script>
```

## Lucide Icons

```html
<script src="https://unpkg.com/lucide@latest"></script>
<script>lucide.createIcons();</script>

<i data-lucide="home"></i>
<i data-lucide="settings"></i>
<i data-lucide="user"></i>
```

## Placeholder Images

```html
<!-- Random image from Unsplash -->
<img src="https://images.unsplash.com/photo-XXX?w=800&h=600" />

<!-- Specific size placeholder -->
<img src="https://placehold.co/800x600" />

<!-- User avatar placeholder -->
<img src="https://i.pravatar.cc/100" />
```

## Common Color Variables (Modern Dark)

```css
:root {
  --background: oklch(1 0 0);
  --foreground: oklch(0.145 0 0);
  --primary: oklch(0.205 0 0);
  --primary-foreground: oklch(0.985 0 0);
  --secondary: oklch(0.970 0 0);
  --muted: oklch(0.970 0 0);
  --muted-foreground: oklch(0.556 0 0);
  --border: oklch(0.922 0 0);
  --destructive: oklch(0.577 0.245 27.325);
  --radius: 0.625rem;
  --font-sans: Inter, system-ui, sans-serif;
}
```

## Animation Timing Cheat

| Type | Duration | Easing |
|---|---|---|
| Hover | 150-200ms | ease-out |
| Press | 100-150ms | ease-in |
| Entry | 300-500ms | ease-out |
| Modal | 250-400ms | ease-out |
| Stagger | 30-50ms per item | ease-out |
| Bounce (success) | 500-700ms | cubic-bezier(0.34, 1.56, 0.64, 1) |

## Anti-Patterns

- ❌ `background: #007bff` (generic bootstrap blue)
- ❌ `border-radius: 0.5rem` in a brutalist theme
- ❌ Animation duration > 500ms for hover
- ❌ Emoji as UI icons (use Lucide)
- ❌ Hard drop shadows on Modern Dark theme
- ❌ Mixing 3 different fonts
- ❌ "Light mode only, dark later" (do both from start)
- ❌ Wireframe after coding (wireframe BEFORE)

---

*From a peer agent's superdesign, structured for skillsmith. 3 themes ready.*
