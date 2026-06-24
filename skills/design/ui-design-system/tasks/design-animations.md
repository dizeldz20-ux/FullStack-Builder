<purpose>
Plan every animation in micro-syntax before writing CSS/JS. This forces consistent timing and prevents over-animation.
</purpose>

<user-story>
As the user, I want every animation in the UI to be planned (not just "I'll add some CSS later"), so the timing and easing are consistent across the whole product.
</user-story>

<when-to-use>
- After theme is approved
- Before implementing the components

NOT for: no animations needed (e.g. static page).
</when-to-use>

<context>
None
</context>

<references>
@frameworks/animation-micro-syntax.md (the planning notation)
</references>

<steps>

<step name="list_animated_elements">
Walk through the wireframe + theme. For each element, ask: "Does this animate?"

Common animated elements:
- Buttons (hover, press, focus)
- Cards (entry, hover)
- Form inputs (focus ring, error)
- Navigation (active state, mobile menu)
- Modals (entry, exit, backdrop)
- Page transitions
- Loading states (spinner, skeleton)
- Lists/grids (stagger entry)
- Toast notifications (entry, auto-dismiss)
</step>

<step name="write_micro_syntax">
For each animated element, write the micro-syntax:

```text
.btn: 200ms ease-out [Y0→-2, shadow↗]    /* hover */
.btn:active: 100ms [S1→0.95→1]            /* press */
.card: 400ms ease-out [Y+20→0, α0→1]      /* entry */
.modal: 300ms ease-out [S0.95→1, α0→1]    /* entry */
.toast: 300ms ease-in-out [X+100→0, α0→1]  /* entry from right */
```

**Use @frameworks/animation-micro-syntax.md** for the full notation guide.
</step>

<step name="plan_stagger">
For lists/grids, plan a stagger:

```text
.card:nth-child(1): 300ms ease-out [Y+20→0, α0→1]
.card:nth-child(2): 350ms ease-out [Y+20→0, α0→1]  /* +50ms */
.card:nth-child(3): 400ms ease-out [Y+20→0, α0→1]  /* +100ms */
.card:nth-child(4): 450ms ease-out [Y+20→0, α0→1]  /* +150ms */
```

**Rule:** 30-50ms per item = "flow". 100ms+ = "obvious stagger".
</step>

<step name="get_approval">
Show the user the animation plan. Ask:
- "הזמנים האלה טובים?"
- "אנימציות איפה שלא צריך?"
- "הstagger מורגש טוב?"

Then move to phase 4 (implementation).
</step>

</steps>

<output>
## Artifact
A list of micro-syntax animations.

## Format
A text document or in-chat list.

## Location
In the project's design folder, or in the implementation task.
</output>

<acceptance-criteria>
- [ ] Every animated element has a micro-syntax plan
- [ ] Timing is consistent (no 100ms next to 800ms without reason)
- [ ] Easing is appropriate (ease-out for entries, etc.)
- [ ] Stagger is planned for lists/grids
- [ ] the user approved the animation plan
</acceptance-criteria>
