<design_theme>

## Purpose
The second phase of UI design — pick the colors, fonts, spacing, and shadows. 3 ready-to-use theme templates: Modern Dark (default), Neo-Brutalism, Glassmorphism.

## When this framework loads
- During `tasks/design-theme.md` → step "pick_theme"
- When you need a starting point for color/typography
- When designing a new product's visual identity

---

## § The 3 Ready-to-Use Themes

### Theme 1: Modern Dark (default — Vercel/Linear style)

**When to use:** Most products. SaaS, dashboards, dev tools, B2B. The "default good taste" of 2024-2026.

**Colors (oklch):**

```css
:root {
  --background: oklch(1 0 0);          /* white */
  --foreground: oklch(0.145 0 0);      /* near-black text */
  --primary: oklch(0.205 0 0);         /* near-black primary button */
  --primary-foreground: oklch(0.985 0 0); /* white text on primary */
  --secondary: oklch(0.970 0 0);      /* light gray */
  --muted: oklch(0.970 0 0);           /* muted background */
  --muted-foreground: oklch(0.556 0 0); /* muted text */
  --border: oklch(0.922 0 0);          /* light border */
  --radius: 0.625rem;                  /* 10px rounded corners */
  --font-sans: Inter, system-ui, sans-serif;
}

/* Dark mode (auto-detect) */
@media (prefers-color-scheme: dark) {
  :root {
    --background: oklch(0.145 0 0);
    --foreground: oklch(0.985 0 0);
    --primary: oklch(0.985 0 0);
    --primary-foreground: oklch(0.205 0 0);
    --secondary: oklch(0.269 0 0);
    --muted: oklch(0.269 0 0);
    --muted-foreground: oklch(0.708 0 0);
    --border: oklch(0.269 0 0);
  }
}
```

**Typography:** Inter (sans), JetBrains Mono (mono)

**Spacing:** 4px base (0.25rem)

**Shadows:** Subtle, 1-2 layers max
```css
--shadow-sm: 0 1px 2px 0 oklch(0 0 0 / 0.05);
--shadow: 0 1px 3px 0 oklch(0 0 0 / 0.1), 0 1px 2px -1px oklch(0 0 0 / 0.1);
--shadow-md: 0 4px 6px -1px oklch(0 0 0 / 0.1), 0 2px 4px -2px oklch(0 0 0 / 0.1);
```

---

### Theme 2: Neo-Brutalism (90s web revival)

**When to use:** Bold, opinionated products. When you want to stand out. Personal sites, creative tools, products with personality.

**Colors (oklch):**

```css
:root {
  --background: oklch(1 0 0);          /* white */
  --foreground: oklch(0 0 0);          /* pure black */
  --primary: oklch(0.649 0.237 26.97); /* bold red-orange */
  --secondary: oklch(0.968 0.211 109.77); /* bold yellow-green */
  --accent: oklch(0.564 0.241 260.82); /* bold blue */
  --border: oklch(0 0 0);              /* pure black borders */
  --radius: 0px;                       /* NO rounded corners */
  --shadow: 4px 4px 0px 0px oklch(0 0% 0%); /* hard offset shadow */
  --font-sans: DM Sans, sans-serif;
  --font-mono: Space Mono, monospace;
}
```

**Typography:** DM Sans (sans), Space Mono (mono) — bold, characterful

**Spacing:** 4px base

**Borders:** THICK (2-3px), pure black, no border-radius

**Shadows:** Hard offset (4px 4px 0 0 #000) — never soft

**Example components:**

```css
.btn-brutal {
  background: var(--primary);
  color: white;
  border: 3px solid var(--border);
  border-radius: 0;
  box-shadow: var(--shadow);
  font-weight: 900;
  text-transform: uppercase;
  padding: 1rem 2rem;
  transition: all 100ms ease;
}

.btn-brutal:hover {
  transform: translate(-2px, -2px);
  box-shadow: 6px 6px 0 0 var(--border);
}

.btn-brutal:active {
  transform: translate(2px, 2px);
  box-shadow: 2px 2px 0 0 var(--border);
}
```

---

### Theme 3: Glassmorphism (translucent + blur)

**When to use:** Modern, premium feel. When you have colorful backgrounds (gradients, images). macOS-style, fintech, AI products.

**Colors (translucent):**

```css
:root {
  --background: oklch(0.98 0.02 250);   /* soft tinted bg */
  --foreground: oklch(0.145 0 0);
  --primary: oklch(0.564 0.241 260.82); /* bold blue */
  --glass-bg: rgba(255, 255, 255, 0.1);
  --glass-border: rgba(255, 255, 255, 0.2);
  --glass-blur: blur(10px);
  --radius: 1rem;                       /* very rounded */
  --font-sans: Inter, system-ui, sans-serif;
}

@media (prefers-color-scheme: dark) {
  :root {
    --background: oklch(0.15 0.05 250);
    --foreground: oklch(0.985 0 0);
    --glass-bg: rgba(0, 0, 0, 0.2);
    --glass-border: rgba(255, 255, 255, 0.1);
  }
}
```

**The .glass class:**

```css
.glass {
  background: var(--glass-bg);
  backdrop-filter: var(--glass-blur);
  -webkit-backdrop-filter: var(--glass-blur);
  border: 1px solid var(--glass-border);
  border-radius: var(--radius);
  box-shadow: 0 8px 32px 0 rgba(0, 0, 0, 0.1);
}
```

**Typography:** Inter

**Requires:** A colorful background (gradient, image, video). Plain white background = no glassmorphism.

---

## § Font Selection (Google Fonts)

### Sans-serif (for body text, UI)

| Font | When to use |
|---|---|
| **Inter** | Default. Clean, modern, very readable. Use for most products. |
| **DM Sans** | Slightly more characterful. Neo-brutalism, friendly apps. |
| **Outfit** | Geometric, modern. Tech products, dashboards. |
| **Plus Jakarta Sans** | Friendly + professional. Consumer apps. |
| **Space Grotesk** | Distinctive, slightly retro. Design-forward products. |
| **Roboto** | Safe default. Boring but works. |
| **Poppins** | Friendly, rounded. Consumer, kids, casual. |
| **Montserrat** | Classic modern. Marketing pages. |

### Monospace (for code, technical content)

| Font | When to use |
|---|---|
| **JetBrains Mono** | Default for code. Excellent ligatures, very readable. |
| **Fira Code** | Classic. Great ligatures. |
| **Source Code Pro** | Adobe-quality. |
| **IBM Plex Mono** | Corporate, clean. |
| **Space Mono** | Distinctive. Brutalist, retro. |
| **Geist Mono** | Modern (Vercel's font). |

### Serif (for long-form reading, editorial)

| Font | When to use |
|---|---|
| **Merriweather** | Highly readable. Blog posts, docs. |
| **Playfair Display** | High-contrast, elegant. Marketing, editorial. |
| **Lora** | Calligraphic, warm. Reading-heavy apps. |
| **Source Serif Pro** | Adobe-quality. |
| **Libre Baskerville** | Classic. Premium products. |

### Display (for headlines, special occasions)

| Font | When to use |
|---|---|
| **Architects Daughter** | Hand-written. Personal, friendly. |
| **Oxanium** | Sci-fi, geometric. Tech-forward. |

---

## § Spacing System

**4px base (0.25rem):**

```css
:root {
  --space-1: 0.25rem;   /* 4px */
  --space-2: 0.5rem;    /* 8px */
  --space-3: 0.75rem;   /* 12px */
  --space-4: 1rem;      /* 16px */
  --space-6: 1.5rem;    /* 24px */
  --space-8: 2rem;      /* 32px */
  --space-12: 3rem;     /* 48px */
  --space-16: 4rem;     /* 64px */
  --space-24: 6rem;     /* 96px */
}
```

**Tailwind default** uses the same scale (`p-4`, `p-8`, etc.).

---

## § Shadow System

### Subtle (Modern Dark theme)

```css
--shadow-sm: 0 1px 2px 0 oklch(0 0 0 / 0.05);
--shadow: 0 1px 3px 0 oklch(0 0 0 / 0.1), 0 1px 2px -1px oklch(0 0 0 / 0.1);
--shadow-md: 0 4px 6px -1px oklch(0 0 0 / 0.1), 0 2px 4px -2px oklch(0 0 0 / 0.1);
--shadow-lg: 0 10px 15px -3px oklch(0 0 0 / 0.1), 0 4px 6px -4px oklch(0 0 0 / 0.1);
```

**Rule:** subtle > heavy. If you can see the shadow from across the room, it's too much.

### Hard offset (Neo-Brutalism)

```css
--shadow-brutal: 4px 4px 0 0 oklch(0 0% 0%);
--shadow-brutal-lg: 8px 8px 0 0 oklch(0 0% 0%);
```

**Rule:** zero blur. Hard edges. Always offset (4-8px) to suggest "popping out" of the page.

---

## § Color Variables — The Full Set

```css
:root {
  /* Base */
  --background: ...;
  --foreground: ...;

  /* Brand */
  --primary: ...;
  --primary-foreground: ...;
  --secondary: ...;
  --secondary-foreground: ...;

  /* Muted */
  --muted: ...;
  --muted-foreground: ...;

  /* Surfaces */
  --card: ...;
  --card-foreground: ...;
  --popover: ...;
  --popover-foreground: ...;

  /* Status */
  --success: ...;
  --warning: ...;
  --destructive: ...;
  --destructive-foreground: ...;

  /* Borders + inputs */
  --border: ...;
  --input: ...;
  --ring: ...;  /* focus ring color */

  /* Layout */
  --radius: ...;
}
```

**Always use semantic names** (`--primary`, `--destructive`) not literal (`--blue-500`, `--red-500`).

---

## § When to Override Defaults

The 3 themes are **starting points**. Override when:

| Override | Why |
|---|---|
| Brand identity | Your brand has specific colors |
| Industry | Fintech = navy/gold. Healthcare = soft blue. Gaming = bold colors. |
| Audience | Enterprise = sober. Consumer = playful. |
| Existing product | Match an existing design system |

**Anti-pattern:** "I'll use the default theme for everything" → all your products look the same.
</content>