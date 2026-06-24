<design_layout>

## Purpose
The first phase of UI design — sketch the layout in ASCII before writing any code. This is the most important phase because it forces you to think about structure before getting lost in pixel details.

## When this framework loads
- During `tasks/design-layout.md` → step "sketch_wireframe"
- When starting any new UI work
- When refactoring an existing UI that's not working

---

## § Why ASCII Wireframes?

**Speed:** You can sketch a full page layout in 30 seconds. A Figma file takes 5-10 minutes. The wireframe is about **structure**, not pixels.

**Communicability:** ASCII art is text — easy to paste in chat, edit, share. No version conflicts.

**Forces simplicity:** You can only fit so much in ASCII. The wireframe stays high-level.

**Reversible:** Throw it away and redo it in 5 seconds. No sunk cost.

---

## § The Wireframe Process (4 steps)

### Step 1: Identify the page sections

Common sections (in order, top to bottom):
- Header / Nav
- Hero
- Features
- Content (cards, lists, tables)
- Social proof (testimonials, logos, stats)
- CTA (call-to-action)
- Footer

Not every page needs every section. Landing page = hero + features + CTA + footer. Dashboard = nav + content + sidebar. Pick what's right for the page.

### Step 2: Sketch the rough layout

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

### Step 3: Add content placeholders

```text
┌─────────────────────────────────────┐
│ [LOGO]      [Nav]  [Nav]  [Sign Up] │
├─────────────────────────────────────┤
│                                     │
│   THE BEST [PRODUCT] FOR [USER]     │
│                                     │
│   [Subtitle goes here]              │
│                                     │
│   [ Get Started ]   [ Learn More ]  │
│                                     │
├─────────────────────────────────────┤
│  ⚡Fast   │  🔒Secure  │  🎨Pretty  │
│  [desc]   │  [desc]    │  [desc]    │
├─────────────────────────────────────┤
│  Trusted by:                         │
│  [Logo] [Logo] [Logo] [Logo]        │
├─────────────────────────────────────┤
│  Ready to try?                       │
│  [ Get Started Free ]                │
├─────────────────────────────────────┤
│  © 2024 [Product] · Privacy · Terms  │
└─────────────────────────────────────┘
```

### Step 4: Get the user's approval BEFORE coding

Show the wireframe to the user. Ask:
- "האם המבנה הזה עובד?"
- "משהו חסר? משהו מיותר?"
- "סדר הסקציות הגיוני?"

Don't code until the user says yes.

---

## § Common Layouts

### Landing page

```text
┌─────────────────────────────────────┐
│ [LOGO]   [Features][Pricing][Docs] [Sign In] [Sign Up] │
├─────────────────────────────────────┤
│                                     │
│     THE BEST [PRODUCT] FOR [USER]   │
│   [Subtitle: 1 sentence value prop] │
│                                     │
│     [ Primary CTA ]  [ Secondary ]  │
│                                     │
│     [Hero image / video / demo]     │
│                                     │
├─────────────────────────────────────┤
│   3 FEATURES in a row                 │
├─────────────────────────────────────┤
│   SOCIAL PROOF (logos / stats)      │
├─────────────────────────────────────┤
│   PRICING (3 tiers)                 │
├─────────────────────────────────────┤
│   FAQ                               │
├─────────────────────────────────────┤
│   FINAL CTA                         │
├─────────────────────────────────────┤
│   FOOTER                            │
└─────────────────────────────────────┘
```

### Dashboard

```text
┌──────────┬──────────────────────────────────┐
│          │  [Search]      [User Menu]    │
│ SIDEBAR  ├──────────────────────────────────┤
│  - Home  │                                  │
│  - Items │  [Page Title]                    │
│  - Users │                                  │
│  - Setts │  ┌──────┐  ┌──────┐  ┌──────┐  │
│          │  │ Stat │  │ Stat │  │ Stat │  │
│          │  └──────┘  └──────┘  └──────┘  │
│          │                                  │
│          │  [Main content table / list]   │
│          │                                  │
│          │                                  │
└──────────┴──────────────────────────────────┘
```

### Form page (login / signup)

```text
┌─────────────────────────────────────┐
│           [LOGO]                    │
│                                     │
│       Welcome back                  │
│                                     │
│   [ Email                          ] │
│   [ Password                       ] │
│                                     │
│   [ Forgot password? ]              │
│                                     │
│   [        Sign In        ]         │
│                                     │
│   Don't have an account? Sign up    │
└─────────────────────────────────────┘
```

### Pricing page

```text
┌─────────────────────────────────────┐
│         Choose your plan            │
│                                     │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ │
│  │  FREE   │ │  PRO ⭐ │ │  TEAM   │ │
│  │         │ │         │ │         │ │
│  │ $0/mo   │ │ $20/mo  │ │ $50/mo  │ │
│  │         │ │         │ │         │ │
│  │  ✓ ...  │ │  ✓ ...  │ │  ✓ ...  │ │
│  │  ✗ ...  │ │  ✓ ...  │ │  ✓ ...  │ │
│  │         │ │         │ │         │ │
│  │ [Get]   │ │ [Get]   │ │ [Get]   │ │
│  └─────────┘ └─────────┘ └─────────┘ │
└─────────────────────────────────────┘
```

### Blog post

```text
┌─────────────────────────────────────┐
│ [LOGO]   [Nav]                  [☰]  │
├─────────────────────────────────────┤
│                                     │
│   POST TITLE (h1)                    │
│   By Author · Date · 5 min read      │
│                                     │
│   [Hero image]                       │
│                                     │
│   Post content (markdown)            │
│                                     │
│   ...                                │
│                                     │
├─────────────────────────────────────┤
│   Related posts                      │
└─────────────────────────────────────┘
```

---

## § Common Mistakes

### Mistake 1: Too much in the wireframe

```text
❌ BAD — too detailed for ASCII:
┌─────────────────────────────────────┐
│ <header>                             │
│   <div class="nav">                  │
│     <a href="/">Logo</a>             │
│     <ul>                             │
│       <li><a>Features</a></li>        │
│       ...                            │
```

**Why bad:** you're writing the code in ASCII. The point of the wireframe is the **structure**, not the HTML.

**Fix:** keep the wireframe simple. Use brackets, arrows, blocks. Add detail when you code.

### Mistake 2: Skipping the wireframe

```text
❌ BAD — going straight to code:
"OK I have a great idea, let me just start building"
```

**Why bad:** you waste time coding a layout that doesn't work, then redo it.

**Fix:** always wireframe first, even for tiny UI changes.

### Mistake 3: Not asking for approval

```text
❌ BAD — wireframe in your head, code right away:
"I'm 90% sure this layout is right, let me build it"
```

**Why bad:** if the user wanted a different layout, you redo everything.

**Fix:** show the wireframe, get a "yes" or "change X" before coding.

---

## § Output

After this phase, you should have:
- A clear ASCII wireframe (text in chat, in a file, or in the SKILL task)
- Approval from the user
- A list of components you'll need (header, hero, card, button, footer, etc.)

The wireframe becomes the input for the **Theme** phase.
</content>