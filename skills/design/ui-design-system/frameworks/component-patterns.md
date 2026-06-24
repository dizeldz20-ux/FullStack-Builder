<component_patterns>

## Purpose
Ready-to-use patterns for common UI components: cards, buttons, forms, navigation, modals. Use these as starting points, not as final code.

## When this framework loads
- During `tasks/implement-design.md` → any component
- When building a UI and need a starting point

---

## § Cards

**Modern Dark:**

```html
<div class="rounded-lg border bg-card p-6 shadow-sm">
  <h3 class="text-lg font-semibold">Card title</h3>
  <p class="text-sm text-muted-foreground mt-2">Card description goes here.</p>
</div>
```

**Neo-Brutalism:**

```html
<div class="border-[3px] border-black p-6 shadow-[4px_4px_0_0_#000]">
  <h3 class="text-lg font-black uppercase">Card title</h3>
  <p class="text-sm mt-2">Card description goes here.</p>
</div>
```

**Hover state (both themes):**

```css
.card {
  transition: transform 200ms ease-out, box-shadow 200ms ease-out;
}
.card:hover {
  transform: translateY(-2px);
  box-shadow: /* larger shadow */;
}
```

---

## § Buttons

### Primary

```html
<button class="
  bg-primary text-primary-foreground
  px-4 py-2 rounded-md
  font-medium
  hover:opacity-90
  active:scale-95
  transition-all
  focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2
  disabled:opacity-50 disabled:cursor-not-allowed
">
  Get Started
</button>
```

### Secondary (outline)

```html
<button class="
  border border-input bg-background
  px-4 py-2 rounded-md
  font-medium
  hover:bg-accent
  active:scale-95
  transition-all
">
  Cancel
</button>
```

### Ghost (no border, just text)

```html
<button class="
  px-4 py-2 rounded-md
  font-medium
  hover:bg-accent
  transition-colors
">
  Learn more →
</button>
```

### Destructive

```html
<button class="
  bg-destructive text-destructive-foreground
  px-4 py-2 rounded-md
  font-medium
  hover:opacity-90
  active:scale-95
">
  Delete
</button>
```

### Loading state

```html
<button disabled class="...">
  <svg class="animate-spin h-4 w-4" /* spinner */ />
  Loading...
</button>
```

### Icon button (square)

```html
<button class="
  h-10 w-10
  inline-flex items-center justify-center
  rounded-md
  hover:bg-accent
  transition-colors
">
  <i data-lucide="settings" class="h-5 w-5"></i>
</button>
```

---

## § Forms

### Input

```html
<div>
  <label for="email" class="block text-sm font-medium mb-2">Email</label>
  <input
    type="email"
    id="email"
    class="
      w-full px-3 py-2
      border border-input rounded-md
      bg-background
      focus:outline-none focus:ring-2 focus:ring-ring
      disabled:opacity-50
    "
    placeholder="you@example.com"
  />
  <p class="text-xs text-muted-foreground mt-1">Helper text goes here.</p>
</div>
```

### Inline validation

```html
<div>
  <label for="password" class="block text-sm font-medium mb-2">Password</label>
  <input
    type="password"
    class="border border-input rounded-md px-3 py-2 border-destructive"  /* red border */
  />
  <p class="text-xs text-destructive mt-1">Password must be at least 8 characters.</p>
</div>
```

### Select

```html
<select class="
  w-full px-3 py-2
  border border-input rounded-md
  bg-background
  focus:outline-none focus:ring-2 focus:ring-ring
">
  <option>Option 1</option>
  <option>Option 2</option>
</select>
```

### Checkbox

```html
<label class="flex items-center gap-2 cursor-pointer">
  <input type="checkbox" class="h-4 w-4 rounded border-input" />
  <span class="text-sm">Remember me</span>
</label>
```

### Radio group

```html
<fieldset>
  <legend class="text-sm font-medium mb-2">Choose a plan</legend>
  <div class="space-y-2">
    <label class="flex items-center gap-2">
      <input type="radio" name="plan" value="free" class="h-4 w-4" />
      <span>Free</span>
    </label>
    <label class="flex items-center gap-2">
      <input type="radio" name="plan" value="pro" class="h-4 w-4" />
      <span>Pro</span>
    </label>
  </div>
</fieldset>
```

---

## § Navigation

### Top nav (header)

```html
<header class="sticky top-0 z-50 border-b bg-background/95 backdrop-blur">
  <div class="container flex h-16 items-center justify-between">
    <a href="/" class="font-bold text-lg">[LOGO]</a>

    <nav class="hidden md:flex items-center gap-6">
      <a href="/features" class="text-sm hover:text-foreground">Features</a>
      <a href="/pricing" class="text-sm hover:text-foreground">Pricing</a>
      <a href="/docs" class="text-sm hover:text-foreground">Docs</a>
    </nav>

    <div class="flex items-center gap-2">
      <button class="...">Sign in</button>
      <button class="...">Sign up</button>
    </div>

    <!-- Mobile menu button -->
    <button class="md:hidden">
      <i data-lucide="menu"></i>
    </button>
  </div>
</header>
```

### Sidebar

```html
<aside class="w-64 border-r bg-card p-4">
  <nav class="space-y-1">
    <a href="/dashboard" class="
      flex items-center gap-3
      px-3 py-2 rounded-md
      bg-accent text-accent-foreground
      font-medium
    ">
      <i data-lucide="home"></i>
      Home
    </a>
    <a href="/items" class="
      flex items-center gap-3
      px-3 py-2 rounded-md
      text-muted-foreground
      hover:bg-accent hover:text-accent-foreground
    ">
      <i data-lucide="package"></i>
      Items
    </a>
    <a href="/settings" class="
      flex items-center gap-3
      px-3 py-2 rounded-md
      text-muted-foreground
      hover:bg-accent hover:text-accent-foreground
    ">
      <i data-lucide="settings"></i>
      Settings
    </a>
  </nav>
</aside>
```

### Breadcrumbs

```html
<nav class="text-sm text-muted-foreground">
  <a href="/" class="hover:underline">Home</a>
  <span class="mx-2">/</span>
  <a href="/dashboard" class="hover:underline">Dashboard</a>
  <span class="mx-2">/</span>
  <span>Settings</span>
</nav>
```

---

## § Modals

```html
<!-- Trigger -->
<button onclick="document.getElementById('modal').classList.remove('hidden')">
  Open modal
</button>

<!-- Modal -->
<div id="modal" class="hidden fixed inset-0 z-50 bg-black/50 flex items-center justify-center p-4">
  <div class="
    bg-background rounded-lg
    border shadow-lg
    p-6 max-w-md w-full
    animate-in fade-in slide-in-from-bottom-4
  ">
    <h2 class="text-lg font-semibold mb-2">Modal title</h2>
    <p class="text-sm text-muted-foreground mb-4">Modal description.</p>
    <div class="flex justify-end gap-2">
      <button class="...">Cancel</button>
      <button class="...">Confirm</button>
    </div>
  </div>
</div>
```

---

## § Loading States

### Skeleton

```html
<div class="space-y-2">
  <div class="h-4 bg-muted rounded animate-pulse"></div>
  <div class="h-4 bg-muted rounded animate-pulse w-3/4"></div>
  <div class="h-4 bg-muted rounded animate-pulse w-1/2"></div>
</div>
```

### Spinner

```html
<svg class="animate-spin h-5 w-5" /* ... */>
  <circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" fill="none" opacity="0.25" />
  <path fill="currentColor" d="..." />
</svg>
```

### Empty state

```html
<div class="text-center py-12">
  <i data-lucide="inbox" class="h-12 w-12 mx-auto text-muted-foreground"></i>
  <h3 class="mt-2 text-sm font-semibold">No items</h3>
  <p class="mt-1 text-sm text-muted-foreground">Get started by creating your first item.</p>
  <button class="mt-4 ...">Create item</button>
</div>
```

---

## § Responsive Breakpoints

Tailwind defaults (mobile-first):

| Prefix | Min-width | Devices |
|---|---|---|
| (none) | 0px | Mobile (default) |
| `sm:` | 640px | Large mobile / small tablet |
| `md:` | 768px | Tablet |
| `lg:` | 1024px | Laptop |
| `xl:` | 1280px | Desktop |
| `2xl:` | 1536px | Large desktop |

**Example — mobile-first card grid:**

```html
<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
  <div class="card">...</div>
  <div class="card">...</div>
  <div class="card">...</div>
</div>
```

---

## § Accessibility Checklist

- [ ] All interactive elements have `focus-visible:ring-2 focus-visible:ring-ring`
- [ ] Color contrast ≥ 4.5:1 for text
- [ ] All form inputs have associated `<label>`
- [ ] All images have `alt` text
- [ ] All buttons have descriptive text (or `aria-label` if icon-only)
- [ ] Navigation is keyboard-accessible (Tab, Enter, Escape)
- [ ] Modal traps focus, closes on Escape
- [ ] Headings form a hierarchy (h1 → h2 → h3, no skipping)
- [ ] Semantic HTML (`<header>`, `<main>`, `<nav>`, `<article>`, `<section>`)
