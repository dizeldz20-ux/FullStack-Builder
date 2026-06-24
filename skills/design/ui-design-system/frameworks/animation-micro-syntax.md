<animation_micro_syntax>

## Purpose
The micro-syntax for planning animations BEFORE writing CSS/JS. Forces you to think about timing, easing, and the visual change before you code.

## When this framework loads
- During `tasks/design-animations.md` → step "plan_animations"
- When designing any UI with motion (hover, page transitions, loading states)

---

## § The Micro-Syntax

```text
[selector]: [duration] [easing] [property: from → to]
```

**Example:**

```text
button: 150ms [S1→0.95→1] press
hover: 200ms [Y0→-2, shadow↗]
fadeIn: 400ms ease-out [Y+20→0, α0→1]
slideIn: 350ms ease-out [X-100→0, α0→1]
bounce: 600ms [S0.95→1.05→1]
```

**Symbols:**
- `S` = scale
- `Y` = translate Y (up/down)
- `X` = translate X (left/right)
- `α` = opacity (alpha)
- `↗` = increase (e.g. shadow growing)
- `↘` = decrease
- `→` = transition to
- `,` = AND (multiple properties at once)

---

## § Common Patterns (validated, 2026-06-24)

### Hover (most common)

```text
.btn: 200ms ease-out [Y0→-2, shadow↗]
```

Effect: button lifts 2px on hover, shadow grows. Feels responsive but subtle.

### Press (button active)

```text
.btn:active: 100ms [S1→0.95→1]
```

Effect: button shrinks to 95% on click, snaps back. Feels tactile.

### Fade in (entry)

```text
.card: 400ms ease-out [Y+20→0, α0→1]
```

Effect: card enters from 20px below, fades in. Standard entry animation.

### Slide in (sidebar, modal)

```text
.sidebar: 350ms ease-out [X-100→0, α0→1]
```

Effect: sidebar slides in from left. Modal slides up.

### Stagger (lists, grids)

```text
.card:nth-child(1): 300ms ease-out [Y+20→0, α0→1]
.card:nth-child(2): 350ms ease-out [Y+20→0, α0→1]  /* 50ms delay */
.card:nth-child(3): 400ms ease-out [Y+20→0, α0→1]  /* 100ms delay */
```

Effect: cards appear one after another. 50ms stagger = "flow", 100ms = "obvious", 200ms = "slow/awkward".

### Page transition

```text
.page: 300ms ease-in-out [α1→0→1]
```

Effect: current page fades out, new page fades in. Simple but effective.

### Loading spinner

```text
.spinner: 800ms linear [R0→360] infinite
```

Effect: rotates 360° every 800ms, infinite. Classic spinner.

### Skeleton (loading placeholder)

```text
.skeleton: 1500ms ease-in-out [α1↔0.5] infinite
```

Effect: skeleton pulses between full and 50% opacity. Feels alive.

### Bounce (success feedback)

```text
.icon-success: 600ms cubic-bezier(0.34, 1.56, 0.64, 1) [S0.95→1.05→1]
```

Effect: icon overshoots and settles. Feels rewarding (used after successful submit).

---

## § Timing Guide

| Type | Duration | Easing | Notes |
|---|---|---|---|
| Hover | 150-200ms | ease-out | Quick, responsive |
| Button press | 100-150ms | ease-in | Snappy, tactile |
| Card entry | 300-500ms | ease-out | Standard, not too slow |
| Modal/sidebar | 250-400ms | ease-out | Smooth, not jarring |
| Page transition | 300-400ms | ease-in-out | Polished |
| Stagger delay | 30-50ms per item | ease-out | "Flow" feel |
| Bounce | 500-700ms | cubic-bezier(0.34, 1.56, 0.64, 1) | Reward feel |
| Loading | 800-1500ms | linear / ease-in-out | "I'm working" feel |

**Rule of thumb:** if the user is waiting for it → 200-400ms. If they're just noticing it → 100-200ms. If it's a reward → 400-700ms.

---

## § Easing Cheat Sheet

| Easing | CSS | When to use |
|---|---|---|
| **ease-out** | `ease-out` | Most UI (entry, hover). Feels "snappy" |
| **ease-in** | `ease-in` | Exit animations. Feels "settled" |
| **ease-in-out** | `ease-in-out` | Symmetric, polished. Page transitions |
| **linear** | `linear` | Continuous loops (spinners, skeletons) |
| **cubic-bezier(0.34, 1.56, 0.64, 1)** | custom | "Overshoot" bounce. Success feedback |
| **cubic-bezier(0.16, 1, 0.3, 1)** | custom | "Premium" ease-out. Vercel/Linear style |

---

## § Common Mistakes

### Mistake 1: Animations too slow

```text
❌ BAD:
.btn: 1000ms ease-out [Y0→-2]

Why bad: by the time the animation finishes, the user has clicked 3 more times.
```

**Fix:** hover = 150-200ms max.

### Mistake 2: Animations on too many properties

```text
❌ BAD:
.btn: 200ms [Y, X, S, R, α, color, bg, border, shadow, ...]

Why bad: feels "jiggly" and unprofessional.
```

**Fix:** 1-3 properties max. Y + shadow is plenty.

### Mistake 3: Linear easing everywhere

```text
❌ BAD:
.card: 400ms linear [Y+20→0, α0→1]

Why bad: feels robotic, mechanical.
```

**Fix:** ease-out for entries, ease-in for exits. Linear only for continuous loops.

### Mistake 4: No stagger

```text
❌ BAD: 10 cards appear simultaneously.
.cards: 400ms [Y+20→0, α0→1]
```

**Fix:** 30-50ms stagger per card for "flow" feel.

---

## § Output

After this phase, you should have:
- A list of every animation in the design, in micro-syntax
- Timing + easing for each
- Stagger plan for lists/grids

This becomes the input for the **Implementation** phase (where you write the actual CSS/JS).
</content>