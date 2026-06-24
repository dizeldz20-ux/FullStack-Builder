# Mobile-First Frontend — Avoiding the "Looks Fine on Desktop, Broken on Phone" Trap

A reference for when a voice-agent web frontend has to render correctly on both a 360px mobile viewport and a 1440px desktop. Covers the specific failure mode of "I built a desktop layout, then opened it on a phone, and the sidebar ate half the screen."

## The trap

When a desktop-first developer adds `md:` Tailwind breakpoints to a layout, the *implicit* assumption is: "mobile is just a smaller desktop." It isn't. Two viewport classes need genuinely different UI:

- **Desktop**: persistent sidebar (260px) + main area, fixed layout, hover affordances.
- **Mobile**: full-bleed main, drawer sidebar (hidden by default), bottom-docked input, hamburger trigger, larger touch targets (44x44 minimum), no horizontal scroll, safe-area inset padding.

A layout that doesn't pick a side will look broken on the smaller viewport, regardless of how polished the desktop side is. In one session, a 1440px desktop screen scored 9/10 and a 375px mobile screen scored 2/10 (sidebar at 30% width, vertical-letter text, no responsive drawer). The user reaction was: "this is not another product, this looks awful."

## The verification matrix, before sending a URL

Always check both viewports in Playwright, in this order, before claiming "it works":

1. **Desktop (1440x900)**: sidebar persistent, main area well-spaced, all suggestion cards visible, input dock at bottom.
2. **Mobile (375x812)**: sidebar hidden by default, hamburger header, full-width main, input dock at the very bottom with safe-area inset, no horizontal scroll, no letter-vertical text.
3. **Tablet (768x1024)** if the user might use it: the breakpoint where the sidebar transitions from drawer to persistent.

Take a screenshot at each, then run a single `vision_analyze` call to score visual quality 1-10. If the mobile score is below 7, the layout is broken; do not send.

## Layout primitives that survive both viewports

```tsx
// Layout.tsx — drawer on mobile, persistent on md+
<div dir="rtl" className="relative h-screen w-screen overflow-hidden">
  {/* Backdrop for mobile drawer */}
  {sidebarOpen && (
    <button
      aria-label="סגור תפריט"
      onClick={() => setSidebarOpen(false)}
      className="fixed inset-0 z-30 bg-black/60 backdrop-blur-sm md:hidden cursor-default"
    />
  )}

  <aside
    className={
      'fixed md:static inset-y-0 right-0 z-40 w-72 max-w-[85vw] md:w-64 ' +
      'transform transition-transform duration-200 ease-out ' +
      (sidebarOpen ? 'translate-x-0' : 'translate-x-full md:translate-x-0')
    }
  >
    <Sidebar onCloseMobile={() => setSidebarOpen(false)} showCloseButton={sidebarOpen} />
  </aside>

  <main className="absolute inset-0 md:relative md:inset-auto md:flex-1 flex flex-col min-w-0">
    {/* Mobile-only top bar with hamburger */}
    <header className="md:hidden flex items-center justify-between px-4 h-12 border-b">
      <button onClick={() => setSidebarOpen(true)} aria-label="פתח תפריט">
        <Menu size={20} />
      </button>
      <span>MyApp</span>
      <div className="w-9" /> {/* spacer for centering */}
    </header>
    <ChatPage />
  </main>
</div>
```

Three details that make this work:

- **`absolute inset-0 md:relative md:inset-auto`** on `<main>`: full-bleed on mobile (sidebar is `fixed`, doesn't compete for space), flexes into the row on `md+`.
- **`fixed md:static`** on the `<aside>`: behaves as a fixed drawer on mobile, becomes a static sibling of `<main>` on desktop.
- **`translate-x-full md:translate-x-0`** hides the drawer off-screen on mobile when closed, keeps it visible on desktop at all times.

## Mobile-specific CSS (add to `index.css`)

```css
/* Safe areas for notched devices */
.safe-bottom {
  padding-bottom: max(0.5rem, env(safe-area-inset-bottom, 0px));
}
.safe-top {
  padding-top: max(0.5rem, env(safe-area-inset-top, 0px));
}

/* Flip horizontal icons in RTL so an arrow points the right way */
[dir="rtl"] .rtl-flip {
  transform: scaleX(-1);
}

/* Disable iOS bounce on body */
html, body {
  overscroll-behavior-y: none;
  -webkit-tap-highlight-color: transparent;
}
```

## RTL gotchas that bite on mobile

- **`transform: scaleX(-1)`** on the send-arrow icon. The send `<Send />` icon from lucide-react points right; in an RTL Hebrew chat, the user expects it to point left. Apply `[dir="rtl"] .rtl-flip { transform: scaleX(-1); }` to icon containers, not the icon itself (so margins/padding still apply normally).
- **Margin / padding direction**: use `ms-*` / `me-*` (margin-start/end) instead of `ml-*` / `mr-*`. Tailwind 4 has these built in; on v3 you need `tailwindcss-logical` or `rtl:` variants. Wrong-direction margin will leave dead space on one side and cramp the other.
- **Avatar / sidebar order**: in RTL, "first" is on the right. The brand mark in the header should be on the right, the settings gear on the left, even if the design was sketched in LTR.
- **`<html dir="rtl" lang="he">`** must be set on `index.html`, not just on the React root, otherwise `text-align: start` (the modern default) won't flip.

## When to use viewport-specific, not media-query-specific, components

Some components need to be totally different on mobile vs desktop (e.g. sidebar with brand+settings+new-chat vs a header strip with just hamburger+brand). For those, render two different components and use `md:hidden` / `hidden md:flex` to switch. Don't try to wrangle one component to look right at 375px and 1440px — the markup becomes unreadable.

## Voice agent specifics on mobile

- **`getUserMedia` requires HTTPS** (the tunnel handles this; see `secure-public-url.md`).
- **iOS Safari treats `SpeechRecognition` differently** from desktop: it can stop listening after 60s of silence, and it can fire `onend` without a result. Provide a manual "stop recording" button so the user can re-trigger without waiting for the timeout.
- **The `<input>` on iOS brings up the on-screen keyboard**, which can cover the input. Use `scrollIntoView` on focus, or rely on `visualViewport` for layout reflow.

## Hard rule: don't ship a frontend that you haven't opened in a real browser

The dev-server typecheck and the curl smoke are necessary but not sufficient. A layout that scores 9/10 in the desktop screenshot but 2/10 on mobile is broken. Verify in Playwright at the user's likely viewport (375x812 is the worst case for most phones) before saying "ready to test."

If you can't verify in Playwright, say so explicitly to the user. Don't hand them a URL you only saw a curl 200 for.
